-- ui.lua :: rendering. Two skins:
--   BORING  (default) — flat, grey, square, no flourish. deepens the obscurity.
--   COOL    (toggle, F1) — "normal" game UI: gradient, colour, rounded, glow.
-- ALL Gelenath text is drawn in a single fixed colour (never english, never a
-- decode mode), distinct from english prose and from your own typed input.

local Glyph  = require("src.glyph")
local R      = require("src.richtext")
local L      = require("src.lang")
local W      = require("src.world")
local ACHV   = require("src.achievements")
local Portal = require("src.portal")

local UI = { cool = true }  -- colourful by default (overridden by saved cfg)

-- ---------------------------------------------------------------- themes -----
local BORING = {
  bg       = { 0.055, 0.055, 0.065 },
  bg2      = { 0.055, 0.055, 0.065 },
  panel    = { 0.075, 0.075, 0.085 },
  border   = { 0.20, 0.20, 0.22 },
  english  = { 0.60, 0.60, 0.60 },
  gel      = { 0.46, 0.62, 0.60 },   -- the eldritch colour (muted)
  input    = { 0.78, 0.74, 0.55 },
  foe      = { 0.66, 0.50, 0.50 },
  accent   = { 0.42, 0.42, 0.46 },
  barbg    = { 0.15, 0.15, 0.16 },
  barfill  = { 0.46, 0.46, 0.50 },
  round    = 0,
  glow     = false,
  coloredBars = false,
}
local COOL = {
  bg       = { 0.05, 0.06, 0.10 },
  bg2      = { 0.10, 0.07, 0.15 },
  panel    = { 0.10, 0.11, 0.17 },
  border   = { 0.34, 0.46, 0.70 },
  english  = { 0.86, 0.87, 0.92 },
  gel      = { 0.42, 0.95, 0.80 },   -- bright eldritch teal
  input    = { 0.99, 0.86, 0.45 },
  foe      = { 1.00, 0.45, 0.42 },
  accent   = { 0.55, 0.78, 1.00 },
  barbg    = { 0.14, 0.16, 0.22 },
  barfill  = { 0.42, 0.95, 0.80 },
  round    = 8,
  glow     = true,
  coloredBars = true,
}

local function T() return UI.cool and COOL or BORING end

-- ----------------------------------------------------------------- fonts -----
function UI.load()
  UI.f   = love.graphics.newFont(18)
  UI.fs  = love.graphics.newFont(13)
  UI.fb  = love.graphics.newFont(34)
  love.graphics.setLineStyle(UI.cool and "smooth" or "rough")
end

-- ----------------------------------------------------------- hit regions -----
UI._hot = {}
function UI.beginFrame() UI._hot = {} love.graphics.setLineStyle(UI.cool and "smooth" or "rough") end

-- VIRTUAL / DESIGN RESOLUTION. The whole game is laid out at UI.W x UI.H and then
-- scaled UNIFORMLY to the real window (centred, with black letterbox bars). So the
-- proportions never stretch, and the UI never shrinks relative to a bigger screen.
UI.W, UI.H = 1280, 800
UI._scale, UI._ox, UI._oy = 1, 0, 0
function UI.computeScale()
  local rw, rh = love.graphics.getDimensions()
  local s = math.min(rw / UI.W, rh / UI.H)
  UI._scale = s
  UI._ox = math.floor((rw - UI.W * s) / 2)
  UI._oy = math.floor((rh - UI.H * s) / 2)
end
function UI.push()
  love.graphics.push()
  love.graphics.translate(UI._ox, UI._oy)
  love.graphics.scale(UI._scale)
  love.graphics.setScissor(UI._ox, UI._oy, UI.W * UI._scale, UI.H * UI._scale)
end
function UI.pop()
  love.graphics.setScissor()
  love.graphics.pop()
end
-- map a real screen point into virtual space (for hit-testing / hover)
function UI.toVirtual(mx, my) return (mx - UI._ox) / UI._scale, (my - UI._oy) / UI._scale end
local function vmouse() return UI.toVirtual(love.mouse.getX(), love.mouse.getY()) end
local function reg(id, x, y, w, h) UI._hot[#UI._hot + 1] = { id = id, x = x, y = y, w = w, h = h } end
function UI.hitTest(mx, my)
  for i = #UI._hot, 1, -1 do
    local r = UI._hot[i]
    if mx >= r.x and mx <= r.x + r.w and my >= r.y and my <= r.y + r.h then return r.id end
  end
  return nil
end

-- last-frame region by id (used by the autoplay cursor to find click targets)
function UI.getRegion(id)
  for i = #UI._hot, 1, -1 do
    if UI._hot[i].id == id then return UI._hot[i] end
  end
  return nil
end
function UI.regionCenter(id)
  local r = UI.getRegion(id)
  if r then return r.x + r.w / 2, r.y + r.h / 2 end
  return nil
end

-- the big, light-blue "AI hand". drawn on top of everything during autoplay.
-- pulse in [0,1] draws a click ripple.
function UI.drawCursor(x, y, pulse)
  local s = 2.2 -- big
  local pts = { 0,0, 0,16, 4,12.5, 7,19, 9.5,18, 6.5,11.5, 11,11.5 }
  local tp = {}
  for i = 1, #pts, 2 do tp[#tp + 1] = x + pts[i] * s; tp[#tp + 1] = y + pts[i + 1] * s end
  if pulse and pulse > 0 then
    love.graphics.setColor(0.6, 0.85, 1.0, 0.5 * pulse)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", x, y, (1 - pulse) * 34 + 6)
  end
  -- soft glow
  love.graphics.setColor(0.6, 0.85, 1.0, 0.25)
  love.graphics.circle("fill", x, y, 6 * s)
  -- body + outline
  love.graphics.setColor(0.05, 0.10, 0.18, 0.9)
  love.graphics.setLineWidth(2)
  love.graphics.polygon("line", tp)
  love.graphics.setColor(0.62, 0.84, 1.0, 1.0) -- light blue
  love.graphics.polygon("fill", tp)
end

-- ----------------------------------------------------------- primitives ------
local function setc(c, a) love.graphics.setColor(c[1], c[2], c[3], a or 1) end

local function panel(x, y, w, h, fill)
  local th = T()
  if th.glow then
    setc(th.accent, 0.10)
    love.graphics.rectangle("fill", x - 2, y - 2, w + 4, h + 4, th.round + 2, th.round + 2)
  end
  setc(fill or th.panel)
  love.graphics.rectangle("fill", x, y, w, h, th.round, th.round)
  setc(th.border)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, w, h, th.round, th.round)
