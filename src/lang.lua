-- lang.lua :: the Gelenath tongue, the rite-verbs, and what the codex teaches.

local L = {}

L.title    = "si'larbentethegn"
L.subtitle = "the bul'narth rite"

-- main-menu button rune labels
L.menu = {
  begin_   = { rune = "ugnaken" },  -- begin
  continue = { rune = "krennax" },  -- resume
  tutorial = { rune = "kennan" },   -- learn / tutorial
  watch    = { rune = "vorae" },    -- the rite plays itself
  settings = { rune = "sethna" },   -- settings
  codex    = { rune = "rosetta" },  -- codex
  quit     = { rune = "vaen" },     -- depart
}

-- top-bar tabs in play (clickable, rune-only).
-- stats (vyrna) on the left, then the map (karth). settings live on the main menu only.
L.tabs = {
  { id = "stats", rune = "vyrna" },
  { id = "map",   rune = "karth" },
  { id = "codex", rune = "rosetta" },
  { id = "menu",  rune = "vaen", plain = "exit" }, -- plain english, on purpose
}

-- settings rows: id, rune label, option rune-words, + english glosses (hover).
-- (autoplay is NOT here — it's the "vorae" mode on the main menu.)
L.settings = {
  { id = "script", rune = "skript", opts = { "gelnath", "sga", "english" },
    tr = "script — how text is drawn",
    optTr = { "gelenath runes", "standard galactic alphabet", "english (readable, not the full rite)" } },
  { id = "ui", rune = "skin", opts = { "vyl", "kvol" },
    tr = "skin — visual theme", optTr = { "boring (plain)", "cool (colourful)" } },
}

-- stat tokens (rendered as runes in the stats panel). value/bar from sim.
-- keep them short; the player learns to read them.
L.stats = {
  { key = "vyr",   tok = "vyr",  col = { 0.55, 0.72, 1.00 } }, -- resonance
  { key = "thuum", tok = "thum", col = { 0.58, 0.92, 0.70 } }, -- essence
  { key = "gloam", tok = "glom", col = { 0.96, 0.42, 0.32 } }, -- corruption / ammo
  { key = "seth",  tok = "seth", col = { 0.94, 0.86, 0.50 } }, -- grip / lucidity
  { key = "wake",  tok = "ugna", col = { 0.80, 0.52, 1.00 } }, -- awakening (goal)
  { key = "za",    tok = "morr", col = { 0.70, 0.80, 0.95 } }, -- sigil 1
  { key = "qor",   tok = "qhel", col = { 0.70, 0.80, 0.95 } }, -- sigil 2
  { key = "neth",  tok = "zyth", col = { 0.70, 0.80, 0.95 } }, -- sigil 3
  { key = "vael",  tok = "vael", col = { 0.50, 0.95, 0.90 } }, -- attune = min(sig)
  { key = "tik",   tok = "tik",  col = { 0.62, 0.62, 0.74 } }, -- turns elapsed
  { key = "gnos",  tok = "gnos", col = { 0.62, 0.62, 0.74 } }, -- places known
  { key = "depf",  tok = "depf", col = { 0.62, 0.62, 0.74 } }, -- depth from threshold
}

-- the rite-verbs (what the player types). ELDRITCH ONLY — no english fallbacks.
-- the codex is the single key that maps these to plain meaning.
-- map of accepted typed word -> canonical command id.
L.verbs = {
  krenn   = "move",     -- tread (krenn <dir>)
  seth    = "sense",    -- sense the place / read a gate open
  vorth   = "channel",  -- feed a sigil
  thuun   = "essence",  -- draw essence
  lu      = "rest",     -- restore grip
  svael   = "purge",    -- burn off gloam
  uthenn  = "utter",    -- speak the Word
  vael    = "attune",   -- lift weakest sigil
  kresh   = "strike",   -- hurl gloam at an ADJACENT foe's aspect
  rosetta = "codex",    -- open the codex
}

-- directions are eldritch. bare direction also moves.
L.dirs = { "vor", "neth", "qor", "zah", "klor" } -- up, down, right, left, through-gate
L.dirset = { vor = true, neth = true, qor = true, zah = true, klor = true }

-- aspects an enemy can bare (and you must name with `kresh <aspect>`)

-- codex entries: verb (latin) -> short english meaning (the only place the
-- grammar is spelled out plainly). the world's NOUNS stay runic.
L.codexVerbs = {
  { "krenn _", "tread: krenn vor / neth / qor / zah / klor  (or just type a direction)" },
  { "seth",    "sense this place — and read a sealed gate open" },
  { "vorth",   "perform the rite at a sigil-shrine (feeds a sigil; costs essence)" },
  { "thuun",   "draw essence — fills THUM, but stirs GLOM (your corruption / ammo)" },
  { "lu",      "rest — restore SETH (grip); GLOM ebbs; time passes" },
  { "svael",   "purge — burn GLOM away, at the cost of SETH and VYR" },
  { "vael",    "attune — spend VYR to lift your weakest sigil" },
  { "uthenn",  "utter the Word — only at the heart, only when sigils are lit" },
  { "kresh _", "strike a foe on an adjacent tile: kresh + the WAY toward it (vor/neth/qor/zah). hurls your GLOM" },
}

L.codexDirs = {
  { "vor",  "the ascending way" },
  { "neth", "the descending way" },
  { "qor",  "the right-handed way" },
  { "zah",  "the left-handed way" },
  { "klor", "through an opened gate, into the next section" },
}

-- eldritch system messages (rendered fully in runes via {braces}).
-- meanings are intentionally opaque; decode them with the codex.
L.msg = {
  unknown   = "{seh qorun na thenn}",          -- the word is not known
  nopath    = "{vaen thuun na}",               -- no way breathes there
  noshrine  = "{za sigil na vael here}",       -- no sigil sleeps here
  noessence = "{thum vael nul}",               -- essence runs dry
  notheart  = "{si lar na vael here}",         -- this is not the heart
  guardbar  = "{korreth ward thenn}",          -- a ward bars the way
  discord   = "{uthenn vaen diskord}",         -- the word breaks wrongly
  attuned   = "{vael lit thenn}",
  channeled = "{sigil thenn fed}",
  purged    = "{glom svael vaen}",
  drawn     = "{thum well rise}",
  rested    = "{seth lu thenn}",
  hit       = "{kresh thenn vaen}",            -- the strike lands
  miss      = "{kresh vaen na} {glom thenn}",  -- the strike falls; corruption grows
  slain     = "{korreth unmade thenn}",        -- the foe is unmade
  fled      = "{vaen krennax}",                -- you slip away
  nofoe     = "{korreth na vael here}",        -- nothing to strike
  novyr     = "{vyr nul}",
  gatesealed = "{gate sealed} {seth thenn it}", -- the way is a sealed gate; sense it
  gateopen  = "{gate thenn open vael}",        -- the gate reads, and opens
  gatestood = "{gate vael open krennax}",      -- the gate already stands open
  foeblock  = "{korreth holds way} {kresh it}", -- a foe holds that tile; strike it
  nodir     = "{kresh which way}",              -- name a direction to strike
}

return L
