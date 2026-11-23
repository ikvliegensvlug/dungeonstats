-- Dungeon Stats tests. Run with: npm test
local ns = {}
for _, file in ipairs(TOC_FILES) do
  local chunk = assert(load(readfile(ROOT .. "/" .. file), "@" .. file))
  chunk("DungeonStats", ns)
end
local DS = ns.DS

local passed, failed = 0, 0
local function check(cond, msg)
  if not cond then error(msg or "check failed", 2) end
end

local function reset()
  wipe(DungeonStatsDB)
  for k, v in pairs(DS.defaults) do DungeonStatsDB[k] = v end
  DungeonStatsDB.tookOver = true
  DS.db = DungeonStatsDB
end

local function test(name, fn)
  reset()
  Printed = {}
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("ok    " .. name)
  else
    failed = failed + 1
    print("FAIL  " .. name .. "\n      " .. tostring(err))
  end
end

-- start-up: a ChatBanner from before the split still holds two runs
ChatBannerDB = { lootMinQuality = 2, lootSummary = true,
  runs = { { name = "Deadmines", duration = 600, items = {}, rolls = {} } },
  lastLoot = { name = "Wailing Caverns", duration = 900, items = {}, rolls = {} } }
Fire("ADDON_LOADED", "DungeonStats")
Fire("PLAYER_LOGIN")

local afterLogin = { runs = {}, q = DungeonStatsDB.lootMinQuality, tookOver = DungeonStatsDB.tookOver }
for i, r in ipairs(DungeonStatsDB.runs or {}) do afterLogin.runs[i] = r.name end

