-- achievements.lua :: the canonical list, mirrored in achievements.json (repo root,
-- which the portal reads). Keys are immutable once released. The in-game achievements
-- page renders titles/descriptions from here; hidden ones stay "???" until unlocked.

return {
  { key = "decipher",         title = "Rosetta",               points = 5,   rarity = "common",
    desc = "Open the codex — the only key to the tongue." },
  { key = "first_unmaking",   title = "First Unmaking",        points = 10,  rarity = "common",
    desc = "Unmake your first foe." },
  { key = "first_sigil",      title = "A Pin Loosened",        points = 20,  rarity = "uncommon",
    desc = "Light your first sigil at a shrine." },
  { key = "corruption_brink", title = "On the Brink",          points = 20,  rarity = "uncommon",
    desc = "Let your corruption (glom) climb to 90." },
  { key = "into_the_deep",    title = "Into the Deep",         points = 30,  rarity = "rare",
    desc = "Descend to the deepest section." },
  { key = "heart_found",      title = "The Heart of si'lar",   points = 25,  rarity = "uncommon",
    desc = "Stand upon the heart of the sleeper." },
  { key = "three_sigils",     title = "All Three Lit",         points = 35,  rarity = "rare",
    desc = "Hold all three sigils lit at once." },
  { key = "warden_folded",    title = "The Warden Folded",     points = 50,  rarity = "rare",
    desc = "Unmake the warden that guards the heart." },
  { key = "ascended",         title = "ugnaken",               points = 100, rarity = "legendary",
    desc = "Wake si'larbentethegn. End the dream." },
  -- secrets (hidden until earned)
  { key = "whisper_heard",    title = "A Thought Not Yet Thought", points = 15, rarity = "uncommon", hidden = true,
    desc = "Hear a whisper of the deeper truth." },
  { key = "word_breaks",      title = "The Word Breaks",       points = 15,  rarity = "uncommon", hidden = true,
    desc = "Utter the Word with the sigils spent." },
}
