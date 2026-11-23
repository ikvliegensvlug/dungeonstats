-- Dungeon Stats: the bosses of each dungeon and raid, by instance ID (the 8th value
-- of GetInstanceInfo()). The game on WoW Forever has no boss list of its own (the
-- Encounter Journal is empty), so this list comes with the add-on.
-- Each boss: { npcID or {npcIDs}, "Name", "Wing" (only where one instance ID
-- holds several dungeons) }. Rare spawns are left out: they are not always there.
local _, ns = ...
local DS = ns.DS

DS.BOSSES = {
  [389] = { -- Ragefire Chasm
    { 11517, "Oggleflint" }, { 11520, "Taragaman the Hungerer" },
    { 11518, "Jergosh the Invoker" }, { 11519, "Bazzalan" },
  },
  [43] = { -- Wailing Caverns
    { 3671, "Lady Anacondra" }, { 3669, "Lord Cobrahn" }, { 3653, "Kresh" },
    { 3670, "Lord Pythas" }, { 3674, "Skum" }, { 3673, "Lord Serpentis" },
    { 5775, "Verdan the Everliving" }, { 3654, "Mutanus the Devourer" },
  },
  [36] = { -- The Deadmines
    { 644, "Rhahk'Zor" }, { 642, "Sneed's Shredder" }, { 643, "Sneed" },
    { 1763, "Gilnid" }, { 646, "Mr. Smite" }, { 647, "Captain Greenskin" },
    { 639, "Edwin VanCleef" }, { 645, "Cookie" },
  },
  [33] = { -- Shadowfang Keep
    { 3914, "Rethilgore" }, { 3886, "Razorclaw the Butcher" }, { 3887, "Baron Silverlaine" },
    { 4278, "Commander Springvale" }, { 4279, "Odo the Blindwatcher" },
    { 4274, "Fenrus the Devourer" }, { 3927, "Wolf Master Nandos" }, { 4275, "Archmage Arugal" },
  },
  [48] = { -- Blackfathom Deeps
    { 4887, "Ghamoo-ra" }, { 4831, "Lady Sarevess" }, { 6243, "Gelihast" },
    { 12902, "Lorgus Jett" }, { 12876, "Baron Aquanis" }, { 4832, "Twilight Lord Kelris" },
    { 4830, "Old Serra'kis" }, { 4829, "Aku'mai" },
  },
  [34] = { -- The Stockade
    { 1696, "Targorr the Dread" }, { 1666, "Kam Deepfury" }, { 1717, "Hamhock" },
    { 1716, "Bazil Thredd" }, { 1663, "Dextren Ward" },
  },
  [90] = { -- Gnomeregan
    { 7361, "Grubbis" }, { 7079, "Viscous Fallout" }, { 6235, "Electrocutioner 6000" },
    { 6229, "Crowd Pummeler 9-60" }, { 7800, "Mekgineer Thermaplugg" },
  },
  [47] = { -- Razorfen Kraul
    { 6168, "Roogug" }, { 4424, "Aggem Thorncurse" }, { 4428, "Death Speaker Jargba" },
    { 4420, "Overlord Ramtusk" }, { 4422, "Agathelos the Raging" }, { 4421, "Charlga Razorflank" },
  },
  [189] = { -- Scarlet Monastery: four wings under one instance ID
    { 3983, "Interrogator Vishas", "Graveyard" }, { 4543, "Bloodmage Thalnos", "Graveyard" },
    { 3974, "Houndmaster Loksey", "Library" }, { 6487, "Arcanist Doan", "Library" },
    { 3975, "Herod", "Armory" },
    { 4542, "High Inquisitor Fairbanks", "Cathedral" },
    { 3976, "Scarlet Commander Mograine", "Cathedral" },
    { 3977, "High Inquisitor Whitemane", "Cathedral" },
  },
  [129] = { -- Razorfen Downs
    { 7355, "Tuten'kash" }, { 7357, "Mordresh Fire Eye" }, { 8567, "Glutton" },
    { 7358, "Amnennar the Coldbringer" },
  },
  [70] = { -- Uldaman
    { 6910, "Revelosh" }, { 6906, "The Lost Dwarves" }, { 7228, "Ironaya" },
    { 7023, "Obsidian Sentinel" }, { 7206, "Ancient Stone Keeper" },
    { 7291, "Galgann Firehammer" }, { 4854, "Grimlok" }, { 2748, "Archaedas" },
  },
  [209] = { -- Zul'Farrak
    { 8127, "Antu'sul" }, { 7272, "Theka the Martyr" }, { 7271, "Witch Doctor Zum'rah" },
    { 7796, "Nekrum Gutchewer" }, { 7275, "Shadowpriest Sezz'ziz" }, { 7604, "Sergeant Bly" },
    { 7795, "Hydromancer Velratha" }, { 7273, "Gahz'rilla" }, { 7267, "Chief Ukorz Sandscalp" },
  },
  [349] = { -- Maraudon
    { 13282, "Noxxion" }, { 12258, "Razorlash" }, { 12236, "Lord Vyletongue" },
    { 12225, "Celebras the Cursed" }, { 12203, "Landslide" }, { 13601, "Tinkerer Gizlock" },
    { 13596, "Rotgrip" }, { 12201, "Princess Theradras" },
  },
  [109] = { -- The Temple of Atal'Hakkar
    { 8580, "Atal'alarion" }, { 5721, "Dreamscythe" }, { 5720, "Weaver" },
    { 5710, "Jammal'an the Prophet" }, { 5711, "Ogom the Wretched" }, { 5719, "Morphaz" },
    { 5722, "Hazzas" }, { 8443, "Avatar of Hakkar" }, { 5709, "Shade of Eranikus" },
  },
  [230] = { -- Blackrock Depths
    { 9018, "High Interrogator Gerstahn" }, { 9025, "Lord Roccor" },
    { 9319, "Houndmaster Grebmar" }, { 9024, "Pyromancer Loregrain" },
    { 9017, "Lord Incendius" }, { 9041, "Warder Stilgiss" }, { 9056, "Fineous Darkvire" },
    { 9016, "Bael'Gar" }, { 9033, "General Angerforge" }, { 8983, "Golem Lord Argelmach" },
    { 9537, "Hurley Blackbreath" }, { 9502, "Phalanx" }, { 9543, "Ribbly Screwspigot" },
    { 9499, "Plugger Spazzring" }, { 9156, "Ambassador Flamelash" },
    { 9039, "The Seven" }, { 9938, "Magmus" }, { 9019, "Emperor Dagran Thaurissan" },
  },
  [229] = { -- Blackrock Spire: lower and upper under one instance ID
    { 9196, "Highlord Omokk", "Lower" }, { 9236, "Shadow Hunter Vosh'gajin", "Lower" },
    { 9237, "War Master Voone", "Lower" }, { 10596, "Mother Smolderweb", "Lower" },
    { 10584, "Urok Doomhowl", "Lower" }, { 9736, "Quartermaster Zigris", "Lower" },
    { 10220, "Halycon", "Lower" }, { 10268, "Gizrul the Slavener", "Lower" },
    { 9568, "Overlord Wyrmthalak", "Lower" },
    { 9816, "Pyroguard Emberseer", "Upper" }, { 10264, "Solakar Flamewreath", "Upper" },
    { 10899, "Goraluk Anvilcrack", "Upper" }, { 10429, "Warchief Rend Blackhand", "Upper" },
    { 10430, "The Beast", "Upper" }, { 10363, "General Drakkisath", "Upper" },
  },
  [289] = { -- Scholomance
    { 10506, "Kirtonos the Herald" }, { 10503, "Jandice Barov" }, { 11622, "Rattlegore" },
    { 10433, "Marduk Blackpool" }, { 10432, "Vectus" }, { 10508, "Ras Frostwhisper" },
    { 10505, "Instructor Malicia" }, { 11261, "Doctor Theolen Krastinov" },
    { 10901, "Lorekeeper Polkelt" }, { 10507, "The Ravenian" }, { 10504, "Lord Alexei Barov" },
    { 10502, "Lady Illucia Barov" }, { 1853, "Darkmaster Gandling" },
  },
  [329] = { -- Stratholme: two sides under one instance ID
    { 10516, "The Unforgiven", "Living" }, { 10808, "Timmy the Cruel", "Living" },
    { 11032, "Malor the Zealous", "Living" }, { 10997, "Cannon Master Willey", "Living" },
    { 10811, "Archivist Galford", "Living" }, { 10813, "Balnazzar", "Living" },
    { 10435, "Magistrate Barthilas", "Undead" }, { 10437, "Nerub'enkan", "Undead" },
    { 10436, "Baroness Anastari", "Undead" }, { 10438, "Maleki the Pallid", "Undead" },
    { 10439, "Ramstein the Gorger", "Undead" }, { 10440, "Baron Rivendare", "Undead" },
  },
  [429] = { -- Dire Maul: three wings under one instance ID
    { 14354, "Pusillin", "East" }, { 11490, "Zevrim Thornhoof", "East" },
    { 13280, "Hydrospawn", "East" }, { 14327, "Lethtendris", "East" },
    { 11492, "Alzzin the Wildshaper", "East" },
    { 11489, "Tendris Warpwood", "West" }, { 11488, "Illyanna Ravenoak", "West" },
    { 11487, "Magister Kalendris", "West" }, { 11496, "Immol'thar", "West" },
    { 11486, "Prince Tortheldrin", "West" },
    { 14326, "Guard Mol'dar", "North" }, { 14322, "Stomper Kreeg", "North" },
    { 14321, "Guard Fengus", "North" }, { 14323, "Guard Slip'kik", "North" },
    { 14325, "Captain Kromcrush", "North" }, { 11501, "King Gordok", "North" },
  },
  [249] = { -- Onyxia's Lair
    { 10184, "Onyxia" },
  },
  [409] = { -- Molten Core
    { 12118, "Lucifron" }, { 11982, "Magmadar" }, { 12259, "Gehennas" }, { 12057, "Garr" },
    { 12264, "Shazzrah" }, { 12056, "Baron Geddon" }, { 12098, "Sulfuron Harbinger" },
    { 11988, "Golemagg the Incinerator" }, { 12018, "Majordomo Executus" }, { 11502, "Ragnaros" },
  },
  [469] = { -- Blackwing Lair
    { 12435, "Razorgore the Untamed" }, { 13020, "Vaelastrasz the Corrupt" },
    { 12017, "Broodlord Lashlayer" }, { 11983, "Firemaw" }, { 14601, "Ebonroc" },
    { 11981, "Flamegor" }, { 14020, "Chromaggus" }, { 11583, "Nefarian" },
  },
  [309] = { -- Zul'Gurub
    { 14517, "High Priestess Jeklik" }, { 14507, "High Priest Venoxis" },
    { 14510, "High Priestess Mar'li" }, { 11382, "Bloodlord Mandokir" },
    { { 15082, 15083, 15084, 15085 }, "Edge of Madness" }, { 15114, "Gahz'ranka" },
    { 14509, "High Priest Thekal" }, { 14515, "High Priestess Arlokk" },
    { 11380, "Jin'do the Hexxer" }, { 14834, "Hakkar" },
  },
  [509] = { -- Ruins of Ahn'Qiraj
    { 15348, "Kurinnaxx" }, { 15341, "General Rajaxx" }, { 15340, "Moam" },
    { 15370, "Buru the Gorger" }, { 15369, "Ayamiss the Hunter" }, { 15339, "Ossirian the Unscarred" },
  },
  [531] = { -- Temple of Ahn'Qiraj
    { 15263, "The Prophet Skeram" }, { { 15511, 15543, 15544 }, "Silithid Royalty" },
    { 15516, "Battleguard Sartura" }, { 15510, "Fankriss the Unyielding" },
    { 15299, "Viscidus" }, { 15509, "Princess Huhuran" },
    { { 15276, 15275 }, "Twin Emperors" }, { 15517, "Ouro" }, { { 15727, 15589 }, "C'Thun" },
  },
  [533] = { -- Naxxramas
    { 15956, "Anub'Rekhan" }, { 15953, "Grand Widow Faerlina" }, { 15952, "Maexxna" },
    { 15954, "Noth the Plaguebringer" }, { 15936, "Heigan the Unclean" }, { 16011, "Loatheb" },
    { 16061, "Instructor Razuvious" }, { 16060, "Gothik the Harvester" },
    { { 16064, 16065, 16062, 16063 }, "The Four Horsemen" },
    { 16028, "Patchwerk" }, { 15931, "Grobbulus" }, { 15932, "Gluth" }, { 15928, "Thaddius" },
    { 15989, "Sapphiron" }, { 15990, "Kel'Thuzad" },
  },
}

