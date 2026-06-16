-- autoplay.lua :: "the rite plays itself" — the VISIBLE, paced driver.
-- This is NOT the win-solver (that's ai.lua, which runs instantly). This wraps
-- ai.lua in human-like theatre: a fake cursor travels to tabs and clicks them,
-- dwells on the stats/map screens, then types the command out before submitting.
--
-- It talks to the rest of the game through injected deps (A.bind), so the whole
-- state machine can be unit-tested headlessly with stubbed UI/IO.

local AI = require("src.ai")
local L  = require("src.lang")

local A = {
  enabled = false, tainted = false, speed = 1,  -- speed multiplier: 1x / 5x / 10x
  cur = { x = 0, y = 0 }, pulse = 0,
  queue = {}, typed = "", timer = 0, actionsSince = 0,
}

-- cycle the autoplay speed 1x -> 5x -> 10x -> 1x
function A.cycleSpeed()
  A.speed = (A.speed == 1 and 5) or (A.speed == 5 and 10) or 1
  return A.speed
end

-- deps: hasRegion(id)->bool, regionCenter(id)->x,y|nil, click(id), setCmd(s), submit(raw)
local D = {}
function A.bind(deps) D = deps end

local function canon(cmd)
  local head = cmd:lower():match("%S+")
  if not head then return nil end
  if L.dirset[head] then return "move" end
  return L.verbs[head]
end

function A.start(w, h)
  A.enabled = true
  A.tainted = true                  -- once the AI drives, this run can't count
  A.queue = {}; A.typed = ""; A.timer = 0; A.actionsSince = 0; A.pulse = 0
  A.cur = { x = w / 2, y = h / 2 }
end

function A.stop()
  A.enabled = false
  A.queue = {}; A.typed = ""
end

-- build the action queue for the next AI command
function A.plan(sim)
  local cmd = AI.step(sim)
  if not cmd then A.queue = { { t = "wait", dur = 0.3 } }; return end
  if not D.hasRegion("input") then A.queue = { { t = "wait", dur = 0.05 } }; return end

  A.actionsSince = A.actionsSince + 1
  local verb = canon(cmd)
  local inCombat = sim.foe() ~= nil   -- an adjacent foe to deal with
  local q = {}

  -- glance at the vyrna stats now and then, like a person checking their state.
  -- (the map is the always-on main view, so we NEVER click the karth tab to "see" it
  -- — that was the redundant same-tab clicking; we only click karth to leave an overlay.)
  local curOverlay = D.getOverlay and D.getOverlay()
  local wantStats = (not inCombat) and (verb == "channel" or verb == "utter" or A.actionsSince % 9 == 0)
  if wantStats then
    if curOverlay ~= "stats" and D.hasRegion("tab:stats") then
      local cx, cy = D.regionCenter("tab:stats")
      q[#q + 1] = { t = "move", x = cx, y = cy }
      q[#q + 1] = { t = "click", id = "tab:stats" }
      q[#q + 1] = { t = "wait", dur = 1.0 }
    end
    if D.hasRegion("tab:map") then          -- pop back to the map (different tab, not a re-click)
      local mx, my = D.regionCenter("tab:map")
      q[#q + 1] = { t = "move", x = mx, y = my }
      q[#q + 1] = { t = "click", id = "tab:map" }
      q[#q + 1] = { t = "wait", dur = 0.25 }
    end
  elseif curOverlay and curOverlay ~= "map" and D.hasRegion("tab:map") then
    local mx, my = D.regionCenter("tab:map")  -- a lingering overlay — return to the map view
    q[#q + 1] = { t = "move", x = mx, y = my }
    q[#q + 1] = { t = "click", id = "tab:map" }
    q[#q + 1] = { t = "wait", dur = 0.2 }
  end

  -- just type — no need to click the input bar first
  q[#q + 1] = { t = "type", text = cmd }
  q[#q + 1] = { t = "wait", dur = 0.18 }
  q[#q + 1] = { t = "submit" }
  q[#q + 1] = { t = "wait", dur = 0.32 }
  A.queue = q
end

function A.update(dt, sim)
  if not A.enabled or sim.status ~= "play" then return end
  A.pulse = math.max(0, A.pulse - dt * 4)
  if #A.queue == 0 then A.plan(sim) end
  local act = A.queue[1]
  if not act then return end

  if act.t == "move" then
    local dx, dy = act.x - A.cur.x, act.y - A.cur.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local step = 950 * dt
    if dist <= step or dist < 2 then
      A.cur.x, A.cur.y = act.x, act.y
      table.remove(A.queue, 1)
    else
      A.cur.x = A.cur.x + dx / dist * step
      A.cur.y = A.cur.y + dy / dist * step
    end
  elseif act.t == "wait" then
    A.timer = A.timer + dt
    if A.timer >= act.dur then A.timer = 0; table.remove(A.queue, 1) end
  elseif act.t == "click" then
    A.timer = A.timer + dt
    if A.timer >= 0.14 then
      A.timer = 0; A.pulse = 1
      D.click(act.id)
      table.remove(A.queue, 1)
    end
  elseif act.t == "type" then
    A.timer = A.timer + dt
    if A.timer >= 0.07 then
      A.timer = 0
      if #A.typed < #act.text then
        A.typed = act.text:sub(1, #A.typed + 1)
        D.setCmd(A.typed)
      else
        table.remove(A.queue, 1)
      end
    end
  elseif act.t == "submit" then
    A.timer = A.timer + dt
    if A.timer >= 0.22 then
      A.timer = 0
      local cmd = A.typed
      A.typed = ""; D.setCmd("")
      D.submit(cmd)
      table.remove(A.queue, 1)
    end
  end
end

return A
