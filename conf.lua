-- Complicated Game :: si'larbentethegn
function love.conf(t)
  t.identity = "complicated_game"
  t.window.title = "si'larbentethegn"
  t.window.width = 1280
  t.window.height = 800
  t.window.minwidth = 980
  t.window.minheight = 640
  t.window.resizable = true
  t.window.vsync = 1
  t.console = false
  -- modules we don't need
  t.modules.physics = false
  t.modules.video = false
  t.modules.joystick = false
end
