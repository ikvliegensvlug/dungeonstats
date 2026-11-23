-- Dungeon Stats: the dungeon scoreboard. Opens when you leave a dungeon or raid:
-- who did the most damage and healing, records, bad luck, and the loot with its rolls.
local _, ns = ...
local DS = ns.DS

local FONT = "Fonts\\FRIZQT__.TTF"
local GOLD = { 1, 0.82, 0 }

-- 48213 -> "48.2k", 1410 -> "1,410", 912 -> "912"
local function num(n)
  n = math.floor((n or 0) + 0.5)
  if n >= 1000000 then return string.format("%.1fm", n / 1000000) end
  if n >= 10000 then return string.format("%.1fk", n / 1000) end
  if n >= 1000 then return string.format("%d,%03d", math.floor(n / 1000), n % 1000) end
  return tostring(n)
end
DS.FormatNumber = num

local function clock(sec)
  sec = math.max(0, math.floor(sec or 0))
  local h, m, s = math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60
  if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
  return string.format("%d:%02d", m, s)
end
DS.FormatClock = clock

-- The player with the highest value of a field (more than 0), ties by name.
local function top(stats, field)
  local best, bestName
  for name, p in pairs(stats.players) do
    local v = p[field] or 0
    if v > 0 and (not best or v > best or (v == best and name < bestName)) then
      best, bestName = v, name
    end
  end
  return bestName, best
end

local ORANGE, GREEN, WHITE = { 1, 0.54, 0.24 }, { 0.3, 0.9, 0.3 }, { 1, 1, 1 }

-- Every category: where it goes, its icon and how to find the winner. Only what
-- the game's damage meter offers: add-ons can no longer read the combat log, so
-- buffs, killing blows and single-hit records are not available.
local CATEGORIES = {
  { section = "Heroes of the run", title = "Most damage", icon = "Ability_MeleeDamage", color = ORANGE,
    pick = function(s)
      local who, v = top(s, "dmg")
      if who then
        local p = s.players[who]
        return who, v, (p.active or 0) >= 1 and (num(v / p.active) .. " DPS") or nil
      end
    end },
  { section = "Heroes of the run", title = "Most healing", icon = "Spell_Holy_Heal", color = GREEN,
    pick = function(s) return top(s, "heal") end },
  { section = "Heroes of the run", title = "Most damage taken", icon = "INV_Shield_06", color = WHITE,
    pick = function(s) return top(s, "taken") end },
  { section = "Bad luck", title = "Died most", icon = "Ability_Rogue_FeignDeath", color = WHITE,
    pick = function(s)
      local who, v = top(s, "deaths")
      return who, v, v and (v == 1 and "time" or "times") or nil
    end },
}
DS.SUMMARY_CATEGORIES = CATEGORIES