---------------------------------------------------------------------------
-- Which bosses died. Three ways, all from the game, whichever this client offers:
-- the encounter event at the end of a boss fight, the corpse you loot, and a dead
-- boss as your target or under your mouse.
---------------------------------------------------------------------------
-- The NPC ID inside a creature's GUID: "Creature-0-1-2-3-3669-0000ABCD" -> 3669.
local function npcID(guid)
  if type(guid) ~= "string" or (DS.IsSecret and DS.IsSecret(guid)) then return nil end
  local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
  if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end
DS.NpcIDFromGUID = npcID

local function bossList(run)
  return run and run.instanceID and DS.BOSSES[run.instanceID] or nil
end

-- "The Lost Dwarves" and "Lost Dwarves" are the same fight.
local function norm(name)
  return (name:lower():gsub("^the ", ""))
end

local function bossByID(list, id)
  for _, b in ipairs(list or {}) do
    if b[1] == id then return b end
    if type(b[1]) == "table" then
      for _, x in ipairs(b[1]) do if x == id then return b end end
    end
  end
end

-- How many letters differ between two names (insert, remove or change one letter).
local function distance(a, b)
  if math.abs(#a - #b) > 2 then return 99 end
  local prev = {}
  for j = 0, #b do prev[j] = j end
  for i = 1, #a do
    local cur = { [0] = i }
    for j = 1, #b do
      local cost = a:sub(i, i) == b:sub(j, j) and 0 or 1
      cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
    end
    prev = cur
  end
  return prev[#b]
end

-- By name; the game's own encounter names are sometimes spelled a little differently
-- ("Geilhast" for Gelihast), so a name one or two letters off counts when only one boss fits.
local function bossByName(list, name)
  local n = norm(name)
  for _, b in ipairs(list or {}) do
    if norm(b[2]) == n then return b end
  end
  if #n < 5 then return nil end
  local found, count = nil, 0
  for _, b in ipairs(list or {}) do
    if distance(norm(b[2]), n) <= 2 then found, count = b, count + 1 end
  end
  if count == 1 then return found end
end

local function bossState(run)
  run.killed = run.killed or {}
  run.wiped = run.wiped or {}
  run.bossOrder = run.bossOrder or {}
  return run.killed, run.wiped, run.bossOrder
end

-- A boss died (by its name in the list, or the game's encounter name).
function DS:NoteBossKill(run, name)
  if not (run and type(name) == "string" and name ~= "") then return end
  local killed, wiped, order = bossState(run)
  if killed[name] then return end
  killed[name] = true
  wiped[name] = nil
  order[#order + 1] = name
end

function DS:NoteBossWipe(run, name)
  if not (run and type(name) == "string" and name ~= "") then return end
  local killed, wiped, order = bossState(run)
  if killed[name] or wiped[name] then return end
  wiped[name] = true
  order[#order + 1] = name
end

-- The game's encounter event: success 1 = killed, 0 = the group wiped.
function DS:NoteEncounterEnd(name, success)
  local run = self.db.run
  if not run or type(name) ~= "string" or (self.IsSecret and self.IsSecret(name)) then return end
  local b = bossByName(bossList(run), name)
  name = b and b[2] or name
  if success == 1 or success == true then self:NoteBossKill(run, name) else self:NoteBossWipe(run, name) end
end

-- A creature that is dead: a boss of this dungeon counts as killed.
function DS:NoteDeadCreature(guid)
  local run = self.db.run
  local id = npcID(guid)
  local b = id and bossByID(bossList(run), id)
  if b then self:NoteBossKill(run, b[2]) end
end

-- A name from a chat line ("X dies, you gain ..."): only a boss in this dungeon's list
-- counts, every other name is a mob.
function DS:NoteNamedDeath(name)
  local run = self.db.run
  if not run or type(name) ~= "string" or (self.IsSecret and self.IsSecret(name)) then return end
  local b = bossByName(bossList(run), name)
  if b then self:NoteBossKill(run, b[2]) end
end

-- "%s dies, you gain %d experience." -> a pattern that captures the name. Not anchored
-- at the end: the line may go on with a rested or group bonus.
local function namePattern(fmt)
  if type(fmt) ~= "string" then return nil end
  local p = fmt:gsub("%%%d?%$?[sd]", "\1")
  p = p:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
  local first = true
  p = p:gsub("\1", function()
    if first then first = false; return "(.-)" end
    return "%d+"
  end)
  return "^" .. p
end

local xpPattern, diesPattern
local function nameFromXP(text)
  xpPattern = xpPattern or namePattern(COMBATLOG_XPGAIN_FIRSTPERSON or "%s dies, you gain %d experience.")
  return xpPattern and text:match(xpPattern)
end
local function nameFromDies(text)
  diesPattern = diesPattern or namePattern(UNITDIESOTHER or "%s dies.")
  return diesPattern and text:match(diesPattern .. "$")
end
DS.NameFromXPLine, DS.NameFromDiesLine = nameFromXP, nameFromDies

-- Boss faces. The game draws a creature's face from its display ID, but has no list of
-- them: a boss's display ID is learned the first time you target it, mouse over it or see
-- its nameplate, and kept for all characters (db.bossFaces, by NPC ID or by name for
-- bosses that are not in the list).
local function faces()
  DS.db.bossFaces = DS.db.bossFaces or {}
  return DS.db.bossFaces
end

local function plain(v)
  if v == nil or (DS.IsSecret and DS.IsSecret(v)) then return nil end
  return v
end

-- The display ID of a unit, read with a hidden model frame (it may take a moment to
-- load). done(display) or done(nil, why). One unit at a time; a busy reader says so.
-- Bosses and players each have their own reader, so reading the group never holds up a boss.
local probes, busyFor = {}, {}
local function readDisplay(unit, done, kind)
  kind = kind or "boss"
  if busyFor[kind] then done(nil, "busy"); return end
  probes[kind] = probes[kind] or CreateFrame("PlayerModel", nil, UIParent)
  local probe = probes[kind]
  if not (probe.SetUnit and probe.GetDisplayInfo) then done(nil, "no model frame"); return end
  probe:SetSize(1, 1)
  probe:ClearAllPoints()
  probe:SetPoint("TOPLEFT", UIParent, "BOTTOMRIGHT", 10, -10)
  probe:Show()
  if not pcall(probe.SetUnit, probe, unit) then probe:Hide(); done(nil, "SetUnit failed"); return end
  busyFor[kind] = true
  local tries = 0
  local function check()
    tries = tries + 1
    local ok, raw = pcall(probe.GetDisplayInfo, probe)
    local display = ok and plain(raw)
    if type(display) == "number" and display > 0 then
      busyFor[kind] = false; probe:Hide(); done(display)
    elseif tries < 10 and C_Timer and C_Timer.After then
      C_Timer.After(0.2, check)
    else
      busyFor[kind] = false; probe:Hide()
      done(nil, ok and (raw == nil and "none" or "secret") or ("error " .. tostring(raw)))
    end
  end
  check()
end
DS.ReadDisplay = readDisplay

local function learnFace(unit)
  local run = DS.db.run
  if not (run and UnitExists and UnitExists(unit)) then return end
  -- by the NPC ID in the GUID; Forever hides most GUIDs inside dungeons, so else by name
  local id = UnitGUID and npcID(plain(UnitGUID(unit)))
  local name = plain(UnitName and UnitName(unit))
  local list = bossList(run)
  local b = (id and bossByID(list, id)) or (type(name) == "string" and bossByName(list, name))
  local key
  if b then
    key = type(b[1]) == "table" and b[1][1] or b[1]   -- one face for a fight of several bosses
  elseif type(name) == "string" and run.bossOrder then
    -- a boss that is not in the list: by its name, once you have fought it
    for _, n in ipairs(run.bossOrder) do if n == name then key = name end end
  end
  if not key or faces()[key] then return end
  local log = DS.db.debug and DS.db.debug.faces
  if DS.db.debug and not log then log = {}; DS.db.debug.faces = log end
  readDisplay(unit, function(display, note)
    if log then
      log[#log + 1] = tostring(key) .. ": " .. (display and tostring(display) or note)
      while #log > 30 do table.remove(log, 1) end
    end
    if display then
      faces()[key] = display
      if DS.RefreshBossFaces then DS:RefreshBossFaces() end
    end
  end)
end
DS.LearnBossFace = learnFace

-- The faces of the players in your group, kept with the run (by GUID and by name), so the
-- scoreboard still shows them after someone has left the group.
local function learnPlayerFaces()
  local run = DS.db.run
  if not run or busyFor.player then return end
  run.faces = run.faces or {}
  for _, unit in ipairs(DS.GroupUnits and DS.GroupUnits() or { "player" }) do
    if UnitExists and UnitExists(unit) and (not UnitIsPlayer or UnitIsPlayer(unit)) then
      local guid = UnitGUID and plain(UnitGUID(unit))
      local name = plain(UnitName and UnitName(unit))
      local key = type(guid) == "string" and guid or (type(name) == "string" and name) or nil
      if key and not run.faces[key] then
        readDisplay(unit, function(display)
          if display and DS.db.run == run then
            run.faces[key] = display
            if type(name) == "string" then run.faces[name] = display end
            learnPlayerFaces()   -- the next one
          end
        end, "player")
        return
      end
    end
  end
end
DS.LearnPlayerFaces = learnPlayerFaces

-- The display ID of a boss row, or nil when it has not been seen yet.
function DS:BossFace(row)
  local f = self.db.bossFaces
  if not f then return nil end
  return (row.id and f[row.id]) or f[row.name]
end

local function checkUnit(unit)
  pcall(learnFace, unit)
  if not (UnitExists and UnitExists(unit)) then return end
  if not (UnitIsDead and UnitIsDead(unit)) then return end
  DS:NoteDeadCreature(UnitGUID and UnitGUID(unit))
end

local function checkLootSources()
  if not (GetNumLootItems and GetLootSourceInfo) then return end
  for slot = 1, GetNumLootItems() do
    local ok, guid = pcall(GetLootSourceInfo, slot)
    if ok then DS:NoteDeadCreature(guid) end
  end
end

-- The bosses section of the scoreboard: { rows = { {name, killed, wiped} }, killed, total },
-- or nil when there is nothing to show. total is nil when the list is unknown:
-- a new WoW Forever dungeon, or a wing of Scarlet Monastery you have not fought in yet.
function DS:SummaryBosses(run)
  local list = bossList(run)
  local killed, wiped, order = run.killed or {}, run.wiped or {}, run.bossOrder or {}
  local rows, seen, nKilled, total = {}, {}, 0, nil
  if list then
    -- where one instance ID holds several wings, only the wings you fought in
    local wings, hasWings = {}, false
    for _, b in ipairs(list) do
      if b[3] then
        hasWings = true
        if killed[b[2]] or wiped[b[2]] then wings[b[3]] = true end
      end
    end
    total = 0
    for _, b in ipairs(list) do
      if not hasWings or wings[b[3]] then
        total = total + 1
        seen[b[2]] = true
        rows[#rows + 1] = { name = b[2], id = type(b[1]) == "table" and b[1][1] or b[1], killed = killed[b[2]] or false, wiped = wiped[b[2]] or false }
      end
    end
    if total == 0 then total = nil end
  end
  -- fights that are not in the list (or there is no list): in the order they happened
  for _, name in ipairs(order) do
    if not seen[name] then
      seen[name] = true
      rows[#rows + 1] = { name = name, killed = killed[name] or false, wiped = wiped[name] or false }
      if total then total = total + 1 end
    end
  end
  for _, r in ipairs(rows) do if r.killed then nKilled = nKilled + 1 end end
  if #rows == 0 then return nil end
  return { rows = rows, killed = nKilled, total = total }
end

function DS:HasBosses(run)
  return run and run.bossOrder and #run.bossOrder > 0 or false
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "ENCOUNTER_END", "BOSS_KILL", "PARTY_KILL", "UNIT_DIED",
                     "CHAT_MSG_COMBAT_XP_GAIN", "CHAT_MSG_COMBAT_HOSTILE_DEATH",
                     "LOOT_OPENED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "UNIT_HEALTH",
                     "NAME_PLATE_UNIT_ADDED", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
local onEvent
ev:SetScript("OnEvent", function(...)
  local ok, err = pcall(onEvent, ...)
  if not ok and DS.NoteError then DS:NoteError(err) end
end)
onEvent = function(_, event, a, b, _, _, e)
  if not (DS.db and DS.db.run) then return end
  if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_REGEN_ENABLED" then
    pcall(learnPlayerFaces)
  end
  if event == "ENCOUNTER_END" then
    -- encounterID, encounterName, difficultyID, groupSize, success
    if DS.db.debug then
      local log = DS.db.debug.bosses or {}
      DS.db.debug.bosses = log
      log[#log + 1] = tostring(a) .. " " .. tostring(b) .. " " .. tostring(e)
      while #log > 30 do table.remove(log, 1) end
    end
    DS:NoteEncounterEnd(b, e)
  elseif event == "BOSS_KILL" then
    -- encounterID, encounterName
    DS:NoteEncounterEnd(b, 1)
  elseif event == "PARTY_KILL" then
    -- attackerGUID, targetGUID: your group killed something (the GUID may be hidden)
    DS:NoteDeadCreature(b)
  elseif event == "UNIT_DIED" then
    DS:NoteDeadCreature(a)
  elseif event == "CHAT_MSG_COMBAT_XP_GAIN" or event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
    if type(a) ~= "string" or (DS.IsSecret and DS.IsSecret(a)) then return end
    local name = event == "CHAT_MSG_COMBAT_XP_GAIN" and nameFromXP(a) or nameFromDies(a)
    if name then DS:NoteNamedDeath(name) end
  elseif event == "LOOT_OPENED" then
    checkLootSources()
  elseif event == "PLAYER_TARGET_CHANGED" then
    checkUnit("target")
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    checkUnit("mouseover")
  elseif event == "NAME_PLATE_UNIT_ADDED" then
    if type(a) == "string" and not (DS.IsSecret and DS.IsSecret(a)) then pcall(learnFace, a) end
  elseif event == "UNIT_HEALTH" and a == "target" then
    checkUnit("target")
  end
end