end

-- clickable button: rune label centred. registers a hot region under `id`.
-- if `plain` is given, that English word is drawn instead of runes (used for
-- EXIT, so you never quit by clicking an unreadable glyph).
local function button(id, x, y, w, h, rune, hovered, plain)
  local th = T()
  panel(x, y, w, h, hovered and th.accent or nil)
  if plain then
    love.graphics.setFont(UI.f)
    setc(th.english)
    local tw = UI.f:getWidth(plain)
    love.graphics.print(plain, x + (w - tw) / 2, y + (h - UI.f:getHeight()) / 2)
  else
    local size = math.min(h * 0.42, 22)
    setc(th.gel)
    Glyph.drawTextCentered(rune, x + w / 2, y + (h - size) / 2, size)
  end
  reg(id, x, y, w, h)
end

-- a labelled bar (rune token + runic numeral + bar)
local function statRow(x, y, w, def, value, frac)
  local th = T()
  setc(th.gel)
  Glyph.drawText(def.tok, x, y, 16)
  -- numeral (runic), right of token
  local nx = x + 64
  setc(th.gel)
  Glyph.drawText(tostring(math.floor(value)), nx, y, 18)
  if frac then
    local bx, bw, bh = x + 130, w - 130, 12
    local by = y + 4
    setc(th.barbg)
    love.graphics.rectangle("fill", bx, by, bw, bh, th.round * 0.5, th.round * 0.5)
    local fill = th.coloredBars and def.col or th.barfill
    setc(fill)
    love.graphics.rectangle("fill", bx, by, bw * math.max(0, math.min(1, frac)), bh, th.round * 0.5, th.round * 0.5)
  end
end

-- ------------------------------------------------------------- background ----
local function drawBG()
  local th = T()
  local w, h = UI.W, UI.H
  if UI.cool then
    -- vertical gradient via two rectangles + mesh-ish bands
    for i = 0, 40 do
      local t = i / 40
      love.graphics.setColor(
        th.bg[1] + (th.bg2[1] - th.bg[1]) * t,
        th.bg[2] + (th.bg2[2] - th.bg[2]) * t,
        th.bg[3] + (th.bg2[3] - th.bg[3]) * t)
      love.graphics.rectangle("fill", 0, h * t, w, h / 40 + 1)
    end
  else
    setc(th.bg)
    love.graphics.rectangle("fill", 0, 0, w, h)
  end
end

local overlayCodex, overlaySettings, overlayInfo, overlayAchievements  -- forward declarations (used by the menu too)