-- The cards to show, grouped in sections; categories without a winner are left out.
function DS:SummaryCards(run)
  local sections, bySection = {}, {}
  local stats = run.stats
  if not stats then return sections end
  for _, c in ipairs(CATEGORIES) do
    local who, value, sub = c.pick(stats)
    if who and value and value > 0 then
      local sec = bySection[c.section]
      if not sec then
        sec = { title = c.section, cards = {} }
        bySection[c.section] = sec
        sections[#sections + 1] = sec
      end
      local p = stats.players[who]
      sec.cards[#sec.cards + 1] = { cat = c, who = who, value = value, text = num(value), sub = sub,
                                    class = p and p.class, isMe = p and p.isMe, guid = p and p.guid }
    end
  end
  return sections
end

-- Loot rows: items from the chosen quality up, with the winner's roll and who else needed.
function DS:SummaryLoot(run)
  local rows, min = {}, self.db.lootMinQuality or 3
  for _, item in ipairs(run.items or {}) do
    if (item.q or 3) >= min then
      local r = run.rolls and run.rolls[item.link]
      local parts = {}
      local won = r and r.rolls[item.who]
      -- "won" only when there was a roll; alone you simply looted it
      parts[1] = (r and r.winner and "won by " or "looted by ") .. item.who
        .. (won and (" (" .. won.kind .. " " .. won.roll .. ")") or "")
      if r then
        local others = {}
        for _, name in ipairs(r.needers) do
          if name ~= item.who then
            local nr = r.rolls[name]
            others[#others + 1] = name .. (nr and nr.roll and (" " .. nr.roll) or "")
          end
        end
        if #others > 0 then parts[2] = "also Need: " .. table.concat(others, ", ") end
      end
      rows[#rows + 1] = { link = item.link, who = item.who, q = item.q or 3, order = #rows, text = table.concat(parts, " - ") }
    end
  end
  -- the best items first, in the order they dropped
  table.sort(rows, function(a, b)
    if a.q ~= b.q then return a.q > b.q end
    return a.order < b.order
  end)
  return rows
end

-- Items in the run that could be shown with some quality filter (green and up).
function DS:SummaryHasLoot(run)
  for _, item in ipairs(run.items or {}) do
    if (item.q or 3) >= 2 then return true end
  end
  return false
end

-- The next quality filter after the current one (green -> blue -> purple -> green).
function DS:NextLootQuality()
  local list, cur = self.LOOT_QUALITIES, self.db.lootMinQuality or 3
  for i, choice in ipairs(list) do
    if choice.key == cur then return list[i % #list + 1].key end
  end
  return list[1].key
end

---------------------------------------------------------------------------
-- Posting to the group
---------------------------------------------------------------------------
-- Chat lines of at most 255 characters; "|" is not allowed in chat except in links.
function DS:SummaryChatLines(run)
  local lines = {}
  local head = "Dungeon Stats: " .. run.name .. " (" .. clock(run.duration)
  if run.stats and run.stats.kills > 0 then head = head .. ", " .. run.stats.kills .. " enemies slain" end
  lines[1] = head .. ")"
  local parts = {}
  for _, sec in ipairs(self:SummaryCards(run)) do
    for _, card in ipairs(sec.cards) do
      parts[#parts + 1] = card.cat.title .. ": " .. card.who .. " " .. card.text
        .. (card.sub and (" (" .. card.sub .. ")") or "")
    end
  end
  for _, row in ipairs(self:SummaryLoot(run)) do
    parts[#parts + 1] = row.link .. " " .. row.text
  end
  local line = ""
  for _, part in ipairs(parts) do
    part = part:gsub("|([^cHhr])", "%1")
    if line ~= "" and #line + 3 + #part > 255 then
      lines[#lines + 1] = line
      line = part
    else
      line = line == "" and part or (line .. " / " .. part)
    end
  end
  if line ~= "" then lines[#lines + 1] = line end
  lines[#lines + 1] = "Download addon Dungeon Stats, free on CurseForge."
  return lines
end

function DS:PostSummary(run)
  local channel = (IsInRaid and IsInRaid() and "RAID") or (IsInGroup and IsInGroup() and "PARTY")
  if not channel then
    self:Print("You are not in a group, so there is nobody to post the summary to.")
    return false
  end
  for _, line in ipairs(self:SummaryChatLines(run)) do SendChatMessage(line, channel) end
  return true
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
local frame
local cards, headers, lootRows = {}, {}, {}
local W, PAD, CARD_W, CARD_H, GAP = 620, 22, 186, 64, 8

-- The unit of a player still in your group: by GUID first (the meter may show a
-- longer name than UnitName, such as "Aztek Ensteek" for "Aztek"), then by name.
local function unitFor(name, guid)
  for _, unit in ipairs(DS.GroupUnits()) do
    if guid and UnitGUID and UnitGUID(unit) == guid then return unit end
  end
  for _, unit in ipairs(DS.GroupUnits()) do
    local n = UnitName(unit)
    if n and n == name and (not UnitExists or UnitExists(unit)) then return unit end
  end
  -- the meter's longer name starts with the game's name
  local me = UnitName("player")
  if me and name:sub(1, #me + 1) == me .. " " then return "player" end
end

-- Make a texture round with a mask texture (the old Texture:SetMask does
-- nothing on this client). No tex coords on masked textures.
local function round(tex)
  local parent = tex:GetParent()
  if not (parent and parent.CreateMaskTexture and tex.AddMaskTexture) then return end
  local mask = parent:CreateMaskTexture()
  mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(tex)
  tex:AddMaskTexture(mask)
end

-- The player's face while they are in the group; otherwise their class emblem.
-- The emblem texture has no mask (the game refuses tex coords on masked textures).
local function setPortrait(c, name, class, isMe, guid)
  local unit = isMe and "player" or unitFor(name, guid)
  if unit and SetPortraitTexture then
    SetPortraitTexture(c.portrait, unit)   -- already round
    c.portrait:Show()
    c.classIcon:Hide()
    return
  end
  c.portrait:Hide()
  -- the game's own round class icon ("classicon-druid"), else a question mark
  local atlas = class and ("classicon-" .. class:lower())
  local hasAtlas = atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
  if hasAtlas and c.classIcon.SetAtlas then
    c.classIcon:SetAtlas(atlas)
  else
    c.classIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
  end
  c.classIcon:Show()
end

local function classColor(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end

local function makeCard()
  local c = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
  c:SetSize(CARD_W, CARD_H)
  if c.SetBackdrop then
    c:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    c:SetBackdropColor(0, 0, 0, 0.55)
    c:SetBackdropBorderColor(0.45, 0.35, 0.12, 0.9)
  end
  -- gold ring behind the round portrait
  c.ring = c:CreateTexture(nil, "BORDER")
  c.ring:SetSize(54, 54)
  c.ring:SetPoint("LEFT", 4, 0)
  -- a file texture with a colour, not SetColorTexture: a mask only rounds file textures
  c.ring:SetTexture("Interface\\Buttons\\WHITE8X8")
  c.ring:SetVertexColor(0.72, 0.57, 0.24, 1)
  round(c.ring)
  -- explicitly above the gold ring (BORDER) and below the category badge (OVERLAY 1, 2)
  c.portrait = c:CreateTexture(nil, "ARTWORK", nil, 7)
  c.portrait:SetSize(48, 48)
  c.portrait:SetPoint("CENTER", c.ring, "CENTER")
  c.classIcon = c:CreateTexture(nil, "ARTWORK", nil, 7)
  c.classIcon:SetSize(48, 48)
  c.classIcon:SetPoint("CENTER", c.ring, "CENTER")
  -- category icon where a unit frame shows the level
  c.badgeRing = c:CreateTexture(nil, "OVERLAY", nil, 1)
  c.badgeRing:SetSize(26, 26)
  c.badgeRing:SetPoint("CENTER", c.ring, "BOTTOMLEFT", 9, 9)
  c.badgeRing:SetTexture("Interface\\Buttons\\WHITE8X8")
  c.badgeRing:SetVertexColor(0.72, 0.57, 0.24, 1)
  round(c.badgeRing)
  c.badge = c:CreateTexture(nil, "OVERLAY", nil, 2)
  c.badge:SetSize(22, 22)
  c.badge:SetPoint("CENTER", c.badgeRing, "CENTER")
  round(c.badge)

  local left = 62
  c.title = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  c.title:SetPoint("TOP", c, "TOPLEFT", left + (CARD_W - left) / 2, -5)
  c.name = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  c.name:SetPoint("TOP", c.title, "BOTTOM", 0, -1)
  c.value = c:CreateFontString(nil, "OVERLAY")
  c.value:SetFont(FONT, 20, "OUTLINE")
  c.value:SetPoint("TOP", c.name, "BOTTOM", 0, -2)
  c.sub = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  c.sub:SetTextColor(0.75, 0.7, 0.6)
  for _, fs in ipairs({ c.title, c.name, c.sub }) do fs:SetWidth(CARD_W - left - 6) fs:SetWordWrap(false) end
  return c
end

local function fillCard(c, card)
  c.card = card
  local cat = card.cat
  c.badge:SetTexture("Interface\\Icons\\" .. cat.icon)
  setPortrait(c, card.who, card.class, card.isMe, card.guid)
  c.title:SetText(cat.title)
  c.name:SetText(card.who)
  c.name:SetTextColor(classColor(card.class))
  c.value:SetText(card.text)
  c.value:SetTextColor(cat.color[1], cat.color[2], cat.color[3])
  c.sub:ClearAllPoints()
  if card.sub then
    -- the value and its note sit together in the middle of the plate
    c.sub:SetText(card.sub)
    c.sub:SetWidth(0)
    local total = c.value:GetStringWidth() + 4 + c.sub:GetStringWidth()
    c.value:ClearAllPoints()
    c.value:SetPoint("TOPLEFT", c.name, "BOTTOM", -total / 2, -2)
    c.sub:SetPoint("BOTTOMLEFT", c.value, "BOTTOMRIGHT", 4, 2)
    c.sub:Show()
  else
    c.value:ClearAllPoints()
    c.value:SetPoint("TOP", c.name, "BOTTOM", 0, -2)
    c.sub:Hide()
  end
  c:Show()
end

local function sectionHeader(i)
  local h = headers[i]
  if not h then
    h = frame:CreateFontString(nil, "OVERLAY")
    h:SetFont(FONT, 14, "")
    h:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    h:SetShadowColor(0, 0, 0, 1)
    h:SetShadowOffset(1, -1)
    h.left = frame:CreateTexture(nil, "ARTWORK")
    h.left:SetColorTexture(0.72, 0.57, 0.24, 0.6)
    h.left:SetHeight(1)
    h.right = frame:CreateTexture(nil, "ARTWORK")
    h.right:SetColorTexture(0.72, 0.57, 0.24, 0.6)
    h.right:SetHeight(1)
    headers[i] = h
  end
  return h
end

local function placeHeader(h, text, y)
  h:SetText(text)
  h:ClearAllPoints()
  h:SetPoint("TOP", frame, "TOP", 0, y)
  h.left:ClearAllPoints()
  h.left:SetPoint("LEFT", frame, "TOPLEFT", PAD, y - 8)
  h.left:SetPoint("RIGHT", h, "LEFT", -8, 0)
  h.right:ClearAllPoints()
  h.right:SetPoint("LEFT", h, "RIGHT", 8, 0)
  h.right:SetPoint("RIGHT", frame, "TOPRIGHT", -PAD, y - 8)
  h:Show(); h.left:Show(); h.right:Show()
end

local function lootRow(i)
  local r = lootRows[i]
  if not r then
    r = CreateFrame("Button", nil, frame)
    r:SetSize(W - 2 * PAD, 22)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(20, 20)
    r.icon:SetPoint("LEFT")
    r.link = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.link:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
    r.info = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.info:SetPoint("LEFT", r.link, "RIGHT", 8, 0)
    r.info:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    r.info:SetJustifyH("LEFT")
    r.info:SetWordWrap(false)
    r.info:SetTextColor(0.75, 0.7, 0.6)
    r:SetScript("OnEnter", function(self)
      if GameTooltip and self.itemLink then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.itemLink)
        GameTooltip:Show()
      end
    end)
    r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    lootRows[i] = r
  end
  return r
end

local function build()
  frame = CreateFrame("Frame", "DungeonStatsFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  frame:SetWidth(W)
  frame:SetPoint("CENTER", 0, 40)
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
  end
  if UISpecialFrames then table.insert(UISpecialFrames, "DungeonStatsFrame") end
  frame:Hide()

  -- the red header plate with the dungeon name, as on Blizzard's own dialogs
  local header = frame:CreateTexture(nil, "ARTWORK")
  header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
  header:SetSize(400, 64)
  header:SetPoint("TOP", 0, 12)
  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.title:SetPoint("TOP", header, "TOP", 0, -14)

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  frame.meta = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.meta:SetPoint("TOP", 0, -30)
  frame.meta:SetTextColor(0.75, 0.7, 0.6)

  -- browse the last runs: Older goes back, Newer forward up to the run you are in
  frame.older = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.older:SetSize(80, 20)
  frame.older:SetText("< Older")
  frame.older:SetPoint("TOPLEFT", PAD, -24)
  frame.older:SetScript("OnClick", function() DS:BrowseSummary(1) end)
  frame.newer = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.newer:SetSize(80, 20)
  frame.newer:SetText("Newer >")
  frame.newer:SetPoint("TOPRIGHT", -42, -24)
  frame.newer:SetScript("OnClick", function() DS:BrowseSummary(-1) end)

  frame.post = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.post:SetSize(130, 24)
  frame.post:SetText("Post to party")
  frame.post:SetPoint("BOTTOMLEFT", PAD, 18)
  frame.post:SetScript("OnClick", function() if frame.run then DS:PostSummary(frame.run) end end)

  frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  frame.closeButton:SetSize(110, 24)
  frame.closeButton:SetText("Close")
  frame.closeButton:SetPoint("BOTTOMRIGHT", -PAD, 18)
  frame.closeButton:SetScript("OnClick", function() frame:Hide() end)
end

local MAX_LOOT = 8

local QUALITY_HEX = { [2] = "1eff00", [3] = "0070dd", [4] = "a335ee" }
local function qualityLabel(q)
  for _, choice in ipairs(DS.LOOT_QUALITIES) do
    if choice.key == q then return "|cff" .. (QUALITY_HEX[q] or "ffffff") .. choice.short .. "|r" end
  end
  return tostring(q)
end

local filterButton
local function lootFilter()
  local f = CreateFrame("Button", nil, frame)
  f:SetHeight(18)
  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.text:SetPoint("RIGHT")
  local hl = f:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 0.82, 0, 0.12)
  f:SetScript("OnClick", function()
    DS.db.lootMinQuality = DS:NextLootQuality()
    if frame.run then DS:OpenSummary(frame.run) end
  end)
  f:SetScript("OnEnter", function(self)
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText("Click to show green, blue or purple items and better.")
      GameTooltip:Show()
    end
  end)
  f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  filterButton = f
  DS.summaryFilter = f
  return f
end

-- The item's icon, by item ID, so it also works for items the game has not cached yet.
local function itemIcon(link)
  local icon
  local id = tonumber(link:match("item:(%d+)"))
  if id and C_Item and C_Item.GetItemIconByID then icon = C_Item.GetItemIconByID(id) end
  if not icon and GetItemIcon then icon = GetItemIcon(link) end
  return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- A made-up run with you and your group, to see the scoreboard without a dungeon.
function DS:SampleRun()
  local names = {}
  for _, unit in ipairs(self.GroupUnits()) do
    local n = UnitName(unit)
    if n then names[#names + 1] = { name = n, class = select(2, UnitClass(unit)) } end
  end
  local extra = { { "Bram", "WARRIOR" }, { "Lisa", "PRIEST" }, { "Joost", "MAGE" }, { "Kees", "HUNTER" } }
  for i = #names + 1, 5 do names[i] = { name = extra[i - 1][1], class = extra[i - 1][2] } end
  local a, b, c, d = names[1], names[2], names[3], names[4]
  local players = {}
  local function p(who, t) t.class = who.class; t.active = t.active or 600; players[who.name] = t; return t end
  p(a, { dmg = 48213, heal = 0, buffs = 6, taken = 9100, kb = 22, deaths = 0, active = 1180 })
  p(b, { dmg = 21000, heal = 0, buffs = 2, taken = 52004, kb = 9, deaths = 1 })
  p(c, { dmg = 3100, heal = 31540, buffs = 27, taken = 7200, kb = 1, deaths = 0 })
  p(d, { dmg = 30500, heal = 0, buffs = 0, taken = 11800, kb = 14, deaths = 3 })
  local link = "|cffa335ee|Hitem:11684::::::::|h[Ironfoe]|h|r"
  local cloak = "|cff0070dd|Hitem:6449::::::::|h[Glowing Lizardscale Cloak]|h|r"
  return {
    name = "Wailing Caverns (sample)", duration = 38 * 60 + 12,
    stats = { players = players, kills = 64, rec = {
      hit = { who = a.name, amount = 912, what = "Ferocious Bite" },
      heal = { who = c.name, amount = 1410, what = "Greater Heal" },
      taken = { who = b.name, amount = 1840, what = "Mutanus the Devourer" } } },
    items = { { who = a.name, link = link, q = 4 }, { who = d.name, link = cloak, q = 3 } },
    rolls = { [link] = { needers = { a.name, b.name }, need = {}, winner = a.name,
      rolls = { [a.name] = { kind = "Need", roll = 87 }, [b.name] = { kind = "Need", roll = 54 } } },
      [cloak] = { needers = { d.name }, need = {}, winner = d.name, rolls = { [d.name] = { kind = "Need", roll = 71 } } } },
  }
end

-- Older (+1) or newer (-1) than the run in the window.
function DS:BrowseSummary(step)
  if not (frame and frame.pos) then return end
  local runs, pos = self:Runs(), frame.pos + step
  if pos >= 1 and runs[pos] then
    self:OpenSummary(runs[pos])
  elseif pos <= 0 then
    local now = self:RunSoFar()
    if now then self:OpenSummary(now) end
  end
end

function DS:OpenSummary(run)
  if not run then
    self:Print("No dungeon summary yet. It appears when you leave a dungeon or raid; "
      .. "|cffffd100/dstats test|r shows a sample.")
    return false
  end
  if not frame then build() end
  frame.run = run
  frame.title:SetText(run.name)
  local meta = clock(run.duration)
  if run.stats and run.stats.kills > 0 then meta = meta .. "  -  " .. run.stats.kills .. " enemies slain" end
  -- where this run sits among the kept runs: 0 = the run you are in
  local runs, pos = self:Runs(), nil
  if run.soFar then pos = 0 end
  for i, r in ipairs(runs) do if r == run then pos = i end end
  frame.pos = pos
  if pos and pos > 0 and run.start and date then meta = meta .. "  -  " .. date("%d %b %H:%M", run.start) end
  frame.meta:SetText(meta)
  frame.older:SetShown(pos ~= nil)
  frame.newer:SetShown(pos ~= nil)
  if pos then
    if pos < #runs then frame.older:Enable() else frame.older:Disable() end
    if pos > 1 or (pos == 1 and self.db.run) then frame.newer:Enable() else frame.newer:Disable() end
  end

  for _, c in ipairs(cards) do c:Hide() end
  for _, h in ipairs(headers) do h:Hide(); h.left:Hide(); h.right:Hide() end
  for _, r in ipairs(lootRows) do r:Hide() end

  local y, n, nh = -52, 0, 0
  for _, sec in ipairs(self:SummaryCards(run)) do
    nh = nh + 1
    placeHeader(sectionHeader(nh), sec.title, y)
    y = y - 24
    for i, card in ipairs(sec.cards) do
      n = n + 1
      local c = cards[n] or makeCard()
      cards[n] = c
      local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
      c:ClearAllPoints()
      c:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + col * (CARD_W + GAP), y - row * (CARD_H + GAP))
      fillCard(c, card)
    end
    y = y - math.ceil(#sec.cards / 3) * (CARD_H + GAP) - 4
  end

  local loot = self:SummaryLoot(run)
  if filterButton then filterButton:Hide() end
  if self:SummaryHasLoot(run) then
    nh = nh + 1
    local h = sectionHeader(nh)
    placeHeader(h, "Loot", y)
    -- a filter on the right of the header: click to show green, blue or purple and up
    local f = filterButton or lootFilter()
    f.text:SetText("Show: " .. qualityLabel(self.db.lootMinQuality))
    f:SetWidth(f.text:GetStringWidth() + 8)
    f:ClearAllPoints()
    f:SetPoint("RIGHT", frame, "TOPRIGHT", -PAD, y - 8)
    f:Show()
    h.right:ClearAllPoints()
    h.right:SetPoint("LEFT", h, "RIGHT", 8, 0)
    h.right:SetPoint("RIGHT", f, "LEFT", -8, 0)
    y = y - 24
    if #loot == 0 then
      local r = lootRow(1)
      r.itemLink = nil
      r.icon:SetTexture(nil)
      r.link:SetText("")
      r.info:SetText("No " .. qualityLabel(self.db.lootMinQuality) .. " items in this run.")
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
      r:Show()
      y = y - 24
    end
    for i, row in ipairs(loot) do
      if i > MAX_LOOT then break end
      local r = lootRow(i)
      r.itemLink = row.link
      r.icon:SetTexture(itemIcon(row.link))
      r.link:SetText(row.link)
      r.info:SetText(row.text)
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
      r:Show()
      y = y - 24
    end
    if #loot > MAX_LOOT then
      local r = lootRow(MAX_LOOT + 1)
      r.itemLink = nil
      r.icon:SetTexture(nil)
      r.link:SetText("")
      r.info:SetText("and " .. (#loot - MAX_LOOT) .. " more (all of them are in Post to party)")
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
      r:Show()
      y = y - 24
    end
  end

  local inGroup = (IsInGroup and IsInGroup()) or (IsInRaid and IsInRaid())
  frame.post:SetText(IsInRaid and IsInRaid() and "Post to raid" or "Post to party")
  if inGroup then frame.post:Enable() else frame.post:Disable() end
  frame:SetHeight(-y + 56)
  frame:Show()
  -- right after a loading screen the game may not have the 3D portraits ready yet:
  -- draw them again a little later
  if C_Timer and C_Timer.After then
    for _, delay in ipairs({ 0.5, 2, 5 }) do
      C_Timer.After(delay, function() DS:RefreshPortraits() end)
    end
  end
  return true
end

function DS:RefreshPortraits()
  if not (frame and frame:IsShown()) then return end
  for _, c in ipairs(cards) do
    if c:IsShown() and c.card then
      setPortrait(c, c.card.who, c.card.class, c.card.isMe, c.card.guid)
    end
  end
end
