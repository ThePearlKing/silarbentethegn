-- sim.lua :: the rite, the resources, the foes. Turn-based; nothing happens
-- until you speak. Combat is POSITIONAL: foes sit on tiles, block them, and are
-- struck from an ADJACENT tile with `kresh <aspect>`. No ambushes, no battle
-- screen — when a foe's tile clears, you may pass.

local W = require("src.world")
local E = require("src.enemies")
local L = require("src.lang")

local M = {}

local function clamp(v) if v < 0 then return 0 elseif v > 100 then return 100 else return v end end

local function reveal(id)
  local n = M.nodes[id]
  n.seen = true
  for _, dir in ipairs(W.allDirs) do
    local to = n.exits[dir]
    if to then M.nodes[to].seen = true end
  end
end

local function liveFoe(id)
  local f = M.foes and M.foes[id]
  if f and f.alive then return f end
end

-- foes on adjacent tiles. with `dir`, the foe in that direction (or nil);
-- without, the first adjacent foe and the direction toward it.
local function adjacentFoe(dir)
  local n = M.nodes[M.node]
  if dir then local to = n.exits[dir]; return to and liveFoe(to) end
  for _, d in ipairs(W.allDirs) do
    local to = n.exits[d]
    local f = to and liveFoe(to)
    if f then return f, d end
  end
end

-- ---------------------------------------------------------------- new run ----
function M.reset(seed)
  M.seed   = seed or 1
  M.nodes, M.start = W.build(M.seed)
  M.node   = M.start
  M.vyr    = 10
  M.thuum  = 55
  M.gloam  = 8
  M.seth   = 100
  M.wake   = 0
  M.sig    = { za = 0, qor = 0, neth = 0 }
  M.tik    = 0
  M.kills  = 0
  M.status = "play"
  M.gatesOpen = {}            -- gateId -> true once inspected open
  M.foes = {}                 -- nodeId -> enemy instance (sits on the tile)
  for id, n in pairs(M.nodes) do
    if n.guardian then
      local f = E.new(n.guardian, 1)   -- deterministic starting aspect
      f._node = id
      M.foes[id] = f
    end
  end
  M.nodes[M.node].visited = true
  reveal(M.node)
end

-- derived fvalues
function M.attune() return math.min(M.sig.za, M.sig.qor, M.sig.neth) end
function M.gnos()
  local c = 0
  for _, n in pairs(M.nodes) do if n.visited then c = c + 1 end end
  return c
end
function M.depf() return M.nodes[M.node].sec end
function M.sectionName() return W.sectionNames[M.nodes[M.node].sec] end

-- the foe you'd strike right now, and the direction toward it
function M.foe()
  local f, dir = adjacentFoe()
  if f then
    return { name = f.name, glamour = math.floor(f.glamour), max = f.glamourMax, dir = dir, boss = f.boss }
  end
  return nil
end
-- a foe sitting on a specific tile (for the map)
function M.foeAt(id)
  local f = liveFoe(id)
  if f then return { name = f.name, glamour = math.floor(f.glamour), max = f.glamourMax } end
  return nil
end

-- ----------------------------------------------------------------- helpers ---
local function entry(kind, text) return { kind = kind, text = text } end
local function sys(key) return entry("sys", L.msg[key]) end
local function node() return M.nodes[M.node] end