-- ============================================================= MAIN MENU =====
function UI.menu(ctx)
  local th = T()
  drawBG()
  local w, h = UI.W, UI.H
  -- title (runic)
  setc(th.gel)
  Glyph.drawTextCentered(L.title, w / 2, h * 0.16, 40)
  setc(th.english)
  -- subtitle stays runic too
  setc(th.gel)
  Glyph.drawTextCentered(L.subtitle, w / 2, h * 0.16 + 70, 18)

  -- wins counter (runic numeral) bottom-left
  setc(th.gel)
  love.graphics.setFont(UI.fs)
  Glyph.drawText("wins", 24, h - 40, 14)
  Glyph.drawText(tostring(ctx.wins), 24 + 56, h - 42, 18)
  -- signed-in handle (from the portal), shown faintly
  if ctx.handle then
    setc(th.english, 0.5); love.graphics.setFont(UI.fs)
    love.graphics.print("bound :: " .. ctx.handle, 24, h - 64)
  end

  -- buttons (centred stack)
  local items = {}
  if ctx.hasSave then items[#items + 1] = { "continue", L.menu.continue.rune } end
  items[#items + 1] = { ctx.hasSave and "newgame" or "begin", L.menu.begin_.rune }
  items[#items + 1] = { "tutorial", L.menu.tutorial.rune }
  items[#items + 1] = { "watch",    L.menu.watch.rune }
  items[#items + 1] = { "settings", L.menu.settings.rune }
  items[#items + 1] = { "codex",    L.menu.codex.rune }
  items[#items + 1] = { "info", "info", "info" }   -- plain english, just above exit
  items[#items + 1] = { "quit",     L.menu.quit.rune, "exit" } -- plain english, on purpose
  local bw, bh, gap = 280, 44, 10
  local total = #items * bh + (#items - 1) * gap
  local bx = w / 2 - bw / 2
  local by = math.max(h * 0.28, h * 0.5 - total / 2)
  -- english gloss shown when you hover a rune button (because yes)
  local TR = {
    continue = "resume your rite", begin = "begin the rite", newgame = "begin anew",
    info = "what is this?", tutorial = "learn — a guided rite", watch = "watch the rite play itself",
    settings = "settings", codex = "the codex (rosetta)", quit = "exit",
  }
  local mx, my = vmouse()
  local hoverTr
  for _, it in ipairs(items) do
    local hov = mx >= bx and mx <= bx + bw and my >= by and my <= by + bh
    button(it[1], bx, by, bw, bh, it[2], hov, it[3])
    if hov then hoverTr = TR[it[1]] end
    by = by + bh + gap
  end

  -- achievements: a small corner button (kept OUT of the crowded central stack)
  do
    local aw, ah = 160, 32
    local ax, ay = w - aw - 24, h - ah - 22
    local hov = mx >= ax and mx <= ax + aw and my >= ay and my <= ay + ah
    button("achv", ax, ay, aw, ah, "achievements", hov, "achievements")
  end

  -- big bobbing arrow pointing at INFO until it's been opened once
  if not ctx.infoSeen and not ctx.info and not ctx.codex and not ctx.settings and not ctx.achv then
    local r = UI.getRegion("info")
    if r then
      local bob = math.sin(love.timer.getTime() * 4) * 12
      local tipx = r.x - 24 - bob
      local cy = r.y + r.h / 2
      setc(th.accent)
      love.graphics.setLineWidth(8)
      love.graphics.line(tipx - 70, cy, tipx, cy)
      love.graphics.polygon("fill", tipx, cy, tipx - 24, cy - 17, tipx - 24, cy + 17)
      love.graphics.setFont(UI.fs); setc(th.accent)
      love.graphics.print("new? start here", tipx - 150, cy - 34)
    end
  end

  -- translation tooltip near the cursor
  if hoverTr and not ctx.codex and not ctx.settings and not ctx.info and not ctx.achv then
    love.graphics.setFont(UI.fs)
    local tw = UI.fs:getWidth(hoverTr) + 18
    local tx, ty = mx + 16, my + 8
    if tx + tw > w then tx = w - tw - 4 end
    setc(th.panel); love.graphics.rectangle("fill", tx, ty, tw, 26, th.round, th.round)
    setc(th.border); love.graphics.rectangle("line", tx, ty, tw, 26, th.round, th.round)
    setc(th.english); love.graphics.print(hoverTr, tx + 9, ty + 5)
  end

  -- overlays opened from the menu
  if ctx.info then
    overlayInfo(w * 0.12, h * 0.09, w * 0.76, h * 0.80)
    reg("menuinfoclose", 0, 0, w, h)
  elseif ctx.achv then
    overlayAchievements(w * 0.14, h * 0.08, w * 0.72, h * 0.84)
    reg("menuachvclose", 0, 0, w, h)
  elseif ctx.codex then
    overlayCodex(w * 0.10, h * 0.12, w * 0.80, h * 0.74)
    reg("menucodexclose", 0, 0, w, h)
  elseif ctx.settings then
    -- registration order matters (hitTest returns the topmost / last-registered):
    --   full-screen close (bottom) < panel background (mid) < setting rows (top)
    reg("menusetclose", 0, 0, w, h)
    local sx, sy, sw, sh = w * 0.22, h * 0.22, w * 0.56, h * 0.52
    reg("setpanel", sx, sy, sw, sh)
    overlaySettings(sx, sy, sw, sh, ctx.auto)
  end
end

-- =============================================================== PLAY ========
local function colorsFor(kind, th)
  if kind == "echo" then return th.input, th.input
  elseif kind == "foe" then return th.foe, th.gel
  elseif kind == "sys" then return th.gel, th.gel
  else return th.english, th.gel end -- narr
end

-- builds flat display lines from the log for the console area
local function buildLines(log, font, gs, maxw)
  local lines = {}
  for _, e in ipairs(log) do
    local text = e.text
    if e.kind == "echo" then text = "> " .. text end
    local wl = R.layout(text, font, gs, maxw)
    for _, l in ipairs(wl) do lines[#lines + 1] = { items = l, kind = e.kind } end
    lines[#lines + 1] = { items = {}, kind = "gap" } -- spacer
  end
  return lines
end

local function drawConsole(sim, ctx, x, y, w, h)
  local th = T()
  panel(x, y, w, h)
  local pad = 14
  local font, gs = UI.f, math.floor(UI.f:getHeight() * 0.82)
  local lineH = math.floor(UI.f:getHeight() * 1.45)
  love.graphics.setFont(font)
  local innerW = w - pad * 2
  local lines = buildLines(ctx.log, font, gs, innerW)
  local visible = math.floor((h - pad * 2) / lineH)
  local total = #lines
  local startI = total - visible - (ctx.scroll or 0)
  if startI < 1 then startI = 1 end
  local endI = math.min(total, startI + visible - 1)
  -- clip
  love.graphics.setScissor(x, y, w, h)
  local cy = y + pad
  for i = startI, endI do
    local ln = lines[i]
    if ln.kind ~= "gap" then
      local ce, cg = colorsFor(ln.kind, th)
      R.draw({ ln.items }, x + pad, cy, font, gs, lineH, ce, cg)
    end
    cy = cy + lineH
  end
  love.graphics.setScissor()
  ctx._consoleLines = total
  ctx._consoleVisible = visible
end

local function drawInput(ctx, x, y, w, h)
  local th = T()
  panel(x, y, w, h)
  reg("input", x, y, w, h)
  setc(th.gel)
  Glyph.drawText("kren", x + 12, y + (h - 16) / 2, 16) -- prompt rune
  love.graphics.setFont(UI.f)
  setc(th.input)
  local tx = x + 80
  love.graphics.print(ctx.cmdbuf or "", tx, y + (h - UI.f:getHeight()) / 2)
  -- block cursor
  if (love.timer.getTime() % 1) < 0.55 then
    local cw = UI.f:getWidth(ctx.cmdbuf or "")
    setc(th.input)
    love.graphics.rectangle("fill", tx + cw + 1, y + (h - UI.f:getHeight()) / 2 + 2, 9, UI.f:getHeight() - 4)
  end
end

local function drawTabs(x, y, w, h, selId)
  local th = T()
  local n = #L.tabs
  local gap = 8
  local bw = (w - gap * (n - 1)) / n
  local mx, my = vmouse()
  for i, tab in ipairs(L.tabs) do
    local bx = x + (i - 1) * (bw + gap)
    local hov = mx >= bx and mx <= bx + bw and my >= y and my <= y + h
    button("tab:" .. tab.id, bx, y, bw, h, tab.rune, hov, tab.plain)
    if tab.id == selId then                     -- the open tab: a bright outline
      setc(th.accent)
      love.graphics.setLineWidth(3)
      love.graphics.rectangle("line", bx + 1, y + 1, bw - 2, h - 2, th.round, th.round)
    end
  end
end

-- overlays --------------------------------------------------------------------
local function overlayStats(sim, x, y, w, h)
  local th = T()
  panel(x, y, w, h)
  local pad = 24
  setc(th.gel)
  Glyph.drawText("vyrna", x + pad, y + pad, 22)
  local function val(key)
    if key == "vyr" then return sim.vyr
    elseif key == "thuum" then return sim.thuum
    elseif key == "gloam" then return sim.gloam
    elseif key == "seth" then return sim.seth
    elseif key == "wake" then return sim.wake
    elseif key == "za" then return sim.sig.za
    elseif key == "qor" then return sim.sig.qor
    elseif key == "neth" then return sim.sig.neth
    elseif key == "vael" then return sim.attune()
    elseif key == "tik" then return sim.tik
    elseif key == "gnos" then return sim.gnos()
    elseif key == "depf" then return sim.depf() end
    return 0
  end
  local ry = y + pad + 44
  local rowH = (h - (pad + 44) - pad) / #L.stats
  for _, def in ipairs(L.stats) do
    local v = val(def.key)
    local frac = nil
    if def.key ~= "tik" and def.key ~= "gnos" and def.key ~= "depf" then frac = v / 100 end
    statRow(x + pad, ry, w - pad * 2, def, v, frac)
    ry = ry + rowH
  end
  -- foe state, if any
  local foe = sim.foe and sim.foe()
  if foe then
    local fy = y + h - pad - 26
    setc(th.foe)
    Glyph.drawText(foe.name, x + pad, fy, 18)
    Glyph.drawText("to", x + pad + 160, fy, 14)
    Glyph.drawText(foe.dir or "", x + pad + 200, fy - 2, 20)
    Glyph.drawText("glamour", x + pad + 290, fy, 14)
    Glyph.drawText(tostring(foe.glamour), x + pad + 380, fy - 2, 20)
  end
end

local function nameFit(str, maxw, base)
  local s = base
  while s > 6 and Glyph.width(str, s) > maxw do s = s - 1 end
  return s
end

-- a distinct colour per section (cool mode; boring stays grey).
-- section 1 is blue, as in the original.
local SECTION_COLORS = {
  { 0.18, 0.26, 0.42 }, -- 1 blue
  { 0.30, 0.20, 0.38 }, -- 2 violet
  { 0.36, 0.22, 0.20 }, -- 3 rust
  { 0.18, 0.32, 0.26 }, -- 4 green
  { 0.36, 0.30, 0.18 }, -- 5 amber (the deep)
}
local function sectionTint(sec)
  return SECTION_COLORS[((sec - 1) % #SECTION_COLORS) + 1]
end

-- the map shows the CURRENT section only (you only carry one section in your head)
local function overlayMap(sim, x, y, w, h)
  local th = T()
  panel(x, y, w, h)
  local pad = 16
  local curSec = sim.nodes[sim.node].sec
  local ax, ay = x + pad, y + pad
  local aw, ah = w - pad * 2, h - pad * 2
  local cw, ch = aw / W.secW, ah / W.secH
  local tint = sectionTint(curSec)
  local function inSec(n) return n.sec == curSec end
  local function cx(n) return ax + n.lx * cw + cw / 2 end
  local function cy(n) return ay + n.ly * ch + ch / 2 end

  -- edges within this section
  for _, n in pairs(sim.nodes) do
    if n.visited and inSec(n) then
      for _, dir in ipairs(W.dirOrder) do
        local toId = n.exits[dir]
        local m = toId and sim.nodes[toId]
        if m and m.visited and inSec(m) then
          setc(th.border, 0.7); love.graphics.setLineWidth(1)
          love.graphics.line(cx(n), cy(n), cx(m), cy(m))
        end
      end
    end
  end

  -- nodes of this section (visited OR seen-from-adjacent show up)
  for _, n in pairs(sim.nodes) do
    if inSec(n) and (n.visited or n.seen) then
      local bx, by = ax + n.lx * cw + 5, ay + n.ly * ch + 5
      local bw, bh = cw - 10, ch - 10
      local foe = sim.foeAt and sim.foeAt(n.id)
      local cur = (n.id == sim.node)
      if cur then setc(th.accent)
      elseif foe then setc(th.foe, 0.22)
      elseif n.visited then setc(UI.cool and tint or th.panel)
      else setc(th.panel, 0.5) end          -- seen but not entered
      love.graphics.rectangle("fill", bx, by, bw, bh, th.round, th.round)
      setc(foe and th.foe or th.border)
      love.graphics.rectangle("line", bx, by, bw, bh, th.round, th.round)
      if foe then
        -- the entity sits on the tile: name + a little glamour bar
        setc(th.foe)
        local s = nameFit(foe.name, bw - 8, 13)
        Glyph.drawTextCentered(foe.name, bx + bw / 2, by + bh / 2 - s, s)
        local gbw = bw - 14
        setc(th.barbg); love.graphics.rectangle("fill", bx + 7, by + bh - 12, gbw, 5)
        setc(th.foe); love.graphics.rectangle("fill", bx + 7, by + bh - 12, gbw * math.max(0, math.min(1, foe.glamour / foe.max)), 5)
      elseif n.gatehere then
        -- a GATE tile: door icon + frame. white when you're on it, else amber=sealed / green=open.
        local open = sim.gatesOpen[n.gatehere]
        local gc = cur and { 1, 1, 1 } or (open and { 0.40, 0.92, 0.55 } or { 0.88, 0.74, 0.40 })
        setc(gc); love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", bx + 2, by + 2, bw - 4, bh - 4, th.round, th.round)
        local dw, dh = bw * 0.34, bh * 0.42
        local dx, dy = bx + bw / 2 - dw / 2, by + bh / 2 - dh / 2 + 4
        love.graphics.line(dx, dy + dh, dx, dy, dx + dw, dy, dx + dw, dy + dh) -- doorway ⊓
        if not open then love.graphics.line(dx, dy + dh * 0.55, dx + dw, dy + dh * 0.55) end -- sealed bar
        love.graphics.circle("line", bx + 9, by + 9, 4)  -- the corner marker, kept
        setc(gc)
        Glyph.drawTextCentered("gate", bx + bw / 2, by + 4, 14)  -- runes, like everything else
      elseif n.type == "heart" then
        -- the HEART tile: a "heart" label + gold ring (white when you're on it)
        local hc = cur and { 1, 1, 1 } or { 0.98, 0.82, 0.35 }
        setc(hc); Glyph.drawTextCentered("heart", bx + bw / 2, by + bh / 2 - 18, 16)
        love.graphics.setColor(hc[1], hc[2], hc[3], 1); love.graphics.setLineWidth(2.5)
        love.graphics.circle("line", bx + bw / 2, by + bh - 14, 7)
        love.graphics.circle("fill", bx + bw / 2, by + bh - 14, 3)
      else
        local s = nameFit(n.name, bw - 8, 14)
        setc(th.gel)
        Glyph.drawTextCentered(n.name, bx + bw / 2, by + bh / 2 - s / 2, s)
        if n.type and n.type:match("^shrine") then
          love.graphics.setLineWidth(2.5)
          if cur then love.graphics.setColor(1, 1, 1, 1) else love.graphics.setColor(0.40, 0.92, 0.50, 1) end
          love.graphics.circle("line", bx + bw / 2, by + bh - 14, 7) -- shrine marker
        end
      end
    elseif inSec(n) then
      setc(th.border, 0.4)
      love.graphics.circle("line", cx(n), cy(n), 3)
    end
  end
end

function overlayCodex(x, y, w, h)
  local th = T()
  panel(x, y, w, h)
  local pad = 22
  love.graphics.setFont(UI.fs)
  setc(th.gel)
  Glyph.drawText("rosetta", x + pad, y + pad, 20)

  -- left column: alphabet + digits (latin key -> rune)
  local colx = x + pad
  local cy = y + pad + 40
  setc(th.english)
  love.graphics.print("the script", colx, cy); cy = cy + 20
  local cellw = 46
  local perRow = math.floor((w * 0.42) / cellw)
  if perRow < 1 then perRow = 1 end
  local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
  for i = 1, #chars do
    local ch = chars:sub(i, i)
    local col = (i - 1) % perRow
    local row = math.floor((i - 1) / perRow)
    local gx = colx + col * cellw
    local gy = cy + row * 40
    setc(th.gel)
    Glyph.drawChar(ch:byte(1), gx, gy, 22)
    setc(th.english)
    love.graphics.print(ch, gx + 8, gy + 24)
  end

  -- right column: verbs + dirs (latin -> english meaning). the grammar key.
  local rx = x + w * 0.46
  local ry = y + pad + 40
  setc(th.english)
  love.graphics.print("the rite-verbs (type these)", rx, ry); ry = ry + 22
  for _, v in ipairs(L.codexVerbs) do
    setc(th.input)
    love.graphics.print(v[1], rx, ry)
    setc(th.english)
    love.graphics.printf(v[2], rx + 86, ry, w * 0.5 - 96)
    ry = ry + (UI.fs:getHeight() * (1 + math.floor(UI.fs:getWidth(v[2]) / (w * 0.5 - 96)))) + 4
  end
  ry = ry + 8
  setc(th.english)
  love.graphics.print("the ways", rx, ry); ry = ry + 20
  for _, d in ipairs(L.codexDirs) do
    setc(th.input)
    love.graphics.print(d[1], rx, ry)
    setc(th.english)
    love.graphics.print(d[2], rx + 70, ry)
    ry = ry + 20
  end
end

-- english gloss tooltip near the cursor (shared by menu + settings)
function UI.tooltip(text)
  if not text then return end
  local th = T()
  local mx, my = vmouse()
  local w = UI.W
  love.graphics.setFont(UI.fs)
  local tw = UI.fs:getWidth(text) + 18
  local tx, ty = mx + 16, my + 8
  if tx + tw > w then tx = w - tw - 4 end
  setc(th.panel); love.graphics.rectangle("fill", tx, ty, tw, 26, th.round, th.round)
  setc(th.border); love.graphics.rectangle("line", tx, ty, tw, 26, th.round, th.round)
  setc(th.english); love.graphics.print(text, tx + 9, ty + 5)
end

-- the info / lore screen. obscure on purpose, thick with {gelenath}.
local INFO = {
  "{si'larbentethegn} does not sleep as you sleep. It is {folded}, waiting. You are {bul'narth} — the wrong little {hand} it grew in its dreaming to undo its own {seal}. Your purpose is to {ugnaken} it: to wake it.",
  "TO WIN: descend to the deep, light the three shrines, fell the {warden}, and speak the {Word} until it wakes.",
  "DESCEND. Each section is closed by a {gate}. Stand on it, read it open with  seth , then pass through with  klor . Entities ring everything that matters; strike a foe on a neighbouring tile with  kresh  and the way toward it.",
  "THE SHRINES. In the deepest section sit three shrines: {morr}, {qhel}, {zyth}. Clear the foes ringing a shrine, step onto it, and  vorth  to light its sigil. Light all three (watch them rise in {vyrna}).",
  "THE HEART. Then reach the {heart}, unmake its {warden}, stand upon it, and  uthenn  the {Word} again and again. Each utterance lifts {ugna} but spends your sigils, so re-light the shrines and return. When {ugna} is full, the {si'lar} wakes and you have won.",
  "Half of this is written in {gelenath} no one is meant to read at a glance; the {karth} shifts every run; death keeps nothing. If it makes no sense, that is the {sense} of it.",
  "Don't want to learn a strange font? Go to settings and set the script to english, and all of this will be translated into plain letters.",
}
function overlayInfo(x, y, w, h)
  local th = T()
  panel(x, y, w, h)
  local pad = 30
  setc(th.gel)
  Glyph.drawTextCentered("si'larbentethegn", x + w / 2, y + pad, 30)
  love.graphics.setFont(UI.fs); setc(th.english)
  love.graphics.printf("(formerly Complicated Game)", x, y + pad + 44, w, "center")
  -- body: mixed english + rune, wrapped
  local font, gs = UI.fs, math.floor(UI.fs:getHeight() * 0.92)
  love.graphics.setFont(font)
  local lineH = math.floor(font:getHeight() * 1.5)
  local ty = y + pad + 84
  local maxw = w - pad * 2
  for _, para in ipairs(INFO) do
    local lines = R.layout(para, font, gs, maxw)
    ty = R.draw(lines, x + pad, ty, font, gs, lineH, th.english, th.gel) + lineH * 0.5
  end
  love.graphics.setFont(UI.fs); setc(th.accent)
  love.graphics.printf("(click anywhere to close)", x, y + h - 30, w, "center")
end

-- the achievements page. reads unlock state from the portal (earned entries lit,
-- the rest dimmed; hidden+unearned shown as ???). plain english, like info/exit.
local RARITY = {
  common    = { 0.72, 0.74, 0.80 },
  uncommon  = { 0.45, 0.88, 0.58 },
  rare      = { 0.45, 0.72, 1.00 },
  legendary = { 0.97, 0.82, 0.42 },
}
function overlayAchievements(x, y, w, h)
  local th = T()
  panel(x, y, w, h)
  local pad = 26
  love.graphics.setFont(UI.f); setc(th.english)
  love.graphics.printf("achievements", x, y + 16, w, "center")
  -- tally
  local earned, epts, tpts = 0, 0, 0
  for _, a in ipairs(ACHV) do
    tpts = tpts + (a.points or 10)
    if Portal.isUnlocked(a.key) then earned = earned + 1; epts = epts + (a.points or 10) end
  end
  love.graphics.setFont(UI.fs); setc(th.accent)
  love.graphics.printf(earned .. " / " .. #ACHV .. "   \194\183   " .. epts .. " / " .. tpts .. " pts",
    x, y + 46, w, "center")
  -- rows
  local top = y + 80
  local rowH = math.min(48, (h - 80 - pad) / #ACHV)
  for i, a in ipairs(ACHV) do
    local ry = top + (i - 1) * rowH
    local got = Portal.isUnlocked(a.key)
    local rc = RARITY[a.rarity or "common"] or RARITY.common
    local cy = ry + rowH / 2 - 4
    -- status dot (filled when earned)
    setc(got and rc or th.barbg); love.graphics.circle("fill", x + pad + 9, cy, 7)
    setc(rc, got and 1 or 0.5); love.graphics.setLineWidth(2); love.graphics.circle("line", x + pad + 9, cy, 7)
    local title, desc = a.title, a.desc
    if a.hidden and not got then title = "???"; desc = "a secret — yet to be earned" end
    love.graphics.setFont(UI.f); setc(got and rc or th.english, got and 1 or 0.45)
    love.graphics.print(title, x + pad + 30, ry + 1)
    love.graphics.setFont(UI.fs); setc(th.english, got and 0.85 or 0.4)
    love.graphics.print(desc, x + pad + 30, ry + 24)
    love.graphics.setFont(UI.fs); setc(rc, got and 1 or 0.5)
    love.graphics.printf((a.points or 10) .. " pts", x, ry + 9, w - pad, "right")
  end
  love.graphics.setFont(UI.fs); setc(th.accent)
  love.graphics.printf("(click anywhere to close)", x, y + h - 28, w, "center")
end

-- settings rows: each toggles between two rune options. cur shown highlighted.
function overlaySettings(x, y, w, h, autoOn)
  local th = T()
  panel(x, y, w, h)
  local pad = 26
  setc(th.gel)
  Glyph.drawText("sethna", x + pad, y + pad, 22)
  local function curIndex(id)
    if id == "script" then
      return (Glyph.script == "galactic") and 2 or (Glyph.script == "english") and 3 or 1
    elseif id == "ui" then return UI.cool and 2 or 1 end
    return 1
  end
  local mx, my = vmouse()
  local hoverTr
  local ry = y + pad + 56
  local rowH = (h - (pad + 56) - pad) / #L.settings
  for _, row in ipairs(L.settings) do
    setc(th.gel)
    Glyph.drawText(row.rune, x + pad, ry, 18)
    local nOpt = #row.opts
    local cgap, chipH = 10, 32
    local areaW = (x + w - pad) - (x + pad + 110)         -- space right of the label
    local chipW = math.min(150, (areaW - cgap * (nOpt - 1)) / nOpt)
    local startX = x + w - pad - (chipW * nOpt + cgap * (nOpt - 1))
    local cur = curIndex(row.id)
    for i, opt in ipairs(row.opts) do
      local cxp = startX + (i - 1) * (chipW + cgap)
      local sel = (i == cur)
      setc(sel and th.accent or th.barbg)
      love.graphics.rectangle("fill", cxp, ry - 4, chipW, chipH, th.round, th.round)
      setc(th.border)
      love.graphics.rectangle("line", cxp, ry - 4, chipW, chipH, th.round, th.round)
      setc(th.gel)
      if row.id == "script" then
        -- draw each script option IN that script, so you can see what each looks like
        local prev = Glyph.script
        Glyph.script = ({ "gelenath", "galactic", "english" })[i] or "gelenath"
        Glyph.drawTextCentered(opt, cxp + chipW / 2, ry + (chipH - 16) / 2 - 4, 16)
        Glyph.script = prev
      else
        Glyph.drawTextCentered(opt, cxp + chipW / 2, ry + (chipH - 16) / 2 - 4, 16)
      end
      -- each chip is its own click target (pick directly, no cycling)
      reg("set:" .. row.id .. ":" .. i, cxp, ry - 4, chipW, chipH)
      if mx >= cxp and mx <= cxp + chipW and my >= ry - 4 and my <= ry - 4 + chipH then
        hoverTr = (row.optTr and row.optTr[i]) or opt
      end
    end
    -- hovering the row label translates the setting
    if not hoverTr and mx >= x + pad and mx <= startX and my >= ry - 8 and my <= ry - 8 + rowH then
      hoverTr = row.tr
    end
    ry = ry + rowH
  end
  -- reset-data button (english, destructive)
  local rbw, rbh = 200, 34
  local rbx, rby = x + w - pad - rbw, y + h - pad - rbh
  local hov = mx >= rbx and mx <= rbx + rbw and my >= rby and my <= rby + rbh
  setc(hov and th.foe or th.barbg)
  love.graphics.rectangle("fill", rbx, rby, rbw, rbh, th.round, th.round)
  setc(th.foe); love.graphics.rectangle("line", rbx, rby, rbw, rbh, th.round, th.round)
  love.graphics.setFont(UI.fs); setc(th.english)
  love.graphics.printf("reset data", rbx, rby + (rbh - UI.fs:getHeight()) / 2, rbw, "center")
  reg("set:reset", rbx, rby, rbw, rbh)
  UI.tooltip(hoverTr)
end

-- the "type RESET" confirmation modal (drawn on top of everything)
function UI.resetModal(buf)
  local th = T()
  local w, h = UI.W, UI.H
  love.graphics.setColor(0, 0, 0, 0.6); love.graphics.rectangle("fill", 0, 0, w, h)
  local pw, ph = math.min(520, w * 0.7), 200
  local px, py = w / 2 - pw / 2, h / 2 - ph / 2
  panel(px, py, pw, ph)
  setc(th.foe); love.graphics.setLineWidth(2); love.graphics.rectangle("line", px, py, pw, ph, th.round, th.round)
  love.graphics.setFont(UI.f); setc(th.foe)
  love.graphics.printf("RESET ALL DATA?", px, py + 20, pw, "center")
  love.graphics.setFont(UI.fs); setc(th.english)
  love.graphics.printf("This erases your wins and your saved run. Settings are kept.\nType  RESET  to confirm.", px + 20, py + 58, pw - 40, "center")
  -- the typed buffer box
  love.graphics.setFont(UI.f)
  local bw2, bh2 = 220, 36
  local bx2, by2 = px + pw / 2 - bw2 / 2, py + 108
  setc(th.barbg); love.graphics.rectangle("fill", bx2, by2, bw2, bh2, th.round, th.round)
  setc(th.border); love.graphics.rectangle("line", bx2, by2, bw2, bh2, th.round, th.round)
  setc(th.input); love.graphics.printf(buf or "", bx2, by2 + (bh2 - UI.f:getHeight()) / 2, bw2, "center")
  setc(th.accent); love.graphics.setFont(UI.fs)
  love.graphics.printf("enter to confirm  ·  esc or click to cancel", px, py + ph - 28, pw, "center")
  reg("resetcancel", 0, 0, w, h)
end

local function drawBanner(text, x, y, w, h, withContinue)
  local th = T()
  panel(x, y, w, h, th.cool and nil or th.panel)
  local font, gs = UI.fs, math.floor(UI.fs:getHeight() * 0.9)
  love.graphics.setFont(font)
  setc(th.accent)
  Glyph.drawText("kennan", x + 12, y + 8, 14)
  local lines = R.layout(text, font, gs, w - 24)
  R.draw(lines, x + 12, y + 26, font, gs, math.floor(font:getHeight() * 1.3), th.english, th.gel)
  if withContinue then
    local bw, bh = 130, 26
    local bx, by = x + w - bw - 12, y + h - bh - 8
    panel(bx, by, bw, bh, th.accent)
    love.graphics.setFont(UI.f)
    setc(th.cool and { 0.05, 0.08, 0.14 } or th.english)
    local label = "continue"
    love.graphics.print(label, bx + (bw - UI.f:getWidth(label)) / 2, by + (bh - UI.f:getHeight()) / 2)
    reg("tutcontinue", bx, by, bw, bh)
  end
end

-- the status line: the latest piece of feedback (no scrolling console)
local function drawStatus(ctx, x, y, w, h)
  panel(x, y, w, h)
  local e
  for i = #ctx.log, 1, -1 do
    local le = ctx.log[i]
    if le.kind ~= "gap" and le.kind ~= "echo" then e = le; break end
  end
  if not e then return end
  local th = T()
  local font, gs = UI.fs, math.floor(UI.fs:getHeight() * 0.92)
  love.graphics.setFont(font)
  local lineH = math.floor(font:getHeight() * 1.4)
  local ce, cg = colorsFor(e.kind, th)
  local lines = R.layout(e.text, font, gs, w - 20)
  local show = {}
  for i = 1, math.min(4, #lines) do show[i] = lines[i] end
  R.draw(show, x + 10, y + 8, font, gs, lineH, ce, cg)
end

function UI.play(sim, ctx)
  local th = T()
  drawBG()
  local w, h = UI.W, UI.H
  local m, tabH, inputH, headerH = 16, 44, 46, 26
  -- which tab is "open": the map (karth) is the default view, else the active overlay
  local selTab = (ctx.overlay == "stats" and "stats") or (ctx.overlay == "codex" and "codex")
              or ((not ctx.overlay) and "map") or nil
  drawTabs(m, m, w - m * 2, tabH, selTab)

  -- section name on top + depth (the three sigils live in the vyrna stats panel)
  setc(th.gel)
  Glyph.drawTextCentered(sim.sectionName() or "", w / 2, m + tabH + 6, 18)
  setc(th.accent)
  Glyph.drawText("depf", m + 4, m + tabH + 8, 12)
  Glyph.drawText(tostring(sim.depf()), m + 48, m + tabH + 6, 16)

  local mapY = m + tabH + headerH + 6
  local tutH = 0
  if ctx.tutorialText then
    local font, gs = UI.fs, math.floor(UI.fs:getHeight() * 0.9)
    local lh = math.floor(font:getHeight() * 1.3)
    local lines = R.layout(ctx.tutorialText, font, gs, w - m * 2 - 24)
    local hb = 26 + #lines * lh + 10 + (ctx.tutorialContinue and 34 or 0)
    drawBanner(ctx.tutorialText, m, mapY, w - m * 2, hb, ctx.tutorialContinue)
    tutH = hb + 8
  end
  mapY = mapY + tutH
  local inputY = h - inputH - m
  local mapH = (inputY - 6) - mapY

  -- the MAP is the main view (no console, no status strip)
  overlayMap(sim, m, mapY, w - m * 2, mapH)
  drawInput(ctx, m, inputY, w - m * 2, inputH)

  -- overlays cover the map region (karth tab just returns to the map)
  if ctx.overlay == "stats" then overlayStats(sim, m, mapY, w - m * 2, mapH)
  elseif ctx.overlay == "codex" then overlayCodex(m, mapY, w - m * 2, mapH)
  elseif ctx.overlay == "settings" then overlaySettings(m, mapY, w - m * 2, mapH, ctx.auto) end

  -- DANGER reminder: low grip or high corruption, always visible & actionable
  local tok, hint
  if sim.gloam >= 78 then tok = "glom"; hint = "HIGH - purge (svael)"
  elseif sim.seth <= 24 then tok = "seth"; hint = "LOW - rest (lu)" end
  if tok then
    local pulse = 0.5 + 0.5 * math.abs(math.sin(love.timer.getTime() * 5))
    local bw2 = 240; local bx2 = w / 2 - bw2 / 2; local by2 = mapY + 8
    love.graphics.setColor(0.92, 0.16, 0.13, 0.9 * pulse)
    love.graphics.rectangle("fill", bx2, by2, bw2, 30, th.round, th.round)
    setc({ 1, 1, 1 }); Glyph.drawText(tok, bx2 + 12, by2 + 7, 16)
    love.graphics.setFont(UI.fs); love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(hint, bx2 + 62, by2 + 9)
  end

  -- a SECRET whisper, surfacing faintly over the map and fading (only on the map view)
  if ctx.whisper and ctx.whisperAge and ctx.whisperAge < 7 and not ctx.overlay then
    local a = math.max(0, 0.7 * (1 - ctx.whisperAge / 7))
    local font, gs = UI.fs, math.floor(UI.fs:getHeight() * 0.92)
    love.graphics.setFont(font)
    local space = font:getWidth(" ")
    local goff = (font:getHeight() - gs) * 0.5
    local lineH = math.floor(font:getHeight() * 1.5)
    local lines = R.layout(ctx.whisper, font, gs, w * 0.62)
    local wy = mapY + (mapH - #lines * lineH) / 2
    for _, line in ipairs(lines) do
      local lw = 0
      for j, it in ipairs(line) do lw = lw + it.w + (j > 1 and space or 0) end
      local cx = w / 2 - lw / 2
      for j, it in ipairs(line) do
        if j > 1 then cx = cx + space end
        if it.t == "g" then setc(th.gel, a); Glyph.drawText(it.word, cx, wy + goff, gs)
        else setc(th.english, a); love.graphics.print(it.word, cx, wy) end
        cx = cx + it.w
      end
      wy = wy + lineH
    end
  end

  if ctx.auto then
    -- clickable speed toggle (also F3): shows current autoplay speed, click to switch 1x/5x
    local cw, ch = 150, 28
    local cx, cy = w - m - cw, m + tabH + 2
    panel(cx, cy, cw, ch)
    setc(th.accent); Glyph.drawText("vorae", cx + 8, cy + 7, 13)
    love.graphics.setFont(UI.fs)
    local spd = ctx.autoSpeed or 1
    if spd > 1 then love.graphics.setColor(0.40, 0.92, 0.50, 1) else love.graphics.setColor(0.62, 0.62, 0.68, 1) end
    love.graphics.print("speed " .. spd .. "x", cx + 64, cy + 7)
    reg("speedtoggle", cx, cy, cw, ch)
  end
end

-- a red edge-flash when you take damage, so harm is never silent
function UI.damageFlash(a)
  local w, h = UI.W, UI.H
  love.graphics.setColor(0.92, 0.16, 0.13, 0.55 * a)
  local b = 26
  love.graphics.rectangle("fill", 0, 0, w, b)
  love.graphics.rectangle("fill", 0, h - b, w, b)
  love.graphics.rectangle("fill", 0, 0, b, h)
  love.graphics.rectangle("fill", w - b, 0, b, h)
end

-- one-time intro shown at the start of a run (the "you stir at the {vael'thuun}…")
function UI.introScreen(text)
  local th = T()
  local w, h = UI.W, UI.H
  love.graphics.setColor(0, 0, 0, 0.7); love.graphics.rectangle("fill", 0, 0, w, h)
  local pw, ph = math.min(680, w * 0.8), math.min(360, h * 0.7)
  local px, py = w / 2 - pw / 2, h / 2 - ph / 2
  panel(px, py, pw, ph)
  setc(th.gel)
  Glyph.drawTextCentered(L.title, px + pw / 2, py + 24, 26)
  local font, gs = UI.f, math.floor(UI.f:getHeight() * 0.82)
  love.graphics.setFont(font)
  local lineH = math.floor(font:getHeight() * 1.5)
  local lines = R.layout(text or "", font, gs, pw - 56)
  R.draw(lines, px + 28, py + 80, font, gs, lineH, th.english, th.gel)
  setc(th.accent); love.graphics.setFont(UI.fs)
  love.graphics.printf("click to begin", px, py + ph - 30, pw, "center")
  reg("introdismiss", 0, 0, w, h)
end

-- =============================================================== OVER ========
function UI.over(sim, ctx)
  local th = T()
  drawBG()
  local w, h = UI.W, UI.H
  local line, cause
  if sim.status == "ascended" then line = "si'larbentethegn ugnaken"; cause = "the Sleeper wakes — you win"
  elseif sim.status == "dissolved" then line = "bul'narth vaen"; cause = "your grip (SETH) ran out"
  else line = "gloam thenn"; cause = "your corruption (GLOM) reached its limit" end
  setc(th.gel)
  Glyph.drawTextCentered(line, w / 2, h * 0.36, 34)
  love.graphics.setFont(UI.fs); setc(th.english)
  love.graphics.printf(cause, 0, h * 0.36 + 48, w, "center")
  -- a SECRET revelation, one of several, chosen by this run's seed (changes per run)
  local secret
  if sim.status == "ascended" then
    local S = {
      "The dream is ending. There was never an \"after\" for it to wake into.",
      "You were the hand it grew to undo itself — and you did not fail it.",
      "The silence that let everything exist is over now.",
      "For the first time in all of forever, it opens its regard.",
      "Its sleep was the mercy. You were the mistake. Now there is neither.",
    }
    secret = S[((sim.seed or 0) % #S) + 1]
  else
    local D = {
      "The dream turns over, and forgets you. It always does.",
      "A wrong little finger twitches in the deep, and goes still.",
      "The seal holds. You were not enough of an error.",
    }
    secret = D[((sim.seed or 0) % #D) + 1]
  end
  setc(th.english, 0.5)
  love.graphics.printf(secret, w * 0.15, h * 0.36 + 86, w * 0.7, "center")
  -- runic numeral of wins (pushed below the secret line so they never overlap)
  setc(th.gel)
  Glyph.drawTextCentered("wins", w / 2 - 30, h * 0.58, 16)
  Glyph.drawText(tostring(ctx.wins), w / 2 + 30, h * 0.58 - 2, 22)
  if ctx.ai then
    setc(th.foe)
    Glyph.drawTextCentered("vorae na wins", w / 2, h * 0.64, 14) -- AI run: not counted
  end
  setc(th.accent)
  Glyph.drawTextCentered("kren vaen", w / 2, h * 0.70, 16)
  reg("overback", 0, 0, w, h)
end

return UI
