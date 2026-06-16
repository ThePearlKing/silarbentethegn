-- glyph.lua
-- The Gelenath script. Every latin letter / digit is drawn as a procedural rune.
-- Glyphs are deterministic (seeded by byte), so the SAME character always yields
-- the SAME rune. Learn the 26 + 10 runes (see the ROSETTA / codex) and you can
-- read every label, number and noun in the game.

local Glyph = {}

-- a 3x3 node grid in normalized [0,1] box space, plus 4 mid-edge nodes (10..13)
local GP = {
  {0.18, 0.14}, {0.50, 0.08}, {0.82, 0.14}, -- 1 2 3  top row
  {0.10, 0.50}, {0.50, 0.50}, {0.90, 0.50}, -- 4 5 6  mid row
  {0.18, 0.86}, {0.50, 0.92}, {0.82, 0.86}, -- 7 8 9  bottom row
  {0.50, 0.28}, {0.72, 0.50}, {0.50, 0.72}, {0.28, 0.50}, -- 10..13 inner cross
}

-- tiny deterministic LCG keyed by an integer
local function lcg(seed)
  local s = seed % 2147483647
  if s <= 0 then s = s + 2147483646 end
  return function()
    s = (s * 48271) % 2147483647
    return s / 2147483647
  end
end

local cache = {}

