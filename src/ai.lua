-- ai.lua :: the solver. Knows the STRATEGY and the world's shape (shrines in
-- sections 1/3/5, heart in 5, one forward gate per section) but NOT the tile layout.
-- It exploits adjacency (a tile it can SEE is a target it heads straight for) and,
-- crucially, it ROUTES AROUND foes whenever a foe-free path exists — foes only hurt
-- you when YOU strike, so it never wastes turns fighting something it can walk past.
-- It only breaks through (fights) when a foe genuinely blocks the way to its goal.

local W = require("src.world")

local AI = {}
local ALLDIRS = W.allDirs
local TARGET = 100          -- charge sigils fully, so one drain (100->0) gives ~50 ugna
local UTTER_FLOOR = 15       -- keep uttering until the sigils are nearly spent, then backtrack
local SHRINE_SEC = { [1] = true, [3] = true, [5] = true }

local function known(n) return n.visited or n.seen end

-- BFS over WALKABLE tiles ONLY (entered/seen, NO live foe, open/no gate). This is the
-- "go around" pathfinder. Goal may be a seen tile we step onto. Returns dir / "@here" / nil.
function AI.bfs(sim, pred)
  if pred(sim.nodes[sim.node]) then return "@here" end
  local prev, q, vis, head = {}, { sim.node }, { [sim.node] = true }, 1
  while head <= #q do
    local cur = q[head]; head = head + 1
    local n = sim.nodes[cur]
    for _, dir in ipairs(ALLDIRS) do
      local to = n.exits[dir]
      if to and not vis[to] then
        local tn = sim.nodes[to]
        local foe = sim.foes[to] and sim.foes[to].alive
        if pred(tn) and not foe then
          prev[to] = { cur, dir }
          local node = to
          while prev[node][1] ~= sim.node do node = prev[node][1] end
          return prev[node][2]
        end
        local gid = n.gated[dir]
        if (tn.visited or tn.seen) and not foe and (not gid or sim.gatesOpen[gid]) then
          vis[to] = true; prev[to] = { cur, dir }; q[#q + 1] = to
        end
      end
    end
  end
end

local function moveStep(sim, dir)
  local n = sim.nodes[sim.node]
  local gid = n.gated[dir]
  if gid and not sim.gatesOpen[gid] then return "seth" end   -- open a gate we stand on
  return dir
end

local function goalDir(sim, pred)
  local d = AI.bfs(sim, pred)
  if d and d ~= "@here" then return moveStep(sim, d) end
  return nil
end

-- load ammo / strike a specific blocking foe (only as much gloam as it needs)
local function combat(sim, foe, dir, noThuun)
  local kill = math.ceil((foe.glamour - 8) / 1.5)
  if sim.gloam >= kill then return "kresh " .. dir end          -- already lethal: strike
  if sim.seth <= 16 then return "lu" end
  if not noThuun and sim.gloam < math.min(kill, 74) and sim.gloam < 78 and sim.seth > foe.bite + 4 then
    return "thuun"
  end
  return "kresh " .. dir
end

-- BFS to the target ALLOWING passage through foe tiles (we'll clear them). Only used
-- when no foe-free route exists. Walk clear tiles; the moment the next tile on the
-- path is a foe, fight it. The boss is impassable while we still need sigils.
local function breakThrough(sim, isTarget, needSig, noThuun, confineSec)
  -- BFS to the goal. First PASS routes AROUND bosses (wardens) — preferred, so we
  -- only fight one when there's no way around. allowBoss=true is the last resort,
  -- which also means the warden-ringed heart costs exactly one warden to breach.
  -- confineSec keeps the search INSIDE one section (no gate-crossing) — used by the
  -- explore-to-find-the-shrine/gate fallback so it can't wander back through a gate.
  local function bfs(allowBoss)
    local prev, q, vis, head = {}, { sim.node }, { [sim.node] = true }, 1
    while head <= #q do
      local cur = q[head]; head = head + 1
      if cur ~= sim.node and isTarget(sim.nodes[cur]) then return prev, cur end
      local n = sim.nodes[cur]
      for _, dir in ipairs(ALLDIRS) do
        local to = n.exits[dir]
        if to and not vis[to] and (sim.nodes[to].visited or sim.nodes[to].seen)
            and not (confineSec and (dir == "klor" or sim.nodes[to].sec ~= confineSec)) then
          local gid = n.gated[dir]
          local foe = sim.foes[to] and sim.foes[to].alive and sim.foes[to]
          local pass = (not gid or sim.gatesOpen[gid])
          if foe and foe.boss and not allowBoss then pass = false end
          if pass then vis[to] = true; prev[to] = { cur, dir }; q[#q + 1] = to end
        end
      end
    end
  end
  local prev, goal = bfs(false)
  if not goal then prev, goal = bfs(true) end   -- last resort: breach a warden
  if not goal then return nil end
  local node = goal
  while prev[node][1] ~= sim.node do node = prev[node][1] end
  local dir = prev[node][2]
  local foe = sim.foes[node] and sim.foes[node].alive and sim.foes[node]
  if foe then return combat(sim, foe, dir, noThuun) end
  return moveStep(sim, dir)
end

-- does entering n reveal still-unseen ground in its section?
local function revealsNew(sim, n)
  for _, dir in ipairs(W.dirOrder) do
    local to = n.exits[dir]
    if to and sim.nodes[to].sec == n.sec and not sim.nodes[to].seen then return true end
  end
  return false
end

-- sparse explorer (grid dirs, foe-free): walk across seen ground to the nearest
-- unentered tile whose entry reveals new ground. Skips rows/cols already in view.
local function uncover(sim)
  local prev, q, vis, head = {}, { sim.node }, { [sim.node] = true }, 1
  local sec = sim.nodes[sim.node].sec
  while head <= #q do
    local cur = q[head]; head = head + 1
    local n = sim.nodes[cur]
    for _, dir in ipairs(W.dirOrder) do
      local to = n.exits[dir]
      if to and not vis[to] then
        local tn = sim.nodes[to]
        local foe = sim.foes[to] and sim.foes[to].alive
        if tn.sec == sec and not foe then
          if not tn.visited and revealsNew(sim, tn) then
            prev[to] = { cur, dir }
            local node = to
            while prev[node][1] ~= sim.node do node = prev[node][1] end
            return moveStep(sim, prev[node][2])
          end
          if tn.visited or tn.seen then vis[to] = true; prev[to] = { cur, dir }; q[#q + 1] = to end
        end
      end
    end
  end
end

local function seenShrineIn(sim, sec)
  for _, n in pairs(sim.nodes) do
    if n.sec == sec and known(n) and n.type and n.type:match("^shrine_") then return true end
  end
  return false
end

function AI.decide(sim, noThuun)
  local here = sim.nodes[sim.node]
  local curSec = here.sec

  -- maintenance ONLY at a critical edge
  if sim.gloam >= 82 then return "svael" end
  if sim.seth <= 20 then return "lu" end

  -- act on the tile underfoot
  local sk = here.type and here.type:match("^shrine_(%a+)$")
  if sk and sim.sig[sk] < TARGET then
    if sim.thuum < 12 then return "thuun" end
    return "vorth"
  end
  if here.type == "heart" and sim.attune() >= UTTER_FLOOR then return "uthenn" end

  local needSig = math.min(sim.sig.za, sim.sig.qor, sim.sig.neth) < TARGET
  local function unlitShrine(n) return n.type and n.type:match("^shrine_") and sim.sig[n.type:match("_(%a+)")] < TARGET end
  local function fwdGate(n) return n.type == "gate" and n.exits.klor and sim.nodes[n.exits.klor].sec > curSec end
  local function frontier(n) return (n.visited or n.seen) and revealsNew(sim, n) end

  -- reach a target: go AROUND foes if a clear path exists, else break through it
  local function pursue(isTarget)
    local d = goalDir(sim, isTarget)
    if d then return d end
    return breakThrough(sim, isTarget, needSig, noThuun)
  end

  if needSig then
    -- 1) a known unlit shrine (drives the backtrack too)
    local m = pursue(function(n) return known(n) and unlitShrine(n) end)
    if m then return m end
    -- 2) NEVER leave a shrine-section until its shrine is lit. If the shrine is still
    --    hidden (ring-enclosed), explore — and if walled in by foes, break through.
    local secSig = ({ [1] = "za", [3] = "qor", [5] = "neth" })[curSec]
    if secSig and sim.sig[secSig] < TARGET then
      local e = uncover(sim); if e then return e end
      return breakThrough(sim, frontier, needSig, noThuun, curSec) or "seth"
    end
    -- 3) descend via the forward gate
    if fwdGate(here) then return moveStep(sim, "klor") end
    local g = pursue(function(n) return known(n) and fwdGate(n) end)
    if g then return g end
    local e = uncover(sim); if e then return e end
    return breakThrough(sim, frontier, needSig, noThuun, curSec) or "seth"
  else
    -- sigils lit: make for the heart (clearing its warden-ring)
    local h = pursue(function(n) return known(n) and n.type == "heart" end)
    if h then return h end
    local e = uncover(sim); if e then return e end
    return breakThrough(sim, frontier, needSig, noThuun, curSec) or "seth"
  end
end

-- public entry. Never draws essence twice in a row, so it can't just stand refilling.
function AI.step(sim)
  if sim.status ~= "play" then AI.last = nil; return nil end
  local c = AI.decide(sim, false)
  if c == "thuun" and AI.last == "thuun" then c = AI.decide(sim, true) end
  AI.last = c
  return c
end

return AI
