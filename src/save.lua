-- save.lua :: persistence.
-- Rules the player set:
--   * WINS are kept forever (a count of ascensions).
--   * the CURRENT run autosaves after every turn...
--   * ...but is DELETED on death. death is permanent; only victory is recorded.
-- also keeps a tiny settings blob (UI theme preference — not run progress).

local S = {}

local WINS_FILE = "wins.dat"
local GAME_FILE = "save.dat"
local CFG_FILE  = "cfg.dat"

-- ---- minimal serializer (numbers, strings, booleans, nested tables) ----
local function ser(v, out)
  local t = type(v)
  if t == "number" then
    out[#out + 1] = tostring(v)
  elseif t == "boolean" then
    out[#out + 1] = v and "true" or "false"
  elseif t == "string" then
    out[#out + 1] = string.format("%q", v)
  elseif t == "table" then
    out[#out + 1] = "{"
    -- array part
    local n = #v
    for i = 1, n do ser(v[i], out); out[#out + 1] = "," end
    -- hash part (string keys only)
    for k, val in pairs(v) do
      if not (type(k) == "number" and k >= 1 and k <= n) then
        out[#out + 1] = "[" .. string.format("%q", tostring(k)) .. "]="
        ser(val, out)
        out[#out + 1] = ","
      end
    end
    out[#out + 1] = "}"
  else
    out[#out + 1] = "nil"
  end
end

local function serialize(tbl)
  local out = {}
  ser(tbl, out)
  return table.concat(out)
end

local function deserialize(str)
  if not str or str == "" then return nil end
  local fn = loadstring or load
  local ok, chunk = pcall(fn, "return " .. str)
  if not ok or not chunk then return nil end
  local ok2, val = pcall(chunk)
  if not ok2 then return nil end
  return val
end

-- ---- wins ----
function S.getWins()
  if not love.filesystem.getInfo(WINS_FILE) then return 0 end
  local data = love.filesystem.read(WINS_FILE)
  return tonumber(data) or 0
end

function S.addWin()
  local w = S.getWins() + 1
  love.filesystem.write(WINS_FILE, tostring(w))
  return w
end

-- ---- current game ----
function S.hasGame()
  return love.filesystem.getInfo(GAME_FILE) ~= nil
end

function S.writeGame(tbl)
  love.filesystem.write(GAME_FILE, serialize(tbl))
end

function S.readGame()
  if not S.hasGame() then return nil end
  return deserialize(love.filesystem.read(GAME_FILE))
end

function S.clearGame()
  if S.hasGame() then love.filesystem.remove(GAME_FILE) end
end

-- ---- wipe everything (wins + current run); keeps settings ----
function S.resetAll()
  if love.filesystem.getInfo(WINS_FILE) then love.filesystem.remove(WINS_FILE) end
  if love.filesystem.getInfo(GAME_FILE) then love.filesystem.remove(GAME_FILE) end
end

-- ---- settings (theme) ----
function S.readCfg()
  if not love.filesystem.getInfo(CFG_FILE) then return {} end
  return deserialize(love.filesystem.read(CFG_FILE)) or {}
end

function S.writeCfg(tbl)
  love.filesystem.write(CFG_FILE, serialize(tbl))
end

return S
