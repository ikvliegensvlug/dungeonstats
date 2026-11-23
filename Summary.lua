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
  { section = "Heroes of the run", title = "Most damage", icon = "Ability_MeleeDamage", color = ORANGE, field = "dmg",
    pick = function(s)
      local who, v = top(s, "dmg")
      if who then
        local p = s.players[who]
        return who, v, (p.active or 0) >= 1 and (num(v / p.active) .. " DPS") or nil
      end
    end },
  { section = "Heroes of the run", title = "Most healing", icon = "Spell_Holy_Heal", color = GREEN, field = "heal",
    pick = function(s) return top(s, "heal") end },
  { section = "Heroes of the run", title = "Most damage taken", icon = "INV_Shield_06", color = WHITE, field = "taken",
    pick = function(s) return top(s, "taken") end },
  { section = "Bad luck", title = "Died most", icon = "Ability_Rogue_FeignDeath", color = WHITE, field = "deaths",
    pick = function(s)
      local who, v = top(s, "deaths")
      return who, v, v and (v == 1 and "time" or "times") or nil
    end },
}
DS.SUMMARY_CATEGORIES = CATEGORIES

-- The first five of a category (more than 0), for the tooltip on its card.
local function topFive(stats, cat)
  local list = {}
  for name, p in pairs(stats.players) do
    local v = p[cat.field] or 0
    if v > 0 then list[#list + 1] = { who = name, value = v, class = p.class, active = p.active } end
  end
  table.sort(list, function(a, b)
    if a.value ~= b.value then return a.value > b.value end
    return a.who < b.who
  end)
  for i = #list, 6, -1 do list[i] = nil end
  for _, e in ipairs(list) do
    e.text = num(e.value)
    if cat.field == "dmg" and (e.active or 0) >= 1 then e.text = e.text .. "  (" .. num(e.value / e.active) .. " DPS)" end
  end
  return list
end

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
      -- the face kept during the run, for someone who has left the group since
      local faces = run.faces
      local display = faces and ((p and p.guid and faces[p.guid]) or faces[who])
      sec.cards[#sec.cards + 1] = { cat = c, who = who, value = value, text = num(value), sub = sub,
                                    class = p and p.class, isMe = p and p.isMe, guid = p and p.guid,
                                    display = display, top = topFive(stats, c) }
    end
  end
  return sections
end

-- Loot rows: items from the chosen quality up, with the winner's roll and who else needed.
function DS:SummaryLoot(run, min)
  local rows = {}
  min = min or self.db.lootMinQuality or 3
  for _, item in ipairs(run.items or {}) do
    if (item.q or 3) >= min then
      local r = run.rolls and run.rolls[item.link]
      -- "won" only when there was a roll; alone you simply looted it
      -- Need or Greed behind the name, without the number rolled; older runs kept only
      -- the rolls (the "won" line was not read then), so the looter's own roll counts too
      local kind = item.wonWith or (r and r.rolls and r.rolls[item.who] and r.rolls[item.who].kind)
      local text = ((item.won or kind or (r and r.winner)) and "won by " or "looted by ") .. item.who
      if kind then text = text .. " (" .. kind .. ")" end
      rows[#rows + 1] = { link = item.link, who = item.who, guid = item.guid, q = item.q or 3, order = #rows, text = text }
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
  -- in chat only blue and purple (and better), whatever the window's filter: a list of
  -- greens would fill the chat. The bosses stay in the window only.
  for _, row in ipairs(self:SummaryLoot(run, 3)) do
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
local cards, headers, lootRows, bossLines = {}, {}, {}, {}
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
local function setPortrait(c, name, class, isMe, guid, display)
  local unit = isMe and "player" or unitFor(name, guid)
  if unit and SetPortraitTexture then
    SetPortraitTexture(c.portrait, unit)   -- already round
    c.portrait:Show()
    c.classIcon:Hide()
    return
  end
  -- gone from the group: the face Dungeon Stats saw during the run
  if display and SetPortraitTextureFromCreatureDisplayID
    and pcall(SetPortraitTextureFromCreatureDisplayID, c.portrait, display) then
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

-- The name to whisper: what the game calls the player (with realm when it is another
-- one). The damage meter may show a longer name ("Aztek Ensteek" for "Aztek"), so the
-- player is found by GUID first, in the group or with GetPlayerInfoByGUID.
function DS:WhisperName(name, guid)
  if guid then
    for _, unit in ipairs(DS.GroupUnits()) do
      if UnitGUID and UnitGUID(unit) == guid then
        local n, realm = UnitName(unit)
        if n then return (realm and realm ~= "") and (n .. "-" .. realm) or n end
      end
    end
    if GetPlayerInfoByGUID then
      local ok, _, _, _, _, _, n, realm = pcall(GetPlayerInfoByGUID, guid)
      if ok and type(n) == "string" and n ~= "" and not (DS.IsSecret and DS.IsSecret(n)) then
        return (type(realm) == "string" and realm ~= "") and (n .. "-" .. realm) or n
      end
    end
  end
  local unit = unitFor(name, guid)
  if unit then
    local n, realm = UnitName(unit)
    if n then return (realm and realm ~= "") and (n .. "-" .. realm) or n end
  end
  return name
end

function DS:IsMe(name, guid)
  if guid and UnitGUID and guid == UnitGUID("player") then return true end
  local me = UnitName("player")
  return me ~= nil and (name == me or (name and name:sub(1, #me + 1) == me .. " "))
end

-- Open a whisper to a player of the run (not to yourself).
function DS:Whisper(name, guid)
  if not name or self:IsMe(name, guid) then return false end
  local target = self:WhisperName(name, guid)
  if ChatFrame_SendTell then ChatFrame_SendTell(target) return true end
  return false
end

local function classColor(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end

local function makeCard()
  local c = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
  c:SetSize(CARD_W, CARD_H)
  -- hover: the top 5 of this category
  c:EnableMouse(true)
  c:SetScript("OnEnter", function(self)
    local card = self.card
    if not (GameTooltip and card and card.top) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(card.cat.title)
    for i, e in ipairs(card.top) do
      local r, g, b = classColor(e.class)
      GameTooltip:AddDoubleLine(i .. ". " .. e.who, e.text, r, g, b, 1, 1, 1)
    end
    if not DS:IsMe(card.who, card.guid) then
      GameTooltip:AddLine("Click: whisper " .. card.who, 0.5, 0.8, 1)
    end
    GameTooltip:Show()
  end)
  c:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" and self.card then DS:Whisper(self.card.who, self.card.guid) end
  end)
  c:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
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
  setPortrait(c, card.who, card.class, card.isMe, card.guid, card.display)
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

-- Loot in two columns: the item with its icon, who got it below.
local LOOT_COLS, LOOT_GAP, LOOT_H = 2, 12, 36
local LOOT_W = (W - 2 * PAD - LOOT_GAP) / LOOT_COLS

local function lootRow(i)
  local r = lootRows[i]
  if not r then
    r = CreateFrame("Button", nil, frame)
    r:SetSize(LOOT_W, LOOT_H - 4)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(28, 28)
    r.icon:SetPoint("LEFT")
    r.link = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.link:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, 0)
    r.link:SetWidth(LOOT_W - 36)
    r.link:SetJustifyH("LEFT")
    r.link:SetWordWrap(false)
    r.info = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.info:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 6, 0)
    r.info:SetWidth(LOOT_W - 36)
    r.info:SetJustifyH("LEFT")
    r.info:SetWordWrap(false)
    r.info:SetTextColor(0.75, 0.7, 0.6)
    r:SetScript("OnEnter", function(self)
      if GameTooltip and self.itemLink then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.itemLink)
        if self.who and not DS:IsMe(self.who, self.guid) then
          GameTooltip:AddLine("Click: whisper " .. self.who .. "  -  Shift-click: link the item", 0.5, 0.8, 1, true)
        end
        GameTooltip:Show()
      end
    end)
    -- click: whisper who got it (to ask for a trade); shift-click: the item into chat
    if r.RegisterForClicks then r:RegisterForClicks("LeftButtonUp") end
    r:SetScript("OnClick", function(self)
      if not self.itemLink then return end
      if IsShiftKeyDown and IsShiftKeyDown() and ChatEdit_InsertLink then
        ChatEdit_InsertLink(self.itemLink)
      elseif self.who then
        DS:Whisper(self.who, self.guid)
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

  -- loot pages: < Page 1 of 3 >
  local pager = CreateFrame("Frame", nil, frame)
  pager:SetSize(220, 22)
  pager.text = pager:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  pager.text:SetPoint("CENTER")
  pager.prev = CreateFrame("Button", nil, pager, "UIPanelButtonTemplate")
  pager.prev:SetSize(32, 20)
  pager.prev:SetText("<")
  pager.prev:SetPoint("LEFT")
  pager.prev:SetScript("OnClick", function() DS:LootPage(-1) end)
  pager.next = CreateFrame("Button", nil, pager, "UIPanelButtonTemplate")
  pager.next:SetSize(32, 20)
  pager.next:SetText(">")
  pager.next:SetPoint("RIGHT")
  pager.next:SetScript("OnClick", function() DS:LootPage(1) end)
  pager:Hide()
  frame.pager = pager
  DS.summaryPager = pager

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

local LOOT_PER_PAGE = 10   -- 5 rows of 2

-- One boss in the bosses section: a check for a kill, a cross for a wipe, grey when not fought.
local READY = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t "
local NOT_READY = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:14|t "
function DS.BossLineText(r)
  if r.killed then return READY .. r.name end
  if r.wiped then return NOT_READY .. r.name .. " |cff999999(wipe)|r" end
  return "|cff808080" .. r.name .. "|r"
end

-- Boss tiles: a round face in a gold ring with the name below. Killed: in colour with a
-- check; wiped on: a red cross; still to go: greyed out. A boss you have not seen yet has
-- a skull until Dungeon Stats has seen its face (target it or mouse over it once).
local TILES_PER_ROW, TILE_W, TILE_H = 6, 96, 78
local SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"

local function bossTile(i)
  local t = bossLines[i]
  if not t then
    t = CreateFrame("Frame", nil, frame)
    t:SetSize(TILE_W, TILE_H)
    t:EnableMouse(true)
    t.ring = t:CreateTexture(nil, "BORDER")
    t.ring:SetSize(48, 48)
    t.ring:SetPoint("TOP", 0, 0)
    t.ring:SetTexture("Interface\\Buttons\\WHITE8X8")
    round(t.ring)
    t.face = t:CreateTexture(nil, "ARTWORK")
    t.face:SetSize(42, 42)
    t.face:SetPoint("CENTER", t.ring, "CENTER")
    t.skull = t:CreateTexture(nil, "ARTWORK")
    t.skull:SetSize(26, 26)
    t.skull:SetPoint("CENTER", t.ring, "CENTER")
    t.skull:SetTexture(SKULL)
    t.mark = t:CreateTexture(nil, "OVERLAY")
    t.mark:SetSize(20, 20)
    t.mark:SetPoint("CENTER", t.ring, "BOTTOMRIGHT", -6, 6)
    t.name = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.name:SetPoint("TOP", t.ring, "BOTTOM", 0, -3)
    t.name:SetWidth(TILE_W - 4)
    t.name:SetHeight(26)
    t.name:SetJustifyV("TOP")
    t:SetScript("OnEnter", function(self)
      if GameTooltip and self.row then
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.row.name)
        GameTooltip:AddLine(self.row.killed and "Killed" or self.row.wiped and "Beat the group (wipe)" or "Not killed",
          0.8, 0.8, 0.8)
        if not DS:BossFace(self.row) then
          GameTooltip:AddLine("Target this boss once to see its face here.", 0.6, 0.6, 0.6, true)
        end
        GameTooltip:Show()
      end
    end)
    t:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    bossLines[i] = t
  end
  return t
end

local function fillBossTile(t, r)
  t.row = r
  local display = DS:BossFace(r)
  local drawn = false
  if display and SetPortraitTextureFromCreatureDisplayID then
    drawn = pcall(SetPortraitTextureFromCreatureDisplayID, t.face, display)
  end
  t.face:SetShown(drawn)
  t.skull:SetShown(not drawn)
  local done = r.killed
  if t.face.SetDesaturated then t.face:SetDesaturated(not done) end
  if t.skull.SetDesaturated then t.skull:SetDesaturated(not done) end
  t.face:SetAlpha(done and 1 or 0.45)
  t.skull:SetAlpha(done and 1 or 0.45)
  if done then
    t.ring:SetVertexColor(0.72, 0.57, 0.24, 1)
  else
    t.ring:SetVertexColor(0.35, 0.35, 0.35, 1)
  end
  if r.killed then
    t.mark:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready"); t.mark:Show()
  elseif r.wiped then
    t.mark:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady"); t.mark:Show()
  else
    t.mark:Hide()
  end
  t.name:SetText(r.name)
  if done then t.name:SetTextColor(1, 1, 1) else t.name:SetTextColor(0.5, 0.5, 0.5) end
  t:Show()
end

-- A face learned while the scoreboard is open: draw the tiles again.
function DS:RefreshBossFaces()
  if not (frame and frame:IsShown()) then return end
  for _, t in ipairs(bossLines) do
    if t:IsShown() and t.row then fillBossTile(t, t.row) end
  end
end

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
    name = "Wailing Caverns (sample)", duration = 38 * 60 + 12, instanceID = 43,
    killed = { ["Lady Anacondra"] = true, ["Lord Cobrahn"] = true, ["Kresh"] = true, ["Skum"] = true },
    wiped = { ["Lord Pythas"] = true },
    bossOrder = { "Lady Anacondra", "Lord Cobrahn", "Kresh", "Lord Pythas", "Skum" },
    stats = { players = players, kills = 64, rec = {
      hit = { who = a.name, amount = 912, what = "Ferocious Bite" },
      heal = { who = c.name, amount = 1410, what = "Greater Heal" },
      taken = { who = b.name, amount = 1840, what = "Mutanus the Devourer" } } },
    items = (function()
      -- 10 blue and purple items (one full page) and 2 greens: the green filter shows a second page
      local list = { { who = a.name, link = link, q = 4 }, { who = d.name, link = cloak, q = 3 } }
      local more = {
        { 6465, "Robe of the Moccasin", 3, c }, { 6460, "Cobrahn's Grasp", 3, b },
        { 10410, "Leggings of the Fang", 3, a }, { 6473, "Armor of the Fang", 3, d },
        { 6627, "Mutant Scale Breastplate", 3, b }, { 6631, "Living Root", 3, c },
        { 6630, "Seedcloud Buckler", 3, b }, { 5243, "Firebelcher", 3, d },
        { 10411, "Footpads of the Fang", 2, a }, { 10413, "Gloves of the Fang", 2, c },
      }
      local hex = { [2] = "1eff00", [3] = "0070dd" }
      for _, m in ipairs(more) do
        list[#list + 1] = { who = m[4].name, q = m[3],
          link = "|cff" .. hex[m[3]] .. "|Hitem:" .. m[1] .. "::::::::|h[" .. m[2] .. "]|h|r" }
      end
      return list
    end)(),
    rolls = { [link] = { needers = { a.name, b.name }, need = {}, winner = a.name,
      rolls = { [a.name] = { kind = "Need", roll = 87 }, [b.name] = { kind = "Need", roll = 54 } } },
      [cloak] = { needers = { d.name }, need = {}, winner = d.name, rolls = { [d.name] = { kind = "Need", roll = 71 } } } },
  }
end

-- The next (+1) or previous (-1) page of loot in the window.
function DS:LootPage(step)
  if not (frame and frame.run) then return end
  frame.lootPage = math.min(math.max((frame.lootPage or 1) + step, 1), frame.lootPages or 1)
  self:OpenSummary(frame.run)
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
  for _, l in ipairs(bossLines) do l:Hide() end

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

  -- the bosses: killed, wiped on, and (when the list is known) still to go
  local bosses = self.SummaryBosses and self:SummaryBosses(run)
  if bosses then
    nh = nh + 1
    placeHeader(sectionHeader(nh), "Bosses  " .. bosses.killed
      .. (bosses.total and ("/" .. bosses.total) or " killed"), y)
    y = y - 24
    local n = #bosses.rows
    for i, r in ipairs(bosses.rows) do
      local t = bossTile(i)
      local col, row = (i - 1) % TILES_PER_ROW, math.floor((i - 1) / TILES_PER_ROW)
      -- each row centred, so a short last row sits in the middle
      local inRow = math.min(TILES_PER_ROW, n - row * TILES_PER_ROW)
      local x = (W - inRow * TILE_W) / 2 + col * TILE_W
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y - row * TILE_H)
      fillBossTile(t, r)
    end
    y = y - math.ceil(n / TILES_PER_ROW) * TILE_H - 4
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
      r.itemLink, r.who, r.guid = nil, nil, nil
      r.icon:SetTexture(nil)
      r.link:SetText("")
      r.info:SetText("No " .. qualityLabel(self.db.lootMinQuality) .. " items in this run.")
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, y)
      r:Show()
      y = y - LOOT_H
    end
    -- pages of 10: the page stays while you look at the same run with the same filter
    local pages = math.max(1, math.ceil(#loot / LOOT_PER_PAGE))
    if frame.lootRun ~= run or frame.lootQuality ~= self.db.lootMinQuality then
      frame.lootPage = 1
      frame.lootRun, frame.lootQuality = run, self.db.lootMinQuality
    end
    local page = math.min(math.max(frame.lootPage or 1, 1), pages)
    frame.lootPage, frame.lootPages = page, pages
    local first = (page - 1) * LOOT_PER_PAGE
    local shown = 0
    for i = first + 1, math.min(#loot, first + LOOT_PER_PAGE) do
      local row = loot[i]
      shown = shown + 1
      local r = lootRow(shown)
      r.itemLink, r.who, r.guid = row.link, row.who, row.guid
      r.icon:SetTexture(itemIcon(row.link))
      r.link:SetText(row.link)
      r.info:SetText(row.text)
      local col, line = (shown - 1) % LOOT_COLS, math.floor((shown - 1) / LOOT_COLS)
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + col * (LOOT_W + LOOT_GAP), y - line * LOOT_H)
      r:Show()
    end
    y = y - math.ceil(shown / LOOT_COLS) * LOOT_H
    frame.pager:SetShown(pages > 1)
    if pages > 1 then
      frame.pager.text:SetText("Page " .. page .. " of " .. pages)
      if page > 1 then frame.pager.prev:Enable() else frame.pager.prev:Disable() end
      if page < pages then frame.pager.next:Enable() else frame.pager.next:Disable() end
      frame.pager:ClearAllPoints()
      frame.pager:SetPoint("TOP", frame, "TOP", 0, y - 2)
      y = y - 28
    end
  else
    frame.pager:Hide()
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
      setPortrait(c, c.card.who, c.card.class, c.card.isMe, c.card.guid, c.card.display)
    end
  end
end
