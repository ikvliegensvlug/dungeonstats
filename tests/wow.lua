-- Minimal fake of the WoW API: just enough to load ChatBanner and drive it with events.
-- Unknown widget methods are harmless no-ops, so only behaviour the tests check is modelled.

unpack = unpack or table.unpack
SlashCmdList = {}
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

local now = 1000
function GetTime() return now end
function Advance(sec) now = now + sec end

Printed = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) Printed[#Printed + 1] = msg end }

AllFrames = {}
local events = {}

local Methods = {}
local function newObj(kind, name, parent)
  local o = { kind = kind, name = name, parent = parent, scripts = {}, points = {},
              shown = true, alpha = 1, w = 0, h = 0, text = "", checked = false, value = 0 }
  return setmetatable(o, { __index = function(_, k)
    return Methods[k] or function() end
  end })
end

function Methods:SetScript(n, f) self.scripts[n] = f end
function Methods:GetScript(n) return self.scripts[n] end
function Methods:HookScript(n, f)
  local old = self.scripts[n]
  self.scripts[n] = function(...) if old then old(...) end f(...) end
end
function Methods:SetSize(w, h) self.w, self.h = w, h end
function Methods:SetWidth(w) self.w = w end
function Methods:SetHeight(h) self.h = h end
function Methods:Disable() self.disabled = true end
function Methods:Enable() self.disabled = false end
function Methods:GetWidth() return self.w end
function Methods:GetHeight() return self.h end
function Methods:GetScale() return self.scale or 1 end
function Methods:GetEffectiveScale() return 1 end
function Methods:GetLeft() return self.left or 0 end
function Methods:GetTop() return self.top or 0 end
CursorX = 0
function GetCursorPosition() return CursorX, 0 end
function Methods:Show() self.shown = true end
function Methods:Hide() self.shown = false end
function Methods:SetShown(v) self.shown = v and true or false end
function Methods:IsShown() return self.shown end
function Methods:IsVisible() return self.shown end
function Methods:SetAlpha(a) self.alpha = a end
function Methods:GetAlpha() return self.alpha end
function Methods:SetText(t) self.text = t end
function Methods:GetText() return self.text end
function Methods:GetStringWidth() return #(self.text or "") * 7 end
function Methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function Methods:ClearAllPoints() self.points = {} end
function Methods:GetPoint() local p = self.points[1] or {} return p[1], p[2], p[3], p[4], p[5] end
function Methods:GetFrameLevel() return 1 end
function Methods:GetName() return self.name end
function Methods:SetChecked(v) self.checked = v end
function Methods:GetChecked() return self.checked end
function Methods:SetMinMaxValues(a, b) self.min, self.max = a, b end
function Methods:SetValue(v)
  self.value = v
  if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end
end
function Methods:GetValue() return self.value end
function Methods:SetScale(s) self.scale = s end
-- like the game: no tex coords on a texture with a mask
function Methods:SetMask(m) self.mask = m end
function Methods:SetTexCoord(...)
  if rawget(self, "mask") then error("Texture:SetTexCoord(): Cannot set tex coords when texture has mask.", 2) end
  self.texCoord = { ... }
end
function Methods:SetTexture(t) self.texture = t end
function Methods:SetTextColor(r, g, b) self.color = { r, g, b } end
function Methods:IsObjectType(t) return self.kind == t end
function Methods:CreateTexture() return newObj("Texture", nil, self) end
function Methods:CreateMaskTexture() return newObj("MaskTexture", nil, self) end
function Methods:GetParent() return self.parent end
function Methods:AddMaskTexture(m) self.mask = m end
function Methods:SetAtlas(a) self.atlas = a end
function Methods:CreateFontString() return newObj("FontString", nil, self) end
function Methods:RegisterEvent(e)
  events[e] = events[e] or {}
  table.insert(events[e], self)
end
function Methods:Click(button)
  if self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton") end
end

function CreateFrame(kind, name, parent, template)
  local f = newObj(kind, name, parent)
  f.template = template
  if name then _G[name] = f end
  AllFrames[#AllFrames + 1] = f
  return f
end

UIParent = newObj("Frame", "UIParent")

function Fire(event, ...)
  for _, f in ipairs(events[event] or {}) do
    if f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
  end
end

-- game state
InCombat = false
function InCombatLockdown() return InCombat end
-- the group: GroupNames["party1"] = "Bram", GroupClasses["Bram"] = "WARRIOR"
GroupNames, GroupClasses = {}, { Aztek = "DRUID" }
function UnitName(unit)
  if unit == nil or unit == "player" then return "Aztek" end
  return GroupNames[unit]
end
function UnitExists(unit) return UnitName(unit) ~= nil end
function UnitClass(unit)
  local n = UnitName(unit)
  local c = n and GroupClasses[n]
  return c, c
end
function UnitGUID(unit) return UnitName(unit) and ("Player-" .. UnitName(unit)) or nil end
InGroup, InRaid = false, false
function IsInGroup() return InGroup end
function IsInRaid() return InRaid end
Sent = {}
function SendChatMessage(msg, channel) Sent[#Sent + 1] = channel .. ":" .. msg end
Portraits = {}
function SetPortraitTexture(tex, unit) tex.portraitUnit = unit; Portraits[#Portraits + 1] = unit end
C_Texture = { GetAtlasInfo = function(a) if a:find("^classicon%-") then return { width = 64 } end end }
function GetItemIcon() return "Interface/Icons/INV_Sword_04" end
Timers = {}
C_Timer = { After = function(_, fn) Timers[#Timers + 1] = fn end }
function RunTimers() local list = Timers; Timers = {}; for _, fn in ipairs(list) do fn() end end
Now = 100000
function time() return Now end
bit = { band = load("return function(a, b) return a & b end")() }
-- the game's damage meter: MeterSessions = { { id = 1, duration = 60, [0] = { sources... }, ... } }
-- keyed by Enum.DamageMeterType (0 damage, 2 healing, 7 taken, 9 deaths)
MeterSessions = {}
SecretValues = false
function issecretvalue() return SecretValues end
C_DamageMeter = {
  GetAvailableCombatSessions = function()
    local out = {}
    for _, s in ipairs(MeterSessions) do out[#out + 1] = { sessionID = s.id, name = "Fight", durationSeconds = s.duration } end
    return out
  end,
  GetCombatSessionFromID = function(id, kind)
    for _, s in ipairs(MeterSessions) do
      if s.id == id then return { combatSources = s[kind] or {}, durationSeconds = s.duration } end
    end
  end,
}
CLASS_ICON_TCOORDS = { DRUID = { 0.75, 1, 0, 0.25 }, WARRIOR = { 0, 0.25, 0, 0.25 } }
RAID_CLASS_COLORS = { DRUID = { r = 1, g = 0.49, b = 0.04 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
function Ambiguate(name) return (name:gsub("%-.*$", "")) end
C_AddOns = { GetAddOnMetadata = function() return "1.0.0" end }
ChatTypeInfo = setmetatable({}, { __index = function() return { r = 0.5, g = 0.6, b = 0.7 } end })
SOUNDKIT = { TELL_MESSAGE = 3081 }
SoundsPlayed = 0
function PlaySound() SoundsPlayed = SoundsPlayed + 1 end

-- chat calls the alerts make
Calls = {}
function ChatFrame_SendTell(name) Calls[#Calls + 1] = "tell:" .. name end
function ChatFrame_SendBNetTell(name) Calls[#Calls + 1] = "bnet:" .. name end
function ChatFrame_OpenChat(text) Calls[#Calls + 1] = "open:" .. text end

-- chat filters (other add-ons)
Filters = {}
function ChatFrame_GetMessageEventFilters(event) return Filters[event] end

-- options panel
Settings = {
  RegisterCanvasLayoutCategory = function(frame, name)
    Settings.registered = { frame = frame, name = name }
    return { GetID = function() return 42 end }
  end,
  RegisterAddOnCategory = function() end,
  OpenToCategory = function(id) Settings.opened = id end,
}
function UIDropDownMenu_Initialize(dd, fn) dd.init = fn end
function UIDropDownMenu_SetWidth() end
function UIDropDownMenu_SetText(dd, t) dd.text = t end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton() end
function CloseDropDownMenus() end