local function strokesFor(byte)
  local g = cache[byte]
  if g then return g end
  local r = lcg((byte * 2654435761 + 101) % 2147483647)
  local n = 3 + math.floor(r() * 2) -- 3..4 strokes -> rich, rune-like
  local strokes = {}
  local prev = 1 + math.floor(r() * #GP)
  for _ = 1, n do
    local nxt = 1 + math.floor(r() * #GP)
    if nxt == prev then nxt = (nxt % #GP) + 1 end
    strokes[#strokes + 1] = { prev, nxt }
    if r() < 0.55 then prev = nxt else prev = 1 + math.floor(r() * #GP) end
  end
  local dot = nil
  if r() < 0.45 then dot = 1 + math.floor(r() * 9) end
  g = { strokes = strokes, dot = dot }
  cache[byte] = g
  return g
end

-- advance width per character at a given glyph size
function Glyph.advance(byte, size)
  if byte == 32 then return size * 0.42 end        -- space
  if byte == 39 then return size * 0.34 end        -- apostrophe '
  if byte == 45 then return size * 0.46 end        -- hyphen -
  if byte == 46 or byte == 44 then return size * 0.30 end -- . ,
  return size * 0.82
end

function Glyph.width(str, size)
  local w = 0
  for i = 1, #str do w = w + Glyph.advance(str:byte(i), size) end
  return w
end

-- ============================================================================
-- SCRIPT MODES (chosen in settings)
--   "gelenath" (default) : the procedural runes above. nobody reads these.
--   "galactic"           : the REAL Standard Galactic Alphabet (Minecraft forms),
--                          hand-drawn here as smooth strokes (no font file) — for
--                          those who actually read SGA.
--   "english"            : a readable line-drawn latin alphabet (cool, but plain
--                          to read). an accessibility option — not the full rite.
--   digits in galactic/english render as 7-segment numerals (readable numbers).
-- ============================================================================
Glyph.script = "gelenath"
function Glyph.setScript(s)
  if s == "galactic" or s == "english" then Glyph.script = s else Glyph.script = "gelenath" end
end

-- the "english" script: the original cool stylised line-font (it is NOT real SGA
-- and not strict latin — it just looks rad). restored exactly as it was.
local ENGLISH = {
  a = {{0.22,0.80, 0.22,0.30, 0.78,0.30}, {0.50,0.30, 0.50,0.62}},
  b = {{0.25,0.20, 0.25,0.80, 0.72,0.80}, {0.25,0.50, 0.60,0.50}},
  c = {{0.75,0.25, 0.30,0.25, 0.30,0.75, 0.75,0.75}},
  d = {{0.30,0.18, 0.30,0.82}, {0.30,0.18, 0.58,0.24, 0.74,0.50, 0.58,0.76, 0.30,0.82}}, -- bowl, not a K
  e = {{0.74,0.22, 0.30,0.22, 0.30,0.78, 0.74,0.78}, {0.30,0.50, 0.58,0.50}},
  f = {{0.30,0.80, 0.30,0.22, 0.74,0.22}, {0.30,0.50, 0.62,0.50}},
  g = {{0.74,0.30, 0.30,0.30, 0.30,0.72, 0.74,0.72, 0.74,0.50, 0.52,0.50}},
  h = {{0.28,0.20, 0.28,0.80}, {0.72,0.20, 0.72,0.80}, {0.28,0.50, 0.72,0.50}},
  i = {{0.50,0.22, 0.50,0.78}, {0.34,0.22, 0.66,0.22}, {0.34,0.78, 0.66,0.78}},
  j = {{0.66,0.22, 0.66,0.78, 0.30,0.78, 0.30,0.58}},
  k = {{0.28,0.20, 0.28,0.80}, {0.72,0.22, 0.28,0.50, 0.72,0.78}},
  l = {{0.30,0.20, 0.30,0.80, 0.74,0.80}},
  m = {{0.24,0.80, 0.24,0.22, 0.50,0.55, 0.76,0.22, 0.76,0.80}},
  n = {{0.26,0.80, 0.26,0.22, 0.74,0.78, 0.74,0.22}},
  o = {{0.30,0.25, 0.70,0.25, 0.70,0.75, 0.30,0.75, 0.30,0.25}},
  p = {{0.28,0.80, 0.28,0.22, 0.72,0.22, 0.72,0.50, 0.28,0.50}},
  q = {{0.30,0.25, 0.70,0.25, 0.70,0.75, 0.30,0.75, 0.30,0.25}, {0.58,0.62, 0.80,0.84}},
  r = {{0.28,0.80, 0.28,0.22, 0.72,0.22, 0.72,0.50, 0.28,0.50}, {0.45,0.50, 0.72,0.80}},
  s = {{0.74,0.25, 0.30,0.25, 0.30,0.50, 0.70,0.50, 0.70,0.75, 0.26,0.75}},
  t = {{0.50,0.22, 0.50,0.80}, {0.30,0.22, 0.70,0.22}},
  u = {{0.28,0.22, 0.28,0.78, 0.72,0.78, 0.72,0.22}},
  v = {{0.26,0.22, 0.50,0.80, 0.74,0.22}},
  w = {{0.22,0.22, 0.34,0.80, 0.50,0.45, 0.66,0.80, 0.78,0.22}},
  x = {{0.28,0.22, 0.72,0.78}, {0.72,0.22, 0.28,0.78}},
  y = {{0.28,0.22, 0.50,0.50, 0.72,0.22}, {0.50,0.50, 0.50,0.80}},
  z = {{0.28,0.22, 0.72,0.22, 0.28,0.78, 0.72,0.78}},
}
-- 7-segment numerals
local S = {
  A = {0.26,0.14, 0.74,0.14}, G = {0.26,0.50, 0.74,0.50}, D = {0.26,0.86, 0.74,0.86},
  F = {0.24,0.16, 0.24,0.48}, B = {0.76,0.16, 0.76,0.48},
  E = {0.24,0.52, 0.24,0.84}, C = {0.76,0.52, 0.76,0.84},
}
local SEG7 = {
  ["0"]={"A","B","C","D","E","F"}, ["1"]={"B","C"}, ["2"]={"A","B","G","E","D"},
  ["3"]={"A","B","G","C","D"}, ["4"]={"F","G","B","C"}, ["5"]={"A","F","G","C","D"},
  ["6"]={"A","F","G","E","C","D"}, ["7"]={"A","B","C"}, ["8"]={"A","B","C","D","E","F","G"},
  ["9"]={"A","B","C","D","F","G"},
}

-- the "galactic" script: the REAL Standard Galactic Alphabet (the Minecraft /
-- Commander Keen letterforms), hand-traced from the canonical pixel glyphs and
-- redrawn as SMOOTH strokes — pixel staircases become curves and corners round off.
-- Coords are in CELL units: col (0..w-1) left→right, row (0..) top→bottom; `yoff`
-- drops the short letters to their place on the line. `s` = stroke polylines (flat
-- {col,row,...}), `d` = dots. Anyone who reads SGA can read these.
local SGA = {
  a = { w = 5, yoff = 0, s = { { 0,6, 1,6, 1,1, 2,0, 3,0, 4,1 } } },
  b = { w = 5, yoff = 0, s = { { 2,0, 2,3, 3,4, 4,5, 4,6, 0,6 } } },
  c = { w = 2, yoff = 0, s = { { 0,2, 0,4, 1,4, 1,6 } }, d = { { 0,0 } } },
  d = { w = 5, yoff = 0, s = { { 0,0, 4,0 }, { 0,2, 1,2, 2,3, 3,4, 4,4 } } },
  e = { w = 5, yoff = 0, s = { { 0,0, 0,6, 4,6 } }, d = { { 4,0 } } },
  f = { w = 5, yoff = 0, s = { { 0,0, 4,0 } }, d = { { 0,2 }, { 2,2 }, { 4,2 } } },
  g = { w = 3, yoff = 0, s = { { 2,0, 2,6 }, { 0,3, 2,3 } } },
  h = { w = 5, yoff = 0, s = { { 0,0, 4,0 }, { 0,2, 4,2 }, { 2,2, 2,6 } } },
  i = { w = 1, yoff = 0, s = { { 0,0, 0,2 }, { 0,4, 0,6 } } },
  j = { w = 1, yoff = 0, s = { { 0,0, 0,1 }, { 0,5, 0,6 } }, d = { { 0,3 } } },
  k = { w = 5, yoff = 0, s = { { 2,0, 2,6 } }, d = { { 0,3 }, { 4,3 } } },
  l = { w = 3, yoff = 0, s = { { 0,0, 0,6 } }, d = { { 2,1 }, { 2,5 } } },
  m = { w = 5, yoff = 0, s = { { 4,0, 4,6, 0,6 } }, d = { { 0,0 } } },
  n = { w = 4, yoff = 0, s = { { 0,0, 0,1 }, { 3,0, 3,2, 2.4,4.3, 0,6 } } },
  o = { w = 4, yoff = 0, s = { { 0,0, 3,0, 3,2, 2.4,4.3, 0,6 } } },
  p = { w = 3, yoff = 0, s = { { 0,2, 0,6 }, { 2,0, 2,4 } }, d = { { 0,0 }, { 2,6 } } },
  q = { w = 5, yoff = 0, s = { { 0,2, 4,2, 4,6, 0,6 } }, d = { { 2,0 } } },
  r = { w = 4, yoff = 0, d = { { 0,0 }, { 3,0 }, { 0,6 }, { 3,6 } } },
  s = { w = 2, yoff = 0, s = { { 0,0, 0,3, 1,3, 1,6 } } },
  t = { w = 5, yoff = 0, s = { { 0,0, 4,0, 4,4 } }, d = { { 4,6 } } },
  u = { w = 5, yoff = 2, s = { { 0,2, 4,2 } }, d = { { 1,0 }, { 3,0 } } },
  v = { w = 5, yoff = 0, s = { { 2,0, 2,4 }, { 0,4, 4,4 }, { 0,6, 4,6 } } },
  w = { w = 5, yoff = 2, d = { { 2,0 }, { 0,3 }, { 4,3 } } },
  x = { w = 5, yoff = 0, s = { { 4,0, 3,2, 2,3, 1,4, 0,6 } }, d = { { 0,0 } } },
  y = { w = 3, yoff = 0, s = { { 0,0, 0,6 }, { 2,0, 2,6 } } },
  z = { w = 5, yoff = 0, s = { { 0,6, 0,2, 1,1, 2,0, 3,1, 4,2, 4,6 } } },
}

-- Catmull-Rom: turn a coarse {x,y,...} polyline into a smooth one (rounds corners,
-- bends pixel staircases into curves). 2-point lines pass through unchanged.
local function smoothCurve(pts)
  local n = #pts / 2
  if n < 3 then return pts end
  local function P(i) i = math.max(1, math.min(n, i)); return pts[2 * i - 1], pts[2 * i] end
  local out, STEPS = {}, 7
  for i = 1, n - 1 do
    local x0, y0 = P(i - 1); local x1, y1 = P(i); local x2, y2 = P(i + 1); local x3, y3 = P(i + 2)
    for s = 0, STEPS - 1 do
      local t = s / STEPS; local t2 = t * t; local t3 = t2 * t
      out[#out + 1] = 0.5 * ((2 * x1) + (-x0 + x2) * t + (2 * x0 - 5 * x1 + 4 * x2 - x3) * t2 + (-x0 + 3 * x1 - 3 * x2 + x3) * t3)
      out[#out + 1] = 0.5 * ((2 * y1) + (-y0 + y2) * t + (2 * y0 - 5 * y1 + 4 * y2 - y3) * t2 + (-y0 + 3 * y1 - 3 * y2 + y3) * t3)
    end
  end
  local lx, ly = P(n); out[#out + 1] = lx; out[#out + 1] = ly
  return out
end

local function polyline(pl, x, y, size)
  local pts = {}
  for i = 1, #pl, 2 do pts[#pts + 1] = x + pl[i] * size; pts[#pts + 1] = y + pl[i + 1] * size end
  if #pts >= 4 then love.graphics.line(pts) end
end
local function drawSeg7(byte, x, y, size)
  for _, seg in ipairs(SEG7[string.char(byte)]) do polyline(S[seg], x, y, size) end
end

-- draw a single glyph in a box [x,y] of side `size`
function Glyph.drawChar(byte, x, y, size, lw)
  lw = lw or math.max(1, size * 0.10)
  love.graphics.setLineWidth(lw)
  love.graphics.setLineJoin("bevel")
  local sc = Glyph.script

  if sc == "english" then
    if byte >= 48 and byte <= 57 then drawSeg7(byte, x, y, size); return end
    local g = ENGLISH[string.char(byte):lower()]
    if g then for _, pl in ipairs(g) do polyline(pl, x, y, size) end; return end
    -- else fall through to procedural marks
  elseif sc == "galactic" then
    if byte >= 48 and byte <= 57 then drawSeg7(byte, x, y, size); return end
    local g = SGA[string.char(byte):lower()]
    if g then
      local cell = 0.125
      local startx = 0.5 - (g.w - 1) * cell / 2
      local function nx(c) return x + (startx + c * cell) * size end
      local function ny(r) return y + (0.12 + (g.yoff + r) * cell) * size end
      love.graphics.setLineStyle("smooth")
      local cap = lw * 0.5
      for _, pl in ipairs(g.s or {}) do
        local pts = {}
        for i = 1, #pl, 2 do pts[#pts + 1] = nx(pl[i]); pts[#pts + 1] = ny(pl[i + 1]) end
        if #pts >= 4 then
          love.graphics.line(smoothCurve(pts))
          love.graphics.circle("fill", pts[1], pts[2], cap)                 -- round caps
          love.graphics.circle("fill", pts[#pts - 1], pts[#pts], cap)
        elseif #pts == 2 then
          love.graphics.circle("fill", pts[1], pts[2], lw * 0.6)
        end
      end
      for _, dd in ipairs(g.d or {}) do love.graphics.circle("fill", nx(dd[1]), ny(dd[2]), lw * 0.7) end
      return
    end
    -- unknown char -> fall through to procedural
  end

  -- gelenath (default): procedural runes
  local g = strokesFor(byte)
  for _, s in ipairs(g.strokes) do
    local a, b = GP[s[1]], GP[s[2]]
    love.graphics.line(x + a[1] * size, y + a[2] * size, x + b[1] * size, y + b[2] * size)
  end
  if g.dot then
    local d = GP[g.dot]
    love.graphics.circle("fill", x + d[1] * size, y + d[2] * size, lw * 1.25)
  end
end

-- draw a whole romanized string as Gelenath. letters/digits become runes;
-- spaces, apostrophes, hyphens get small marks. returns the x cursor end.
function Glyph.drawText(str, x, y, size, lw)
  local cx = x
  lw = lw or math.max(1, size * 0.10)
  for i = 1, #str do
    local b = str:byte(i)
    if b == 32 then
      -- space: nothing
    elseif b == 39 then
      love.graphics.setLineWidth(lw)
      love.graphics.line(cx + size * 0.10, y + size * 0.04, cx + size * 0.16, y + size * 0.24)
    elseif b == 45 then
      love.graphics.setLineWidth(lw)
      love.graphics.line(cx + size * 0.08, y + size * 0.5, cx + size * 0.34, y + size * 0.5)
    elseif b == 46 or b == 44 then
      love.graphics.circle("fill", cx + size * 0.12, y + size * 0.82, lw * 1.1)
    else
      Glyph.drawChar(b, cx, y, size, lw)
    end
    cx = cx + Glyph.advance(b, size)
  end
  return cx
end

function Glyph.drawTextCentered(str, cx, y, size, lw)
  local w = Glyph.width(str, size)
  return Glyph.drawText(str, cx - w * 0.5, y, size, lw)
end

return Glyph
