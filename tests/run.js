// Offline checks for Dungeon Stats: Lua syntax (5.1, as in WoW), no leaked globals,
// then the behaviour tests in tests.lua on a fake WoW API (tests/wow.lua).
const fs = require('fs');
const path = require('path');
const luaparse = require('luaparse');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');

const ROOT = path.resolve(__dirname, '..');
const toc = fs.readFileSync(path.join(ROOT, 'DungeonStats.toc'), 'utf8')
  .split(/\r?\n/).map(l => l.trim()).filter(l => l && !l.startsWith('#'));

// Globals the add-on is allowed to create.
const ALLOWED_GLOBALS = new Set(['DungeonStatsDB', 'SLASH_DUNGEONSTATS1', 'SLASH_DUNGEONSTATS2']);

let bad = 0;
for (const file of toc) {
  const p = path.join(ROOT, file);
  if (!fs.existsSync(p)) { console.log('MISSING', file); bad++; continue; }
  let ast;
  try {
    ast = luaparse.parse(fs.readFileSync(p, 'utf8'), { luaVersion: '5.1', scope: true });
  } catch (e) { console.log('SYNTAX', file, e.message); bad++; continue; }
  (function walk(n) {
    if (!n || typeof n !== 'object') return;
    if (Array.isArray(n)) return n.forEach(walk);
    if (n.type === 'AssignmentStatement') {
      for (const v of n.variables) {
        if (v.type === 'Identifier' && !v.isLocal && !ALLOWED_GLOBALS.has(v.name)) {
          console.log('GLOBAL', file, v.name); bad++;
        }
      }
    }
    for (const k of Object.keys(n)) if (k !== 'type') walk(n[k]);
  })(ast);
}
console.log(bad ? `static checks: ${bad} problem(s)` : `static checks: ${toc.length} files ok`);

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
lua.lua_register(L, to_luastring('readfile'), (L) => {
  const p = lua.lua_tojsstring(L, 1);
  lua.lua_pushstring(L, to_luastring(fs.readFileSync(p, 'utf8')));
  return 1;
});
lua.lua_pushstring(L, to_luastring(ROOT.replace(/\\/g, '/')));
lua.lua_setglobal(L, to_luastring('ROOT'));
lua.lua_newtable(L);
toc.forEach((f, i) => {
  lua.lua_pushstring(L, to_luastring(f));
  lua.lua_rawseti(L, -2, i + 1);
});
lua.lua_setglobal(L, to_luastring('TOC_FILES'));

function run(file) {
  const src = fs.readFileSync(path.join(__dirname, file), 'utf8');
  if (lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring('@' + file)) !== lua.LUA_OK
      || lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) {
    console.log(lua.lua_tojsstring(L, -1));
    return false;
  }
  return true;
}

const ok = run('wow.lua') && run('tests.lua');
process.exit(ok && !bad ? 0 : 1);