local function exitsLine(n)
  local parts = {}
  for _, dir in ipairs(W.allDirs) do
    if n.exits[dir] then parts[#parts + 1] = "{" .. dir .. "}" end
  end
  if #parts == 0 then return "No way breathes onward." end
  return "Ways breathe toward " .. table.concat(parts, " ") .. "."
end

local function gateClause(n)
  if not n.gatehere then return "" end
  if M.gatesOpen[n.gatehere] then return "  You stand at an open {gate}."
  else return "  You stand at a sealed {gate}; only {seth} will read it open." end
end

-- note adjacent foes in prose so you always know they're there
local function foeClause()
  local f, dir = adjacentFoe()
  if not f then return "" end
  return "  A {" .. f.name .. "} holds the tile to your {" .. dir .. "} — strike it: kresh " .. dir .. "."
end

local function narrate(n)
  return entry("narr", "{" .. n.name .. "} — " .. n.desc .. gateClause(n) .. foeClause() .. "  " .. exitsLine(n))
end

-- passive drift each spent turn
local function tick()
  M.tik = M.tik + 1
  M.thuum = clamp(M.thuum + 3)
  M.seth  = clamp(M.seth - (0.8 + M.gloam * 0.04))
  M.gloam = clamp(M.gloam - 0.5)
  -- sigils do NOT bleed over time: a lit sigil stays lit so the long treks back
  -- to re-light the others aren't an unwinnable race.
end

local function checkDeath(out)
  if M.status ~= "play" then return end
  if M.gloam >= 100 then
    M.status = "devoured"; out[#out + 1] = entry("sys", "{gloam thenn vaen}")
  elseif M.seth <= 0 then
    M.status = "dissolved"; out[#out + 1] = entry("sys", "{bul narth vaen}")
  end
end

local function onEnter()
  local n = node()
  n.visited = true
  reveal(M.node)
  if n.type == "hazard" then M.gloam = clamp(M.gloam + 9); M.harm = (M.harm or 0) + 9 end
  if n.type == "font" then M.gloam = clamp(M.gloam - 4); M.thuum = clamp(M.thuum + 8) end
end

-- ----------------------------------------------------------------- actions ---
local function doMove(dir, out)
  local n = node()
  if not n.exits[dir] then out[#out + 1] = sys("nopath"); return false end
  local gid = n.gated[dir]
  if gid and not M.gatesOpen[gid] then out[#out + 1] = sys("gatesealed"); return false end
  local target = n.exits[dir]
  if liveFoe(target) then out[#out + 1] = sys("foeblock"); return false end  -- can't enter a foe's tile
  local prevSec = n.sec
  M.node = target
  if node().sec ~= prevSec then
    out[#out + 1] = entry("sys", "{" .. W.sectionNames[node().sec] .. "}")
  end
  out[#out + 1] = narrate(node())
  onEnter()
  return true
end

local function doSense(out)
  local n = node()
  if n.gatehere then
    if not M.gatesOpen[n.gatehere] then M.gatesOpen[n.gatehere] = true; out[#out + 1] = sys("gateopen")
    else out[#out + 1] = sys("gatestood") end
    return true
  end
  local hint
  if n.type == "shrine_za" then hint = "{morr sigil thenn vorth}"
  elseif n.type == "shrine_qor" then hint = "{qhel sigil thenn vorth}"
  elseif n.type == "shrine_neth" then hint = "{zyth sigil thenn vorth}"
  elseif n.type == "heart" then hint = "{si lar uthenn here}"
  elseif n.type == "font" then hint = "{thuum well drink here}"
  elseif n.type == "hazard" then hint = "{gloam rot beware}"
  else hint = "{seh qorun na sigil here}" end
  out[#out + 1] = entry("sys", hint)
  return true
end

local function doChannel(out)
  local n = node()
  local which = n.type == "shrine_za" and "za" or n.type == "shrine_qor" and "qor"
             or n.type == "shrine_neth" and "neth" or nil
  if not which then out[#out + 1] = sys("noshrine"); return false end
  if M.thuum < 12 then out[#out + 1] = sys("noessence"); return false end
  M.thuum = clamp(M.thuum - 12)
  M.sig[which] = clamp(M.sig[which] + 20 + M.vyr * 0.12)
  M.vyr = clamp(M.vyr + 4)
  M.gloam = clamp(M.gloam + 4)
  out[#out + 1] = sys("channeled")
  return true
end

local function doEssence(out)
  local big = (node().type == "font")
  M.thuum = clamp(M.thuum + (big and 45 or 28))
  M.gloam = clamp(M.gloam + (big and 4 or 12))   -- gloam is ammo: drawing loads it
  M.vyr = clamp(M.vyr - 3)
  out[#out + 1] = sys("drawn")
  return true
end

local function doRest(out)
  M.seth = clamp(M.seth + 16)
  M.gloam = clamp(M.gloam - 6)
  out[#out + 1] = sys("rested")
  return true
end

local function doPurge(out)
  M.gloam = clamp(M.gloam - 30)
  M.seth = clamp(M.seth - 8)
  M.vyr = clamp(M.vyr - 6)
  out[#out + 1] = sys("purged")
  return true
end

local function doAttune(out)
  if M.vyr < 25 then out[#out + 1] = sys("novyr"); return false end
  M.vyr = M.vyr - 25
  local lowk = "za"
  if M.sig.qor < M.sig[lowk] then lowk = "qor" end
  if M.sig.neth < M.sig[lowk] then lowk = "neth" end
  M.sig[lowk] = clamp(M.sig[lowk] + 26)
  out[#out + 1] = sys("attuned")
  return true
end

local function doUtter(out)
  if node().type ~= "heart" then out[#out + 1] = sys("notheart"); return false end
  -- the sigils must hold light to give: drained to nothing, the Word breaks.
  if M.attune() <= 0 then
    M.gloam = clamp(M.gloam + 10)
    out[#out + 1] = sys("discord"); return true   -- spent: go re-light the shrines
  end
  -- uttering spends ALL three sigils (-20 each); the wake it gives scales with how
  -- lit they are (the lowest sigil). A full charge drained 100 -> 0 yields ~50 UGNA,
  -- so the rite needs TWO full sigil-charges with the long backtrack between them.
  local att = M.attune() / 100
  local gain = 16.7 * att
  M.wake = clamp(M.wake + gain)
  M.gloam = clamp(M.gloam + 12)
  M.sig.za   = clamp(M.sig.za - 20)
  M.sig.qor  = clamp(M.sig.qor - 20)
  M.sig.neth = clamp(M.sig.neth - 20)
  out[#out + 1] = entry("sys", "{ugnaken thenn} " .. math.floor(gain))
  if M.wake >= 100 then M.status = "ascended" end
  return true
end

-- DIRECTIONAL combat: hurl your GLOAM at the foe on the tile in `dir`.
local function doStrike(dir, out)
  if not (dir and L.dirset[dir]) then out[#out + 1] = sys("nodir"); return false end
  local foe = adjacentFoe(dir)
  if not foe then out[#out + 1] = sys("nofoe"); return false end
  local dmg = math.floor(M.gloam * 1.5) + 8
  foe.glamour = foe.glamour - dmg
  M.gloam = clamp(M.gloam - 30)                   -- a gout of corruption is spent
  out[#out + 1] = entry("sys", "{kresh thenn vaen} " .. dmg)
  if foe.glamour <= 0 then
    foe.alive = false; M.kills = M.kills + 1
    local r = foe.reward or {}
    if r.vyr then M.vyr = clamp(M.vyr + r.vyr) end
    if r.thuum then M.thuum = clamp(M.thuum + r.thuum) end
    out[#out + 1] = sys("slain")
    if r.note then out[#out + 1] = entry("sys", r.note) end
    return true                                    -- the tile clears; no counter
  end
  -- the foe bites your grip (seth); striking only SPENDS gloam as ammo, never raises it
  M.seth = clamp(M.seth - foe.bite)
  M.harm = (M.harm or 0) + foe.bite
  return true
end

-- --------------------------------------------------------------- dispatch ----
-- returns: entries(list), action(string|nil "codex")
function M.command(raw)
  local out = {}
  if M.status ~= "play" then return out, nil end
  M.harm = 0   -- event damage this turn (hazards / foe bites), NOT the passive bleed
  local words = {}
  for w in raw:lower():gmatch("%S+") do words[#words + 1] = w end
  if #words == 0 then return out, nil end

  local head = words[1]
  if L.dirset[head] then            -- bare direction = move
    doMove(head, out)
    checkDeath(out)
    if M.status == "play" then tick(); checkDeath(out) end
    return out, nil
  end

  local verb = L.verbs[head]
  if not verb then out[#out + 1] = sys("unknown"); return out, nil end

  local spends = true
  if verb == "move" then
    local dir = words[2]
    if not (dir and L.dirset[dir]) then out[#out + 1] = sys("nopath"); spends = false
    else doMove(dir, out) end
  elseif verb == "sense" then doSense(out)
  elseif verb == "channel" then doChannel(out)
  elseif verb == "essence" then doEssence(out)
  elseif verb == "rest" then doRest(out)
  elseif verb == "purge" then doPurge(out)
  elseif verb == "attune" then doAttune(out)
  elseif verb == "utter" then doUtter(out)
  elseif verb == "strike" then doStrike(words[2], out)
  elseif verb == "codex" then return out, "codex"
  end

  if spends then
    checkDeath(out)
    if M.status == "play" then tick(); checkDeath(out) end
  end
  return out, nil
end

function M.intro()
  reveal(M.node)
  return { narrate(node()) }
end

-- ----------------------------------------------------------------- save -----
function M.snapshot()
  local visited, seen, slain, foeHP = {}, {}, {}, {}
  for id, n in pairs(M.nodes) do
    if n.visited then visited[id] = true end
    if n.seen then seen[id] = true end
  end
  for id, f in pairs(M.foes) do
    if not f.alive then slain[id] = true else foeHP[id] = math.floor(f.glamour) end
  end
  local gates = {}
  for id, v in pairs(M.gatesOpen) do if v then gates[id] = true end end
  return {
    v = 3, seed = M.seed, vyr = M.vyr, thuum = M.thuum, gloam = M.gloam, seth = M.seth, wake = M.wake,
    za = M.sig.za, qor = M.sig.qor, neth = M.sig.neth, kills = M.kills,
    node = M.node, tik = M.tik, visited = visited, seen = seen, slain = slain, foeHP = foeHP, gates = gates,
  }
end

function M.restore(t)
  M.reset(t.seed or 1)
  M.vyr, M.thuum, M.gloam = t.vyr or 10, t.thuum or 55, t.gloam or 8
  M.seth, M.wake = t.seth or 100, t.wake or 0
  M.sig.za, M.sig.qor, M.sig.neth = t.za or 0, t.qor or 0, t.neth or 0
  M.node = t.node or M.start
  M.tik, M.kills = t.tik or 0, t.kills or 0
  if t.visited then for id in pairs(t.visited) do if M.nodes[id] then M.nodes[id].visited = true end end end
  if t.seen then for id in pairs(t.seen) do if M.nodes[id] then M.nodes[id].seen = true end end end
  if t.slain then for id in pairs(t.slain) do if M.foes[id] then M.foes[id].alive = false end end end
  if t.foeHP then for id, hp in pairs(t.foeHP) do if M.foes[id] then M.foes[id].glamour = hp end end end
  if t.gates then for id in pairs(t.gates) do M.gatesOpen[id] = true end end
end

return M
