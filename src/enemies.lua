-- enemies.lua :: the things that ward the dark.
-- Combat is fought in place, in the console. You damage a foe by hurling your
-- own GLOAM (corruption) at it with `kresh <aspect>` — but ONLY if you correctly
-- read and name the rune-aspect it is currently baring. Read the script, or feed
-- it your corruption for nothing.

local E = {}

-- glamour is kept LOW on purpose: foes surround structures in numbers, so each
-- one should die fast (a loaded kresh or two), not be a slog.
E.templates = {
  -- shrine wardens (ring the shrines)
  vaelorn = { name = "vael'orn",  glamour = 45, miasma = 4, bite = 2, reward = { vyr = 10, note = "{vael orn unmade}" } },
  qethrave = { name = "qethrave", glamour = 50, miasma = 4, bite = 2, reward = { vyr = 10, note = "{qethrave unmade}" } },
  nethulu  = { name = "nethulu",  glamour = 55, miasma = 5, bite = 2, reward = { vyr = 12, note = "{nethulu unmade}" } },
  -- the heart's warden (the boss). a little tougher.
  larth    = { name = "the larth", glamour = 150, miasma = 6, bite = 3, boss = true,
              reward = { note = "{the larth folds} {si lar bare}" } },
  -- roamers (stand on random deep tiles)
  ghael    = { name = "ghael",    glamour = 40, miasma = 4, bite = 2, reward = { thuum = 12, note = "{ghael scatters}" } },
  vorm     = { name = "vorm",     glamour = 48, miasma = 5, bite = 2, reward = { thuum = 14, note = "{vorm bursts}" } },
  -- gate wardens (ring the gates; scale gently with depth)
  vorthak  = { name = "vor'thak", glamour = 50, miasma = 4, bite = 2, reward = { vyr = 8, note = "{vor thak unmade}" } },
  qhulra   = { name = "qhul'ra",  glamour = 58, miasma = 5, bite = 2, reward = { vyr = 9, note = "{qhul ra unmade}" } },
  ssgrael  = { name = "ss'grael", glamour = 66, miasma = 5, bite = 3, reward = { vyr = 10, note = "{ss grael unmade}" } },
  drennan  = { name = "dren'nan", glamour = 74, miasma = 6, bite = 3, reward = { vyr = 11, note = "{dren nan unmade}" } },
}

function E.new(id)
  local t = E.templates[id]
  if not t then return nil end
  return {
    id        = id,
    name      = t.name,
    glamour   = t.glamour,
    glamourMax = t.glamour,
    miasma    = t.miasma,
    bite      = t.bite,
    boss      = t.boss or false,
    reward    = t.reward,
    alive     = true,
  }
end

return E
