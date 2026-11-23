-- Dungeon Stats: settings, slash commands, options and start-up.
-- A "run" is one visit to a dungeon or raid (Loot.lua), with the numbers from the
-- game's damage meter (Stats.lua); Summary.lua shows the scoreboard when you leave.
local ADDON, ns = ...

local DS = {}
ns.DS = DS
_G.DungeonStats = DS

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
DS.version = (GetMeta and GetMeta(ADDON, "Version")) or "?"

DS.defaults = {
  autoOpen = true,        -- open the scoreboard when you leave a dungeon or raid
  lootMinQuality = 3,     -- lowest loot quality on it: 2 green, 3 blue, 4 purple
}

function DS:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Dungeon Stats|r  " .. tostring(msg))
end

local function merge(db, defaults)
  for k, v in pairs(defaults) do
    if db[k] == nil then db[k] = v end
  end
end

-- In a dungeon fight the game may hand add-ons "secret" values they cannot read.
function DS.IsSecret(v)
  return v ~= nil and issecretvalue ~= nil and issecretvalue(v) and true or false
end

-- Errors are kept quietly (and in the debug log), never shown as a Lua error.
function DS:NoteError(err)
  self.lastError = tostring(err)
  if self.db and self.db.debug then
    local log = self.db.debug.errors or {}
    self.db.debug.errors = log
    log[#log + 1] = self.lastError
    while #log > 10 do table.remove(log, 1) end
  end
end

-- ChatBanner 1.0.5 and the 1.0.6 test versions kept the runs themselves:
-- take them over once, so nothing is lost when switching.
function DS:TakeOverFromChatBanner()
  local db, old = self.db, _G.ChatBannerDB
  if db.tookOver or type(old) ~= "table" then return end
  db.tookOver = true
  local runs = {}
  if type(old.runs) == "table" then
    for _, r in ipairs(old.runs) do runs[#runs + 1] = r end
  end
  if type(old.lastLoot) == "table" then table.insert(runs, 1, old.lastLoot) end
  db.runs = db.runs or {}
  for _, r in ipairs(runs) do db.runs[#db.runs + 1] = r end
  if not db.run and type(old.lootRun) == "table" then db.run = old.lootRun end
  if old.lootMinQuality then db.lootMinQuality = old.lootMinQuality end
  if old.lootSummary == false then db.autoOpen = false end
  self:Runs()   -- at most five
end

---------------------------------------------------------------------------
-- Options (Esc > Options > AddOns > Dungeon Stats)
---------------------------------------------------------------------------
local panel, category

local function qualityText()
  for _, q in ipairs(DS.LOOT_QUALITIES) do
    if q.key == DS.db.lootMinQuality then return q.label end
  end
  return "?"
end

function DS:RefreshOptions()
  if not panel then return end
  panel.autoOpen:SetChecked(self.db.autoOpen)
  panel.quality:SetText(qualityText())
end

function DS:InitOptions()
  panel = CreateFrame("Frame")
  panel.name = "Dungeon Stats"

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Dungeon Stats " .. DS.version)
  local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  sub:SetText("A scoreboard after every dungeon or raid: damage, healing, damage taken, deaths and loot.")

  local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", -4, -16)
  cb.label = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  cb.label:SetText("Open the scoreboard when you leave a dungeon or raid")
  cb:SetScript("OnClick", function(self) DS.db.autoOpen = self:GetChecked() and true or false end)
  panel.autoOpen = cb

  local qLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  qLabel:SetPoint("TOPLEFT", cb, "BOTTOMLEFT", 4, -14)
  qLabel:SetText("Loot on the scoreboard (click to change)")
  local q = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  q:SetSize(240, 24)
  q:SetPoint("TOPLEFT", qLabel, "BOTTOMLEFT", 0, -6)
  q:SetScript("OnClick", function()
    DS.db.lootMinQuality = DS:NextLootQuality()
    DS:RefreshOptions()
  end)
  panel.quality = q

  local show = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  show:SetSize(240, 24)
  show:SetPoint("TOPLEFT", q, "BOTTOMLEFT", 0, -16)
  show:SetText("Show the scoreboard")
  show:SetScript("OnClick", function() DS:OpenSummary(DS:RunSoFar() or DS:LastRun()) end)
  panel.show = show

  local help = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", show, "BOTTOMLEFT", 0, -16)
  help:SetJustifyH("LEFT")
  help:SetText("/dstats  - this dungeon so far, or the last one\n/dstats last  - the last finished run (Older and Newer browse the last 100)\n/dstats test  - a sample with your group\n/dstats options  - these options")

  panel:SetScript("OnShow", function() DS:RefreshOptions() end)
  if Settings and Settings.RegisterCanvasLayoutCategory then
    category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
  end
  DS.optionsPanel = panel
  self:RefreshOptions()
end

function DS:OpenOptions()
  if Settings and Settings.OpenToCategory and category then
    Settings.OpenToCategory(category:GetID())
  end
end

---------------------------------------------------------------------------
-- Start-up
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == ADDON then
    DungeonStatsDB = DungeonStatsDB or {}
    merge(DungeonStatsDB, DS.defaults)
    DS.db = DungeonStatsDB
  elseif event == "PLAYER_LOGIN" then
    -- every add-on's saved variables are loaded by now
    pcall(DS.TakeOverFromChatBanner, DS)
    DS:InitOptions()
    DS:CheckRun()
  end
end)

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local HELP = {
  "/dstats  - the scoreboard of this dungeon so far, or of the last one",
  "/dstats last  - the last finished run (Older and Newer browse the last 100)",
  "/dstats test  - a sample scoreboard with your group",
  "/dstats options  - the options",
}

SLASH_DUNGEONSTATS1 = "/dstats"
SLASH_DUNGEONSTATS2 = "/dungeonstats"
SlashCmdList.DUNGEONSTATS = function(msg)
  local cmd = (msg or ""):lower():match("^%s*(%S*)")
  if cmd == "" or cmd == "show" then
    DS:OpenSummary(DS:RunSoFar() or DS:LastRun())
  elseif cmd == "last" then
    DS:OpenSummary(DS:LastRun())
  elseif cmd == "test" then
    DS:OpenSummary(DS:SampleRun())
  elseif cmd == "options" or cmd == "config" then
    DS:OpenOptions()
  elseif cmd == "debug" then
    if DS.db.debug then
      DS.db.debug = nil
      DS:Print("Debug log off and cleared.")
    else
      DS.db.debug = { loot = {}, meter = {} }
      DS:Print("Debug log on: loot lines and damage meter numbers are kept until /dstats debug again.")
    end
  else
    for _, line in ipairs(HELP) do DS:Print(line) end
  end
end