test("runs and the loot setting are taken over from ChatBanner once", function()
  check(table.concat(afterLogin.runs, ",") == "Wailing Caverns,Deadmines", "both runs, newest first, got " .. table.concat(afterLogin.runs, ","))
  check(afterLogin.q == 2 and afterLogin.tookOver, "green as set in ChatBanner, and only once")
  DungeonStatsDB.tookOver = true
  DungeonStatsDB.runs = {}
  DS:TakeOverFromChatBanner()
  check(#DungeonStatsDB.runs == 0, "not taken over a second time")
end)

test("the options panel is registered and changes the settings", function()
  check(Settings.registered and Settings.registered.name == "Dungeon Stats", "under AddOns")
  local p = DS.optionsPanel
  DS:RefreshOptions()
  check(p.autoOpen.checked == true and p.quality.text == "Blue (rare) and better", "shows the settings")
  p.autoOpen.checked = false
  p.autoOpen:Click()
  check(DS.db.autoOpen == false, "auto open off")
  p.quality:Click()
  check(DS.db.lootMinQuality == 4 and p.quality.text == "Purple (epic) and better", "next quality, got " .. p.quality.text)
end)

local BLUE = "|cff0070dd|Hitem:2000::::::::|h[Archeus]|h|r"
local PURPLE = "|cffa335ee|Hitem:2100::::::::|h[Ironfoe]|h|r"
local GREEN = "|cff1eff00|Hitem:2200::::::::|h[Gnoll Hide]|h|r"

local function enterDungeon(name)
  IsInInstance = function() return true, "party" end
  GetInstanceInfo = function() return name end
  Fire("PLAYER_ENTERING_WORLD")
end

local function leaveDungeon()
  IsInInstance = function() return false, "none" end
  Fire("PLAYER_ENTERING_WORLD")
end

local summary = function() return _G.DungeonStatsFrame end
local function closeSummary() if summary() then summary():Hide() end end

test("loot lines are read with who got which item", function()
  local who, link = DS.ParseLoot("Bram-Realm receives loot: " .. BLUE .. ".")
  check(who == "Bram-Realm" and link == BLUE, "someone else")
  who, link = DS.ParseLoot("You receive loot: " .. PURPLE .. "x2.")
  check(who == nil and link == PURPLE, "you, more than one")
  check(DS.ParseLoot("You won: " .. BLUE) == nil, "roll results are not counted twice")
  check(DS.ItemQuality(BLUE) == 3 and DS.ItemQuality(PURPLE) == 4 and DS.ItemQuality(GREEN) == 2, "quality from colour")
end)

test("roll lines are read with who, item and roll", function()
  local r = DS.ParseRoll("Need Roll - 87 for " .. PURPLE .. " by Bram-Realm")
  check(r.kind == "needroll" and r.roll == 87 and r.link == PURPLE and r.who == "Bram", "need roll")
  r = DS.ParseRoll("You have selected Need for: " .. PURPLE)
  check(r.kind == "need" and r.who == "Aztek", "your own need")
  r = DS.ParseRoll("Everyone passed on: " .. PURPLE)
  check(r.kind == "passed" and r.who == nil, "everyone passed")
  r = DS.ParseRoll("You won: " .. PURPLE)
  check(r.kind == "won" and r.who == "Aztek", "you won, not a player called You")
end)

test("blue and better is the default for the loot summary", function()
  check(DS.db.lootMinQuality == 3, "blue by default")
end)

test("the winner's roll and who else needed show in the summary", function()
  enterDungeon("Wailing Caverns")
  Fire("CHAT_MSG_LOOT", "Bram has selected Need for: " .. PURPLE)
  Fire("CHAT_MSG_LOOT", "You have selected Need for: " .. PURPLE)
  Fire("CHAT_MSG_LOOT", "Need Roll - 54 for " .. PURPLE .. " by Bram")
  Fire("CHAT_MSG_LOOT", "Need Roll - 87 for " .. PURPLE .. " by Aztek")
  Fire("CHAT_MSG_LOOT", "You won: " .. PURPLE)
  Fire("CHAT_MSG_LOOT", "You receive loot: " .. PURPLE .. ".")
  local rows = DS:SummaryLoot(DS.db.run)
  check(#rows == 1 and rows[1].text == "won by Aztek (Need 87) - also Need: Bram 54",
    "loot row, got " .. tostring(rows[1] and rows[1].text))
  leaveDungeon()
  closeSummary()
end)

-- the game's damage meter: one session per fight
local function fight(id, duration, data)
  local s = { id = id, duration = duration }
  local kinds = { dmg = 0, heal = 2, taken = 7, deaths = 9 }
  for field, rows in pairs(data) do
    local list = {}
    for _, r in ipairs(rows) do
      list[#list + 1] = { name = r[1], totalAmount = r[2], classFilename = r[3], sourceDisplayType = r[4],
                          isLocalPlayer = r[5], sourceGUID = r[6] }
    end
    s[kinds[field]] = list
  end
  MeterSessions[#MeterSessions + 1] = s
end

test("the scoreboard never registers for the combat log", function()
  -- this client blocks add-ons that register for it ("has been blocked from an action")
  for _, file in ipairs(TOC_FILES) do
    local src = readfile(ROOT .. "/" .. file)
    check(not src:find("COMBAT_LOG_EVENT", 1, true), file .. " mentions the combat log event")
  end
end)

test("the damage meter's fights since entering are added up per player", function()
  MeterSessions = {}
  fight(1, 30, { dmg = { { "Aztek", 999, "DRUID" } } })        -- before the dungeon
  enterDungeon("Wailing Caverns")
  check(DS.db.run.statsFrom == 1, "starts after the newest fight")
  fight(2, 40, { dmg = { { "Aztek-Realm", 1000, "DRUID" }, { "Bram", 400, "WARRIOR" }, { "Kobold", 5000, nil, 2 } },
                 heal = { { "Aztek", 800, "DRUID" } },
                 taken = { { "Bram", 2090, "WARRIOR" } } })
  fight(3, 20, { dmg = { { "Aztek", 312, "DRUID" } }, deaths = { { "Bram", 0, "WARRIOR" } } })   -- the meter gives 0 for a death
  local run = DS.db.run
  leaveDungeon()
  closeSummary()
  local s = run.stats
  local a, b = s.players.Aztek, s.players.Bram
  check(a.dmg == 1312, "Aztek's damage without the fight before, got " .. a.dmg)
  check(a.active == 60, "active time from his fights, got " .. a.active)
  check(b.dmg == 400 and b.taken == 2090 and b.deaths == 1, "Bram's numbers")
  check(a.heal == 800, "healing")
  check(not s.players.Kobold, "enemies left out")
  check(a.class == "DRUID" and b.class == "WARRIOR", "classes from the meter")
  MeterSessions = {}
end)

test("secret numbers are skipped, and combat delays the end", function()
  MeterSessions = {}
  enterDungeon("Deadmines")
  fight(1, 40, { dmg = { { "Aztek", 1000, "DRUID" } } })
  InCombat = true
  leaveDungeon()
  check(DS.db.run and not (summary() and summary().shown), "waits while in combat")
  InCombat = false
  SecretValues = true
  Fire("PLAYER_REGEN_ENABLED")
  check(DS.db.run == nil, "finished after combat")
  check(not (summary() and summary().shown), "no numbers readable, nothing to show")
  SecretValues = false
  MeterSessions = {}
end)

test("nothing is counted outside a dungeon", function()
  IsInInstance = function() return false, "none" end
  Fire("PLAYER_ENTERING_WORLD")
  check(DS.db.run == nil, "no run")
end)

test("links coloured by quality (|cnIQ2:) are read", function()
  enterDungeon("Wailing Caverns")
  local bracer = "|cnIQ2:|Hitem:14366::::::::27:1484::1::1:28:5254:::::|h[Mystic's Bracelets]|h|r"
  Fire("CHAT_MSG_LOOT", "You receive loot: " .. bracer .. ".")
  Fire("CHAT_MSG_LOOT", "You receive loot: |cnIQ0:|Hitem:5124::::::::27:1484:::::::::|h[Small Raptor Tooth]|h|r.")
  local items = DS.db.run.items
  check(#items == 1 and items[1].link == bracer and items[1].q == 2, "the green bracer, not the grey tooth, got " .. #items)
  leaveDungeon()
  closeSummary()
end)

test("alone, items taken from the loot window count once", function()
  enterDungeon("Deadmines")
  local slots = { BLUE, "|cff9d9d9d|Hitem:1::::::::|h[Broken Fang]|h|r" }
  GetNumLootItems = function() return #slots end
  GetLootSlotLink = function(i) return slots[i] end
  Fire("LOOT_OPENED")
  Fire("LOOT_SLOT_CLEARED", 1)
  Fire("LOOT_SLOT_CLEARED", 2)
  Fire("CHAT_MSG_LOOT", "You receive loot: " .. BLUE .. ".")   -- the same item again in chat
  local items = DS.db.run.items
  check(#items == 1 and items[1].who == "Aztek" and items[1].link == BLUE, "one blue item, got " .. #items)
  Fire("CHAT_MSG_LOOT", "You receive loot: " .. BLUE .. ".")   -- a second one is a new item
  check(#items == 2, "a second drop counts")
  InGroup = true
  Fire("LOOT_OPENED")
  Fire("LOOT_SLOT_CLEARED", 1)
  check(#items == 2, "in a group the chat line decides")
  InGroup = false
  GetNumLootItems, GetLootSlotLink = nil, nil
  SlashCmdList.DUNGEONSTATS("")
  check(summary().shown and summary().title.text == "Deadmines (so far)", "the run so far, got " .. summary().title.text)
  closeSummary()
  check(DS.db.run and #DS.db.run.items == 2, "still in the run")
  DS.db.lastLoot = { name = "Earlier run", duration = 60, items = {}, rolls = {} }
  SlashCmdList.DUNGEONSTATS("last")
  check(summary().shown and summary().title.text == "Earlier run", "summary last: the finished run, got " .. summary().title.text)
  closeSummary()
  leaveDungeon()
  closeSummary()
end)

test("leaving a dungeon opens the scoreboard with portraits", function()
  GroupNames.party1 = "Bram"; GroupClasses.Bram = "WARRIOR"
  DS.db.lootMinQuality = 2
  MeterSessions = {}
  enterDungeon("Wailing Caverns")
  fight(1, 60, { dmg = { { "Aztek", 48213, "DRUID" } }, taken = { { "Bram", 50, "WARRIOR" } } })
  Fire("CHAT_MSG_LOOT", "Bram receives loot: " .. BLUE .. ".")
  Fire("CHAT_MSG_LOOT", "Lisa receives loot: " .. GREEN .. ".")
  Fire("CHAT_MSG_LOOT", "Bram receives loot: |cff9d9d9d|Hitem:1::::::::|h[Broken Fang]|h|r.")
  Portraits = {}
  GroupNames.party1 = nil                     -- Bram left the group before the end
  Now = Now + 38 * 60 + 12
  leaveDungeon()
  local f = summary()
  check(f and f.shown, "scoreboard shown")
  check(f.title.text == "Wailing Caverns" and f.meta.text:find("38:12", 1, true), "name and time, got " .. f.meta.text)
  local titles = {}
  for _, c in ipairs(AllFrames) do
    if c.parent == f and rawget(c, "badge") and c.shown then titles[#titles + 1] = c.title.text end
  end
  local all = table.concat(titles, ",")
  check(all:find("Most damage", 1, true) and all:find("Most damage taken", 1, true), "cards with data, got " .. all)
  check(not all:find("Most healing", 1, true) and not all:find("Died most", 1, true), "empty categories left out")
  check(#Portraits >= 1 and Portraits[1] == "player", "your own face as portrait")
  local rows = 0
  for _, r in ipairs(AllFrames) do
    if r.parent == f and rawget(r, "itemLink") and r.shown then rows = rows + 1 end
  end
  check(rows == 2, "green and blue loot, no grey, got " .. rows)
  check(DS.db.run == nil and DS:LastRun().name == "Wailing Caverns", "run finished and kept")
  closeSummary()
  SlashCmdList.DUNGEONSTATS("")
  check(summary().shown, "/dstats opens it again")
  closeSummary()

  -- post to party
  local run = DS:LastRun()
  Sent = {}
  InGroup = false
  check(DS:PostSummary(run) == false and #Sent == 0, "not in a group: nothing sent")
  InGroup = true
  DS:PostSummary(run)
  check(#Sent >= 2 and Sent[1]:find("^PARTY:Dungeon Stats: Wailing Caverns %(38:12"), "header line, got " .. tostring(Sent[1]))
  local text = table.concat(Sent, "\n")
  check(text:find("Most damage: Aztek 48.2k (804 DPS)", 1, true), "categories posted, got " .. text)
  check(text:find("[Archeus]", 1, true), "loot posted")
  for _, line in ipairs(Sent) do check(#line - 6 <= 255, "lines fit in chat") end
  check(Sent[#Sent] == "PARTY:Download addon Dungeon Stats, free on CurseForge.", "ends with where to get Dungeon Stats")
  InRaid = true
  Sent = {}
  DS:PostSummary(run)
  check(Sent[1]:find("^RAID:"), "raid chat in a raid")
  InGroup, InRaid = false, false
  MeterSessions = {}
end)

test("the loot list puts the best first and its filter cycles green, blue, purple", function()
  local PURPLE = "|cffa335ee|Hitem:11684::::::::|h[Ironfoe]|h|r"
  local run = { name = "Deadmines", duration = 60, rolls = {},
    items = { { who = "Aztek", link = GREEN, q = 2 }, { who = "Bram", link = BLUE, q = 3 }, { who = "Lisa", link = PURPLE, q = 4 } } }
  DS.db.lootMinQuality = 2
  local rows = DS:SummaryLoot(run)
  check(#rows == 3 and rows[1].link == PURPLE and rows[3].link == GREEN, "best first")
  check(rows[1].text == "looted by Lisa", "no roll: looted, got " .. rows[1].text)
  DS:OpenSummary(run)
  local f = DS.summaryFilter
  check(f and f.shown and f.text.text:find("green or better", 1, true), "filter shows the choice")
  f:Click()
  check(DS.db.lootMinQuality == 3 and f.text.text:find("blue or better", 1, true), "click: blue")
  f:Click(); f:Click()
  check(DS.db.lootMinQuality == 2, "and around to green")
  DS.db.lootMinQuality = 4
  run.items = { run.items[1] }
  DS:OpenSummary(run)
  local empty = false
  for _, r in ipairs(AllFrames) do
    local info = rawget(r, "info"); if r.parent == summary() and info and r.shown and info.text:find("^No ") then empty = true end
  end
  check(f.shown and empty, "filter stays, with a note that nothing matches")
  DS.db.lootMinQuality = 3
  closeSummary()
end)

test("the last 5 runs are kept and can be browsed", function()
  DS.db.runs, DS.db.lastLoot = nil, { name = "Old", duration = 60, items = {}, rolls = {} }
  check(DS:LastRun().name == "Old" and DS.db.lastLoot == nil, "the one run from before is kept")
  MeterSessions = {}
  for i = 1, 6 do
    enterDungeon("Run " .. i)
    Fire("CHAT_MSG_LOOT", "You receive loot: " .. BLUE .. ".")
    leaveDungeon()
    closeSummary()
  end
  local runs = DS:Runs()
  check(#runs == 5 and runs[1].name == "Run 6" and runs[5].name == "Run 2", "newest five, got " .. #runs)
  enterDungeon("Deadmines")
  SlashCmdList.DUNGEONSTATS("")
  local f = summary()
  check(f.title.text == "Deadmines (so far)" and f.older.shown and f.newer.disabled, "the run you are in: only Older")
  f.older:Click()
  check(f.title.text == "Run 6" and not f.newer.disabled, "back to the last finished run")
  for _ = 1, 4 do f.older:Click() end
  check(f.title.text == "Run 2" and f.older.disabled, "the oldest kept run")
  for _ = 1, 5 do f.newer:Click() end
  check(f.title.text == "Deadmines (so far)", "forward to the run you are in, got " .. f.title.text)
  closeSummary()
  DS:OpenSummary(DS:SampleRun())
  check(not f.older.shown and not f.newer.shown, "no browsing in the sample")
  closeSummary()
  leaveDungeon()
  closeSummary()
end)

test("/dstats test shows a sample with your name", function()
  SlashCmdList.DUNGEONSTATS("test")
  local f = summary()
  check(f.shown and f.title.text:find("sample", 1, true), "sample shown")
  local names = {}
  for _, c in ipairs(AllFrames) do
    if c.parent == f and rawget(c, "badge") and c.shown then names[#names + 1] = c.name.text end
  end
  check(#names == #DS.SUMMARY_CATEGORIES, "every category, got " .. #names)
  check(table.concat(names, ","):find("Aztek", 1, true), "you are in it")
  local emblem
  for _, c in ipairs(AllFrames) do
    if c.parent == f and rawget(c, "classIcon") and c.shown and c.classIcon.shown and c.name.text == "Bram" then
      emblem = c.classIcon
    end
  end
  check(emblem and emblem.atlas == "classicon-warrior", "players outside your group get their round class icon")
  closeSummary()
end)

test("players are found by GUID or by the start of a longer name", function()
  MeterSessions = {}
  GroupNames.party1 = "Bram"
  enterDungeon("Wailing Caverns")
  fight(1, 60, { dmg = { { "Bram Steelhand", 900, "WARRIOR", nil, nil, "Player-Bram" } },
                 taken = { { "Aztek Ensteek", 400, "DRUID" } } })
  Portraits = {}
  leaveDungeon()
  local units = table.concat(Portraits, ",")
  check(units:find("party1", 1, true), "Bram by GUID, got " .. units)
  check(units:find("player", 1, true), "you by the start of your name, got " .. units)
  closeSummary()
  GroupNames.party1 = nil
  MeterSessions = {}
end)

test("your own card shows your face even when the meter names you differently", function()
  MeterSessions = {}
  enterDungeon("Wailing Caverns")
  fight(1, 60, { dmg = { { "Aztek Ensteek", 3135, "DRUID", nil, true } } })
  Portraits = {}
  leaveDungeon()
  check(summary().shown and Portraits[1] == "player", "your portrait, got " .. tostring(Portraits[1]))
  closeSummary()
  MeterSessions = {}
end)

test("/dstats debug keeps loot lines and how they were read", function()
  SlashCmdList.DUNGEONSTATS("debug")
  Fire("CHAT_MSG_LOOT", "You receive loot: " .. GREEN .. ".")
  SecretValues = true
  Fire("CHAT_MSG_LOOT", "You receive loot: " .. GREEN .. ".")
  SecretValues = false
  local log = DS.db.debug.loot
  check(#log == 2 and log[1].parsed == "you -> " .. GREEN .. " q2", "parsed line, got " .. tostring(log[1] and log[1].parsed))
  check(log[2].text == "<secret>", "secret lines are marked")
  SlashCmdList.DUNGEONSTATS("debug")
  check(DS.db.debug == nil, "off again")
end)

test("secret loot lines in a dungeon fight are skipped, never read", function()
  enterDungeon("Deadmines")
  SecretValues = true
  Fire("CHAT_MSG_LOOT", "You receive loot: " .. GREEN .. ".")
  SecretValues = false
  check(#DS.db.run.items == 0, "nothing noted")
  check(DS.lastError == nil, "no errors, got " .. tostring(DS.lastError))
  leaveDungeon()
  closeSummary()
end)

test("an error while noting loot never reaches the player", function()
  local real = DS.NoteLoot
  DS.NoteLoot = function() error("boom") end
  Fire("CHAT_MSG_LOOT", "You receive loot: " .. GREEN .. ".")
  DS.NoteLoot = real
  check(DS.lastError and DS.lastError:find("boom", 1, true), "error kept, got " .. tostring(DS.lastError))
  DS.lastError = nil
end)

test("portraits are drawn again shortly after the scoreboard opens", function()
  SlashCmdList.DUNGEONSTATS("test")
  Portraits = {}
  RunTimers()
  check(#Portraits >= 3 and Portraits[1] == "player", "your portrait redrawn by the timers, got " .. #Portraits)
  closeSummary()
  Portraits = {}
  RunTimers()
  check(#Portraits == 0, "nothing redrawn once closed")
end)

test("numbers and times are short and readable", function()
  check(DS.FormatNumber(912) == "912" and DS.FormatNumber(1410) == "1,410" and DS.FormatNumber(48213) == "48.2k", "numbers")
  check(DS.FormatClock(2292) == "38:12" and DS.FormatClock(3725) == "1:02:05", "times")
end)

test("the options never touch Blizzard's shared dropdown menus", function()
  -- UIDropDownMenu shares global state with the game's own menus; using it
  -- got ChatBanner blamed for blocked actions (party invites, player menus)
  local used = false
  for _, f in ipairs(AllFrames) do
    if f.template == "UIDropDownMenuTemplate" then used = true end
  end
  check(not used, "no UIDropDownMenuTemplate frames")
  for _, file in ipairs(TOC_FILES) do
    local src = readfile(ROOT .. "/" .. file)
    check(not src:find("UIDropDownMenu_", 1, true) and not src:find("CloseDropDownMenus", 1, true), file .. " uses UIDropDownMenu")
  end
end)

test("dying and running back does not end the dungeon", function()
  enterDungeon("Deadmines")
  Fire("CHAT_MSG_LOOT", "Bram receives loot: " .. BLUE .. ".")
  UnitIsDeadOrGhost = function() return true end
  leaveDungeon()
  check(not (summary() and summary().shown) and DS.db.run, "still in the run as a ghost")
  UnitIsDeadOrGhost = function() return false end
  enterDungeon("Deadmines")
  Fire("CHAT_MSG_LOOT", "Lisa receives loot: " .. BLUE .. ".")
  leaveDungeon()
  check(#DS:LastRun().items == 2, "both items in one summary")
  closeSummary()
  UnitIsDeadOrGhost = nil
end)

test("no scoreboard for an empty run or with the option off", function()
  enterDungeon("Ragefire Chasm")
  leaveDungeon()
  check(not (summary() and summary().shown), "nothing happened, nothing shown")
  DS.db.autoOpen = false
  enterDungeon("Ragefire Chasm")
  Fire("CHAT_MSG_LOOT", "Bram receives loot: " .. BLUE .. ".")
  leaveDungeon()
  check(not (summary() and summary().shown), "option off")
  IsInInstance, GetInstanceInfo = nil, nil
end)


print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then error("tests failed") end
