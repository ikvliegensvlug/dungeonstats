-- Dungeon Stats: dungeon statistics from the game's own damage meter (C_DamageMeter).
-- Add-ons may no longer read the combat log on this client: registering for it
-- is blocked ("... has been blocked from an action..."). The built-in
-- meter keeps one session per fight; at the end of a run we add up the sessions
-- that started after we entered. Its numbers are secret during combat, so they
-- are only read out of combat, after leaving the dungeon.
local _, ns = ...
local DS = ns.DS

local function meter() return C_DamageMeter end

local T = (Enum and Enum.DamageMeterType) or {}
local ENEMY = (Enum and Enum.DamageMeterSourceDisplayType and Enum.DamageMeterSourceDisplayType.Enemy) or 2

-- Our stat -> the meter's type.
local FIELDS = {
  dmg    = T.DamageDone  or 0,
  heal   = T.HealingDone or 2,
  taken  = T.DamageTaken or 7,
  deaths = T.Deaths      or 9,
}

-- A value we may read and calculate with (not nil, not secret).
local function readable(v)
  if v == nil then return false end
  if issecretvalue and issecretvalue(v) then return false end
  if canaccessvalue and not canaccessvalue(v) then return false end
  return true
end
DS.Readable = readable

local function short(name)
  return (Ambiguate and Ambiguate(name, "short")) or (name:gsub("%-.*$", ""))
end

-- Units that can be in your group, to find who is still around (portraits).
local function groupUnits()
  local units = { "player" }
  for i = 1, 4 do units[#units + 1] = "party" .. i end
  if IsInRaid and IsInRaid() then
    for i = 1, 40 do units[#units + 1] = "raid" .. i end
  end
  return units
end
DS.GroupUnits = groupUnits

-- The meter's sessions as { id, duration }, or nil when it cannot be read.
local function sessions()
  local dm = meter()
  if not (dm and dm.GetAvailableCombatSessions) then return nil end
  local ok, list = pcall(dm.GetAvailableCombatSessions)
  if not ok or type(list) ~= "table" then return nil end
  local out = {}
  for _, s in ipairs(list) do
    if type(s) == "table" and readable(s.sessionID) then
      out[#out + 1] = { id = s.sessionID, duration = readable(s.durationSeconds) and s.durationSeconds or 0 }
    end
  end
  return out
end

-- Called when a run starts: remember the newest session, so only later fights count.
function DS:StartStats(run)
  local list = sessions()
  if not list then return end
  local newest = 0
  for _, s in ipairs(list) do if s.id > newest then newest = s.id end end
  run.statsFrom = newest
end

local function addSource(stats, field, src, duration)
  if type(src) ~= "table" then return end
  if src.sourceDisplayType == ENEMY then return end
  if not (readable(src.name) and readable(src.totalAmount)) then return end
  local amount = src.totalAmount
  if type(amount) ~= "number" then return end
  -- the deaths list names who died in that fight; its amount is 0 on this client
  if field == "deaths" and amount <= 0 then amount = 1 end
  if amount <= 0 then return end
  local name = short(src.name)
  local p = stats.players[name]
  if not p then
    p = { dmg = 0, heal = 0, taken = 0, deaths = 0, active = 0 }
    stats.players[name] = p
  end
  if readable(src.classFilename) then p.class = src.classFilename end
  -- the meter marks you; your name there may not match UnitName exactly
  if src.isLocalPlayer == true then p.isMe = true end
  if readable(src.sourceGUID) then p.guid = src.sourceGUID end
  p[field] = p[field] + amount
  if field == "dmg" then p.active = p.active + (duration or 0) end
end

-- At the end of a run (out of combat): add up every fight since the start.
function DS:CollectStats(run)
  local dm = meter()
  if not (dm and dm.GetCombatSessionFromID) or not run.statsFrom then return end
  local list = sessions()
  if not list then return end
  local stats = { players = {}, rec = {}, kills = 0 }
  for _, s in ipairs(list) do
    if s.id > run.statsFrom then
      for field, meterType in pairs(FIELDS) do
        local ok, session = pcall(dm.GetCombatSessionFromID, s.id, meterType)
        if ok and type(session) == "table" and type(session.combatSources) == "table" then
          local duration = readable(session.durationSeconds) and session.durationSeconds or s.duration
          for _, src in ipairs(session.combatSources) do
            pcall(addSource, stats, field, src, duration)
            if self.db.debug then
              local log = self.db.debug.meter
              log[#log + 1] = string.format("session %s %s: %s %s%s", tostring(s.id), field,
                readable(src.name) and tostring(src.name) or "<secret>",
                readable(src.totalAmount) and tostring(src.totalAmount) or "<secret>",
                src.isLocalPlayer == true and " (you)" or "")
              while #log > 60 do table.remove(log, 1) end
            end
          end
        end
      end
    end
  end
  if next(stats.players) then run.stats = stats end
end

function DS:HasStats(run)
  return run.stats ~= nil and next(run.stats.players) ~= nil
end
