-- Dungeon Stats: a "run" is one visit to a dungeon or raid. During the run this file
-- notes who received green (uncommon) or better items and who rolled what;
-- Stats.lua adds the combat numbers. When you leave, Summary.lua shows it all,
-- with loot from the quality chosen in the options (db.lootMinQuality) upwards.
local _, ns = ...
local DS = ns.DS

local KEEP_QUALITY = 2  -- noted during the run: 2 = uncommon (green) and up

-- Choices for the lowest quality in the summary, as the options show them.
DS.LOOT_QUALITIES = {
  { key = 2, label = "Green (uncommon) and better", short = "green or better" },
  { key = 3, label = "Blue (rare) and better",      short = "blue or better" },
  { key = 4, label = "Purple (epic) and better",    short = "purple or better" },
}

-- Quality from the colour of an item link, for items the client has not cached yet.
local QUALITY_COLOURS = {
  ["1eff00"] = 2, ["0070dd"] = 3, ["a335ee"] = 4, ["ff8000"] = 5, ["e6cc80"] = 6,
}

local function quality(link)
  -- this client colours links by quality: |cnIQ2:...|r (2 = uncommon)
  local iq = link:match("|cnIQ(%d+):")
  if iq then return tonumber(iq) end
  if GetItemInfo then
    local _, _, q = GetItemInfo(link)
    if q then return q end
  end
  local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
  return hex and QUALITY_COLOURS[hex:lower()] or 0
end
DS.ItemQuality = quality

-- The game's (translated) loot lines. who = nil means the player.
local LOOT_FORMATS = {
  -- the "x2" versions first, or the plain ones would swallow the count
  { "LOOT_ITEM_MULTIPLE",       "%s receives loot: %sx%d.",    true },
  { "LOOT_ITEM_SELF_MULTIPLE",  "You receive loot: %sx%d.",    false },
  { "LOOT_ITEM",                "%s receives loot: %s.",       true },
  { "LOOT_ITEM_SELF",           "You receive loot: %s.",       false },
}

-- "%s receives loot: %s." -> pattern with captures, plus which capture is what.
-- Handles numbered arguments ("%2$s") that some translations use.
local function toCapture(fmt)
  local order, n = {}, 0
  local p = fmt:gsub("%%(%d?)%$?([sd])", function(num, kind)
    n = n + 1
    order[n] = tonumber(num) or n
    return kind == "s" and "<<S>>" or "<<D>>"
  end)
  p = p:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
  p = p:gsub("<<S>>", "(.+)"):gsub("<<D>>", "(%%d+)")
  return "^" .. p .. "$", order
end

