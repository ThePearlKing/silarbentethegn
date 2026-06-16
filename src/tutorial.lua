-- tutorial.lua :: a guided first rite, taught in the order you should learn it.
-- Teaching steps (kind="info") are read and dismissed with a CONTINUE button; the
-- hands-on steps wait for you to actually do the thing. Each step also names the
-- tab you want, and the game snaps you there when the step begins (`snap`):
--   "karth" = the map, "vyrna" = the stats, "rosetta" = the codex.

local T = { active = false, step = 1 }

-- kinds:
--   info = read it, press CONTINUE
--   tab  = open the named overlay yourself (want)
--   say  = type the named verb (want = canonical verb)
--   move = tread to a new tile
--   kill = unmake a foe
T.steps = {
  { kind = "info",
    text = "You are {bul'narth}, come to wake the sleeper {si'larbentethegn}. Your tongue is not English — almost everything you read is {gelenath} runes. This guided rite will teach the whole way, step by step. Press CONTINUE." },

  { kind = "tab", want = "codex",
    text = "First, your key. Open the {rosetta} tab at the top — the codex. It translates every rune and verb. Lean on it whenever a word looks strange." },

  { kind = "info", snap = "vyrna",
    text = "This is {vyrna}, your fvalues. {thum} = essence, your fuel. {glom} = corruption — both your WEAPON and your danger. {seth} = your grip on a place. {vyr} = vigor. {ugna} = how awake the god is. The three sigils {morr} {qhel} {zyth} begin dark. Press CONTINUE." },

  { kind = "info", snap = "karth",
    text = "This is {karth}, the map — your main view. You move blind through {sectors} chained by sealed {gates}; {depf} shows how deep you are. The deep holds the shrines and the {heart}. Press CONTINUE." },

  { kind = "say", want = "sense", snap = "karth",
    text = "Type  seth  to SENSE your tile. Its real use: when you stand ON a sealed {gate},  seth  UNLOCKS it — then  klor  carries you through to the next sector. That is how you open every gate you find." },

  { kind = "move", snap = "karth",
    text = "Now tread. You begin in a CORNER, so only  neth  (south) and  qor  (east) lead onward —  vor  and  zah  press against the wall and go nowhere. Type  neth  or  qor ." },

  { kind = "info", snap = "karth",
    text = "You moved — see it on {karth}: your place shifted, and the dark around the new tile peels back as you go. Press CONTINUE." },

  { kind = "say", want = "essence", snap = "vyrna",
    text = "Watch {vyrna} as you do this. Type  thuun  to draw {essence}: {thum} rises — and so does {glom}, for corruption is the ammunition you hurl at foes." },

  { kind = "say", want = "rest", snap = "vyrna",
    text = "When {seth} runs low you falter and the warning bar lights. Type  lu  to REST and restore it (a little {glom} ebbs away too)." },

  { kind = "info", snap = "vyrna",
    text = "{glom} is your ammunition: a strike's force scales with it, so a good stock fells a foe in ONE blow. You CAN strike with almost no {glom} — it still scratches, the fight just drags on — so {glom} is a SHORTCUT, not a gate. Draw some with  thuun  to make the kill quick. Press CONTINUE." },

  { kind = "kill", snap = "karth",
    text = "Now strike. Foes ring everything that matters. Stand on a tile NEXT TO one, type  kresh  and the way toward it (e.g.  kresh qor ). The more {glom} you spend, the harder it lands — fell one foe." },

  { kind = "info", snap = "vyrna",
    text = "If {glom} climbs too high it rots you, and the warning bar will say so. Type  svael  to PURGE it back down. Keep corruption as a tool, never a master. Press CONTINUE." },

  { kind = "info", snap = "karth",
    text = "THE RITE, part one: descend through {gates} —  seth  to open one,  klor  to cross. On depths 1, 3 and 5 a {shrine} waits (green ring). Stand on it and type  vorth  to light its sigil. Press CONTINUE." },

  { kind = "info", snap = "karth",
    text = "THE RITE, part two: with all three sigils lit, reach the gold {heart} on depth 5, fell the {warden}, and type  uthenn  to pour the sigils into the god. They drain to nothing — so BACKTRACK, re-light them, and  uthenn  again until {ugna} is full. Then you have won. Press CONTINUE." },
}

T.final = { kind = "sys", text = "{kennan vaen} {si lar krennax}" }

function T.start() T.active = true; T.step = 1 end
function T.text() if not T.active then return nil end local s = T.steps[T.step]; return s and s.text end
function T.current() if not T.active then return nil end return T.steps[T.step] end
function T.snapTab() local s = T.current(); return s and s.snap end
function T.needsContinue() local s = T.current(); return s ~= nil and s.kind == "info" end
function T.progress() return T.step, #T.steps end

local function advance()
  T.step = T.step + 1
  if T.step > #T.steps then T.active = false; return T.final end
  return nil
end

-- called after each command / overlay change, for the hands-on (non-info) steps.
-- loops so an already-satisfied step (e.g. "charge gloam" when you're already
-- stocked) is skipped before it's ever shown.
function T.check(ctx)
  if not T.active then return nil end
  while true do
    local s = T.steps[T.step]; if not s then T.active = false; return nil end
    local done = false
    if s.kind == "tab" then done = (ctx.overlay == s.want)
    elseif s.kind == "say" then done = (ctx.lastVerb == s.want)
    elseif s.kind == "move" then done = (ctx.nodeChanged == true)
    elseif s.kind == "kill" then done = ((ctx.kills or 0) >= 1)
    elseif s.kind == "charge" then done = ((ctx.gloam or 0) >= s.want)
    end                                 -- info steps wait for CONTINUE, never auto
    if not done then return nil end
    local final = advance()
    if final or not T.active then return final end
  end
end

-- called when CONTINUE is clicked (advances the read-only teaching steps)
function T.continue()
  if not T.active then return nil end
  local s = T.steps[T.step]
  if s and s.kind == "info" then return advance() end
  return nil
end

return T
