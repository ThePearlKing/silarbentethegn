-- main.lua :: complicated game / si'larbentethegn
-- a blind, command-driven eldritch rite. you are bul'narth; wake the sleeper.

local UI    = require("src.ui")
local sim   = require("src.sim")
local save  = require("src.save")
local synth = require("src.synth")
local T     = require("src.tutorial")
local Glyph = require("src.glyph")
local L     = require("src.lang")
local AP    = require("src.autoplay")  -- the visible, paced "rite plays itself"

local G = {
  state    = "menu",   -- menu | play | over
  log      = {},
  cmdbuf   = "",
  scroll   = 0,
  overlay  = nil,      -- stats | map | codex | settings | nil
  wins     = 0,
  hasSave  = false,
  menuCodex = false,
  menuSettings = false,
  menuInfo = false,
  infoSeen = false,
  intro = false,        -- one-time intro message at the start of a run
  introText = "",
  hurtT = -9,           -- time of last damage taken (drives the red flash)
  resetConfirm = false,
  resetBuf = "",
  lastVerb = nil,
  _lines = 0, _visible = 1,
}

-- ----------------------------------------------------------------- helpers ---
local function push(e) G.log[#G.log + 1] = e end
local function pushAll(list) for _, e in ipairs(list) do push(e) end end
local function trimLog() while #G.log > 240 do table.remove(G.log, 1) end end
local function canonVerb(raw)
  local head = raw:lower():match("%S+")
  if not head then return nil end
  if L.dirset[head] then return "move" end
  return L.verbs[head]
end

local function stopAuto()
  -- "leave autoplay": the AI lets go, you keep playing the same run
  AP.stop()
  G.cmdbuf = ""
end

local function startAuto()
  local w, h = love.graphics.getDimensions()
  AP.start(w, h)
  G.overlay = nil
  -- the system cursor stays visible alongside the AI's light-blue hand
end

local function toMenu()
  stopAuto()
  G.state = "menu"; G.overlay = nil; G.menuCodex = false; G.menuSettings = false
  G.hasSave = save.hasGame()
  synth.stopDrone()
end

-- snap the view to the tab the current tutorial step wants you on
local function applyTutSnap()
  if not T.active then return end
  local s = T.snapTab()
  if s == "karth" then G.overlay = nil
  elseif s == "vyrna" then G.overlay = "stats"
  elseif s == "rosetta" then G.overlay = "codex" end
end

local function tutorialAdvance()
  if not T.active then return end
  local before = T.step
  local final = T.check({ overlay = G.overlay, lastVerb = G.lastVerb,
                          nodeChanged = G._nodeChanged, kills = sim.kills, gloam = sim.gloam })
  if final then push(final) end
  if T.active and T.step ~= before then applyTutSnap() end   -- new step: take them to its tab
end

-- CONTINUE button on a teaching step
local function tutorialContinue()
  if not T.active then return end
  local before = T.step
  local final = T.continue()
  if final then push(final) end
  if T.active and T.step ~= before then applyTutSnap() end
end

-- run a single command (used by both manual entry and the autoplay driver)
local function runCommand(raw)
  if raw:match("^%s*$") then return end
  -- typing a tab's name switches to it (no turn spent)
  local head0 = raw:lower():match("%S+")
  if head0 == "vyrna" then G.overlay = "stats"; G.cmdbuf = ""; return end
  if head0 == "karth" then G.overlay = nil; G.cmdbuf = ""; return end
  if head0 == "rosetta" then G.overlay = "codex"; G.cmdbuf = ""; return end
  push({ kind = "echo", text = raw })
  -- commands never switch the screen; whatever tab you're on, you stay on.
  local before = sim.node
  local foeBefore = sim.foe() ~= nil
  local seth0, thuum0, gloam0 = sim.seth, sim.thuum, sim.gloam
  local verb = canonVerb(raw)
  local entries = sim.command(raw)
  pushAll(entries); trimLog(); G.scroll = 0
  -- a secret whisper, if one surfaced this turn (shown faintly over the map)
  for _, e in ipairs(entries) do
    if e.kind == "whisper" then G.whisper = e.text; G.whisperT = love.timer.getTime() end
  end
  -- sound feedback
  local foeNow = sim.foe() ~= nil
  local harm = (sim.harm or 0) > 0          -- real damage (hazard / foe bite), not the passive bleed
  if not verb then synth.error()                                   -- wrong/unknown command
  elseif foeNow and not foeBefore then synth.boom()               -- stepped next to a foe
  elseif harm then synth.hurt()
  elseif sim.thuum > thuum0 + 4 or sim.seth > seth0 + 4 then synth.replenish()
  else synth.blip() end
  G.lastVerb = verb
  G._nodeChanged = (sim.node ~= before)
  tutorialAdvance()
  if sim.status == "ascended" then
    if not AP.tainted then G.wins = save.addWin(); save.clearGame(); G.hasSave = false end
    synth.boom(); synth.stopDrone(); stopAuto(); G.state = "over"
  elseif sim.status == "dissolved" or sim.status == "devoured" then
    if not AP.tainted then save.clearGame(); G.hasSave = false end
    synth.boom(); synth.stopDrone(); stopAuto(); G.state = "over"
  else
    if not AP.tainted then save.writeGame(sim.snapshot()) end
  end
end

local function submit()
  local raw = G.cmdbuf; G.cmdbuf = ""
  runCommand(raw)
end

-- shared click handling for play tabs (real mouse OR the fake AI cursor)
local function handlePlayClick(id)
  if id == "tab:menu" then toMenu(); return end
  if id == "tab:map" then G.overlay = nil            -- back to the map (the main view)
  elseif id == "tab:stats" then G.overlay = (G.overlay == "stats") and nil or "stats"
  elseif id == "tab:codex" then G.overlay = (G.overlay == "codex") and nil or "codex" end
  tutorialAdvance()
end

local function applyCfg()
  local cfg = save.readCfg()
  UI.cool = (cfg.cool ~= false)   -- colourful by default; only off if explicitly disabled
  Glyph.setScript(cfg.script or "gelenath")
  G.infoSeen = cfg.infoSeen == true
end
local function persistCfg()
  save.writeCfg({ cool = UI.cool, script = Glyph.script, infoSeen = G.infoSeen })
end
local function doReset()
  save.resetAll()
  G.wins = save.getWins()
  G.hasSave = false
  G.resetConfirm = false; G.resetBuf = ""
end

local SCRIPT_BY_INDEX = { "gelenath", "galactic", "english" }
local function handleSettingClick(id)
  if id == "set:reset" then G.resetConfirm = true; G.resetBuf = ""; return end
  local row, idx = id:match("^set:(%a+):(%d+)$")
  idx = tonumber(idx)
  if not row then return end
  if row == "script" then
    if SCRIPT_BY_INDEX[idx] then Glyph.setScript(SCRIPT_BY_INDEX[idx]); persistCfg() end
  elseif row == "ui" then
    UI.cool = (idx == 2); persistCfg()   -- 1 = vyl (boring), 2 = kvol (cool)
  end
end

-- ------------------------------------------------------------ run starts -----
local function newSeed() return love.math.random(1, 2147483000) end

local function freshRun(seed)
  sim.reset(seed or newSeed())
  G.log = {}; G.overlay = nil; G.scroll = 0; G.cmdbuf = ""
  G.intro = false
  AP.tainted = false
  G.state = "play"
  synth.startDrone()
end

local function startNew()
  freshRun()                                   -- random seed each game
  local intro = sim.intro()
  pushAll(intro)
  G.introText = (intro[1] and intro[1].text) or ""
  G.intro = true                               -- show the one-time intro
  save.writeGame(sim.snapshot()); G.hasSave = true
end

local function continueRun()
  local t = save.readGame()
  freshRun(t and t.seed)
  if t then sim.restore(t) end
  pushAll(sim.intro())                          -- resume: no intro screen
end

local function startTutorial()
  freshRun()
  T.start()
  applyTutSnap()
  local intro = sim.intro()
  pushAll(intro)
  G.introText = (intro[1] and intro[1].text) or ""
  G.intro = true
  save.writeGame(sim.snapshot()); G.hasSave = true
end

local function startWatch()
  -- a demo: the rite plays itself. tainted -> never saved, never counted.
  freshRun()
  push({ kind = "sys", text = "{vorae si lar krennax}" })
  pushAll(sim.intro())
  startAuto()
end

-- ----------------------------------------------------------------- love ------
function love.load()
  love.keyboard.setKeyRepeat(true)
  love.math.setRandomSeed(os.time())   -- so each new game gets a fresh map seed
  applyCfg()
  UI.load()
  synth.load()
  -- give the paced autoplay driver its hooks into the UI / IO
  AP.bind({
    hasRegion    = function(id) return UI.getRegion(id) ~= nil end,
    regionCenter = function(id) return UI.regionCenter(id) end,
    getOverlay   = function() return G.overlay end,
    click        = function(id) handlePlayClick(id) end,
    setCmd       = function(s) G.cmdbuf = s end,
    submit       = function(raw) runCommand(raw) end,
  })
  G.wins = save.getWins()
  G.hasSave = save.hasGame()
end

function love.update(dt)
  if dt > 0.1 then dt = 0.1 end
  if G.state == "play" and AP.enabled then AP.update(dt * AP.speed, sim) end
end

function love.draw()
  UI.beginFrame()
  if G.state == "menu" then
    UI.menu({ wins = G.wins, hasSave = G.hasSave, codex = G.menuCodex,
              settings = G.menuSettings, info = G.menuInfo, infoSeen = G.infoSeen, auto = AP.enabled })
  elseif G.state == "play" then
    UI.play(sim, { log = G.log, cmdbuf = G.cmdbuf, scroll = G.scroll, overlay = G.overlay,
                   auto = AP.enabled, autoSpeed = AP.speed, tutorialText = (T.active and T.text()) or nil,
                   tutorialContinue = (T.active and T.needsContinue()) or false,
                   whisper = G.whisper, whisperAge = G.whisperT and (love.timer.getTime() - G.whisperT) or nil })
    G._lines = G._consoleLines or 0
    G._visible = G._consoleVisible or 1
    if G.intro then UI.introScreen(G.introText) end
    if AP.enabled then UI.drawCursor(AP.cur.x, AP.cur.y, AP.pulse) end
  else
    UI.over(sim, { wins = G.wins, ai = AP.tainted })
  end
  if G.resetConfirm then UI.resetModal(G.resetBuf) end   -- modal on top of everything
end

function love.textinput(t)
  if G.resetConfirm then
    if #t == 1 and t:byte(1) >= 32 and t:byte(1) <= 126 and #G.resetBuf < 8 then G.resetBuf = G.resetBuf .. t end
    return
  end
  if G.state ~= "play" or AP.enabled then return end
  if #t == 1 then
    local b = t:byte(1)
    if b >= 32 and b <= 126 and #G.cmdbuf < 40 then G.cmdbuf = G.cmdbuf .. t end
  end
end

function love.keypressed(key)
  if G.resetConfirm then   -- the reset modal captures everything
    if key == "return" or key == "kpenter" then
      if G.resetBuf:upper() == "RESET" then doReset() end
    elseif key == "backspace" then G.resetBuf = G.resetBuf:sub(1, -2)
    elseif key == "escape" then G.resetConfirm = false; G.resetBuf = "" end
    return
  end
  if G.intro then G.intro = false; return end   -- any key dismisses the intro
  if key == "f1" then UI.cool = not UI.cool; persistCfg(); return end
  if key == "f2" then
    if G.state == "play" then if AP.enabled then stopAuto() else startAuto() end end
    return
  end
  if key == "f3" then AP.cycleSpeed(); return end  -- cycle autoplay speed 1x/5x/10x

  if G.state == "play" then
    if AP.enabled then
      if key == "escape" then stopAuto() end   -- easy exit from AI mode
      return
    end
    if key == "return" or key == "kpenter" then submit()
    elseif key == "backspace" then G.cmdbuf = G.cmdbuf:sub(1, -2)
    elseif key == "escape" then if G.overlay then G.overlay = nil else toMenu() end
    elseif key == "up" then G.scroll = math.min(G.scroll + 1, math.max(0, G._lines - G._visible))
    elseif key == "down" then G.scroll = math.max(G.scroll - 1, 0)
    elseif key == "pageup" then G.scroll = math.min(G.scroll + G._visible, math.max(0, G._lines - G._visible))
    elseif key == "pagedown" then G.scroll = math.max(G.scroll - G._visible, 0) end
  elseif G.state == "menu" then
    if key == "escape" then
      if G.menuInfo then G.menuInfo = false
      elseif G.menuCodex then G.menuCodex = false
      elseif G.menuSettings then G.menuSettings = false
      else love.event.quit() end
    end
  elseif G.state == "over" then
    toMenu()
  end
end

function love.wheelmoved(_, y)
  if G.state == "play" and not G.overlay then
    G.scroll = math.max(0, math.min(G.scroll + y, math.max(0, G._lines - G._visible)))
  end
end

function love.mousepressed(mx, my, b)
  if b ~= 1 then return end
  local id = UI.hitTest(mx, my)

  if G.resetConfirm then                 -- modal: any click cancels (confirm is by typing)
    G.resetConfirm = false; G.resetBuf = ""
    return
  end
  if G.intro then G.intro = false; return end   -- click dismisses the intro

  if G.state == "menu" then
    if G.menuInfo then G.menuInfo = false; return end
    if G.menuCodex then G.menuCodex = false; return end
    if G.menuSettings then
      if id and id:match("^set:") then handleSettingClick(id)   -- toggle a setting / open reset
      elseif id == "setpanel" then                              -- inside panel: keep open
      else G.menuSettings = false end                           -- clicked out: close
      return
    end
    if id == "begin" or id == "newgame" then startNew()
    elseif id == "continue" then continueRun()
    elseif id == "tutorial" then startTutorial()
    elseif id == "watch" then startWatch()
    elseif id == "settings" then G.menuSettings = true
    elseif id == "codex" then G.menuCodex = true
    elseif id == "info" then G.menuInfo = true; if not G.infoSeen then G.infoSeen = true; persistCfg() end
    elseif id == "quit" then love.event.quit() end
    return
  end

  if G.state == "play" then
    if not id then return end
    if id == "tutcontinue" then tutorialContinue()           -- advance a teaching step
    elseif id == "speedtoggle" then AP.cycleSpeed()          -- click the vorae chip to cycle 1x/5x/10x
    elseif id:match("^tab:") then handlePlayClick(id)
    elseif id:match("^set:") then handleSettingClick(id) end
    return
  end

  if G.state == "over" then toMenu() end
end