local lootPatterns
-- Returns who (nil = you) and the item link of a loot line, or nil.
local function parseLoot(text)
  if type(text) ~= "string" then return nil end
  if not lootPatterns then
    lootPatterns = {}
    for _, f in ipairs(LOOT_FORMATS) do
      local fmt = _G[f[1]]
      local pattern, order = toCapture(type(fmt) == "string" and fmt or f[2])
      lootPatterns[#lootPatterns + 1] = { pattern = pattern, order = order, other = f[3] }
    end
  end
  for _, lp in ipairs(lootPatterns) do
    local caps = { text:match(lp.pattern) }
    if caps[1] then
      local args = {}
      for i, argNum in ipairs(lp.order) do args[argNum] = caps[i] end
      if lp.other then return args[1], args[2] end
      return nil, args[1]
    end
  end
end
DS.ParseLoot = parseLoot

-- Roll lines. Each format names what its arguments are; who = nil means you.
local ROLL_FORMATS = {
  { "LOOT_ROLL_NEED_SELF",     "You have selected Need for: %s", "need",     { "link" } },
  { "LOOT_ROLL_NEED",          "%s has selected Need for: %s",  "need",      { "who", "link" } },
  { "LOOT_ROLL_ROLLED_NEED",   "Need Roll - %d for %s by %s",   "needroll",  { "roll", "link", "who" } },
  { "LOOT_ROLL_ROLLED_GREED",  "Greed Roll - %d for %s by %s",  "greedroll", { "roll", "link", "who" } },
  -- "You won" before "%s won", or "You" would be taken for a name
  { "LOOT_ROLL_YOU_WON",       "You won: %s",                   "won",       { "link" } },
  { "LOOT_ROLL_WON",           "%s won: %s",                    "won",       { "who", "link" } },
  { "LOOT_ROLL_ALL_PASSED",    "Everyone passed on: %s",        "passed",    { "link" } },
}

local rollPatterns
-- This client starts roll lines with a link to the loot history: "|HlootHistory:9772545|h[Loot]|h: ".
-- Without it the lines read as on other clients (and its number is not the roll).
local function stripHistory(s)
  return (s:gsub("^|HlootHistory:[^|]*|h%[.-%]|h:%s*", ""))
end
DS.StripLootHistory = stripHistory
-- Returns { kind, who, link, roll } for a roll line, or nil. who is a short name.
local function parseRoll(text)
  if type(text) ~= "string" then return nil end
  if not rollPatterns then
    rollPatterns = {}
    for _, f in ipairs(ROLL_FORMATS) do
      local fmt = _G[f[1]]
      local pattern, order = toCapture(stripHistory(type(fmt) == "string" and fmt or f[2]))
      rollPatterns[#rollPatterns + 1] = { pattern = pattern, order = order, kind = f[3], roles = f[4] }
    end
  end
  text = stripHistory(text)
  for _, rp in ipairs(rollPatterns) do
    local caps = { text:match(rp.pattern) }
    if caps[1] then
      local args = {}
      for i, argNum in ipairs(rp.order) do args[argNum] = caps[i] end
      local r = { kind = rp.kind }
      for i, role in ipairs(rp.roles) do r[role] = args[i] end
      r.roll = tonumber(r.roll)
      local who = r.who or (rp.kind ~= "passed" and UnitName("player")) or nil
      r.who = who and ((Ambiguate and Ambiguate(who, "short")) or who) or nil
      return r
    end
  end
end
DS.ParseRoll = parseRoll

---------------------------------------------------------------------------
-- Tracking a run
---------------------------------------------------------------------------
local function inGroupInstance()
  if not IsInInstance then return nil end
  local inside, kind = IsInInstance()
  if inside and (kind == "party" or kind == "raid") then
    local name, id
    if GetInstanceInfo then
      local info = { GetInstanceInfo() }
      name, id = info[1], tonumber(info[8])
    end
    return name or (GetRealZoneText and GetRealZoneText()) or "Dungeon", id
  end
end

-- The last finished runs, newest first. Older versions kept only one (db.lastLoot).
-- 100 runs: a dungeon takes a few kilobytes in the saved variables, a raid somewhat more
DS.MAX_RUNS = 100
function DS:Runs()
  local db = self.db
  db.runs = db.runs or {}
  if db.lastLoot then
    table.insert(db.runs, 1, db.lastLoot)
    db.lastLoot = nil
  end
  while #db.runs > DS.MAX_RUNS do table.remove(db.runs) end
  return db.runs
end

function DS:LastRun() return self:Runs()[1] end

function DS:FinishRun()
  local run = self.db.run
  if not run then return end
  -- the damage meter's numbers are secret during combat: finish once it is over
  if InCombatLockdown and InCombatLockdown() then
    self.finishAfterCombat = true
    return
  end
  self.finishAfterCombat = nil
  self.db.run = nil
  run.duration = (time and run.start and (time() - run.start)) or 0
  if self.CollectStats then pcall(self.CollectStats, self, run) end
  -- keep the saved run small: of the rolls only whether an item was won
  for _, item in ipairs(run.items) do
    local r = run.rolls and run.rolls[item.link]
    local roll = r and r.rolls and r.rolls[item.who]
    if r and r.winner then item.won = true end
    -- what the one who got it chose: "Need" or "Greed"
    if roll and roll.kind then item.won, item.wonWith = true, roll.kind end
  end
  run.rolls = nil
  if #run.items > 0 or (self.HasStats and self:HasStats(run)) or (self.HasBosses and self:HasBosses(run)) then
    table.insert(self:Runs(), 1, run)
    self:Runs()   -- keep at most MAX_RUNS
    if self.db.autoOpen and self.OpenSummary then self:OpenSummary(run) end
  end
end

-- The run you are in, as far as it has come (for /dstats inside).
-- The meter is only readable out of combat; in a fight it shows the loot only.
function DS:RunSoFar()
  local run = self.db.run
  if not run then return nil end
  local copy = { name = run.name .. " (so far)", items = run.items, rolls = run.rolls,
                 start = run.start, statsFrom = run.statsFrom, soFar = true,
                 instanceID = run.instanceID, killed = run.killed, wiped = run.wiped,
                 bossOrder = run.bossOrder, faces = run.faces }
  copy.duration = (time and run.start and (time() - run.start)) or 0
  if self.CollectStats and not (InCombatLockdown and InCombatLockdown()) then
    pcall(self.CollectStats, self, copy)
  end
  return copy
end

-- Called on every zone change: start, continue or finish a run.
function DS:CheckRun()
  local name, instanceID = inGroupInstance()
  local run = self.db.run
  if name then
    if run and run.name ~= name then self:FinishRun(); run = nil end
    if run and not run.instanceID then run.instanceID = instanceID end
    if not run then
      run = { name = name, instanceID = instanceID, items = {}, rolls = {}, start = time and time() or 0 }
      self.db.run = run
      if self.StartStats then self:StartStats(run) end
      if self.LearnPlayerFaces then pcall(self.LearnPlayerFaces) end
    end
  elseif run then
    -- a ghost running back from the graveyard has not finished the dungeon yet
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return end
    self:FinishRun()
  end
end

-- The rolls on one item in the current run.
local function rollsFor(run, link)
  run.rolls = run.rolls or {}
  local r = run.rolls[link]
  if not r then
    r = { need = {}, needers = {}, rolls = {} }
    run.rolls[link] = r
  end
  return r
end

-- What someone rolled on an item in the current run: { kind = "Need", roll = 87 } or nil.
function DS:RollOf(link, who)
  local run = self.db.run
  local r = run and run.rolls and run.rolls[link]
  return r and who and r.rolls[who] or nil
end

local function noteRoll(run, roll)
  local r = rollsFor(run, roll.link)
  if roll.kind == "need" and roll.who and not r.need[roll.who] then
    r.need[roll.who] = true
    r.needers[#r.needers + 1] = roll.who
  elseif (roll.kind == "needroll" or roll.kind == "greedroll") and roll.who then
    r.rolls[roll.who] = { kind = roll.kind == "needroll" and "Need" or "Greed", roll = roll.roll }
  elseif roll.kind == "won" then
    r.winner = roll.who
  end
end

-- The same item can reach us twice: from the loot window and from the chat line.
local recent = {}
local function seenRecently(key, source)
  local now = GetTime and GetTime() or 0
  local r = recent[key]
  if r and r.source ~= source and now - r.time < 5 then recent[key] = nil; return true end
  recent[key] = { time = now, source = source }
  return false
end

local function addItem(run, who, link, source, guid)
  local q = quality(link)
  if q < KEEP_QUALITY then return end
  who = (Ambiguate and Ambiguate(who, "short")) or who
  if seenRecently(who .. link, source) then return end
  if guid and (DS.IsSecret and DS.IsSecret(guid) or type(guid) ~= "string" or guid == "") then guid = nil end
  table.insert(run.items, { who = who, link = link, q = q, guid = guid })
end

-- Alone, what you take from the loot window is yours; this works even when the
-- chat line is hidden from add-ons. In a group the chat line says who got it.
local lootSlots = {}
local function noteLootWindow()
  wipe(lootSlots)
  if not (GetNumLootItems and GetLootSlotLink) then return end
  for slot = 1, GetNumLootItems() do
    local ok, link = pcall(GetLootSlotLink, slot)
    if ok and type(link) == "string" and not (DS.IsSecret and DS.IsSecret(link)) then lootSlots[slot] = link end
  end
end
local function noteSlotTaken(slot)
  local run = DS.db.run
  local link = lootSlots[slot]
  lootSlots[slot] = nil
  if not (run and link) or (IsInGroup and IsInGroup()) then return end
  addItem(run, UnitName("player") or "You", link, "window", UnitGUID and UnitGUID("player"))
end

function DS:NoteLoot(text, guid)
  local run = self.db.run
  if not run then return end
  if self.IsSecret and self.IsSecret(text) then return end   -- unreadable during a fight
  local roll = parseRoll(text)
  if roll then
    if roll.link then noteRoll(run, roll) end
    return
  end
  local who, link = parseLoot(text)
  if not link then return end
  -- the line names who got it; its GUID (the event's 12th value) finds them to whisper
  if not who and not guid then guid = UnitGUID and UnitGUID("player") end
  addItem(run, who or UnitName("player") or "You", link, "chat", guid)
end

-- /dstats debug: keep the last loot lines and what Dungeon Stats made of them,
-- in the saved variables, so a problem in the game can be looked at afterwards.
function DS:DebugLoot(text)
  local log = self.db.debug.loot
  local entry = { run = self.db.run ~= nil }
  if issecretvalue and issecretvalue(text) then
    entry.text = "<secret>"
  else
    entry.text = tostring(text)
    local ok, who, link = pcall(parseLoot, text)
    entry.parsed = ok and (link and ((who or "you") .. " -> " .. link .. " q" .. quality(link)) or "no match") or ("error: " .. tostring(who))
    local ok2, roll = pcall(parseRoll, text)
    if ok2 and roll then entry.roll = roll.kind end
  end
  log[#log + 1] = entry
  while #log > 30 do table.remove(log, 1) end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_ALIVE",
                     "PLAYER_UNGHOST", "PLAYER_REGEN_ENABLED", "CHAT_MSG_LOOT",
                     "LOOT_OPENED", "LOOT_SLOT_CLEARED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
local onEvent
ev:SetScript("OnEvent", function(...)
  local ok, err = pcall(onEvent, ...)
  if not ok and DS.NoteError then DS:NoteError(err) end
end)
onEvent = function(_, event, text, ...)
  if not DS.db then return end
  if event == "LOOT_OPENED" then
    noteLootWindow()
  elseif event == "LOOT_SLOT_CLEARED" then
    noteSlotTaken(text)
  elseif event == "CHAT_MSG_LOOT" then
    if DS.db.debug then DS:DebugLoot(text) end
    DS:NoteLoot(text, (select(11, ...)))
  elseif event == "PLAYER_REGEN_ENABLED" then
    if DS.finishAfterCombat then DS:FinishRun() end
  else
    DS:CheckRun()
  end
end
