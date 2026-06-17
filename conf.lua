-- Complicated Game :: si'larbentethegn
function love.conf(t)
  t.identity = "complicated_game"
  t.version  = "11.5"
  t.window.title = "si'larbentethegn"
  t.window.width = 1280       -- design resolution; the game letterboxes to any size
  t.window.height = 800
  t.window.minwidth = 640
  t.window.minheight = 400
  t.window.resizable = true
  t.window.highdpi = true
  t.window.vsync = 1
  t.console = false
  -- modules we don't need (thread/video unsupported on the web runtime)
  t.modules.physics = false
  t.modules.video = false
  t.modules.joystick = false
  t.modules.thread = false
end
