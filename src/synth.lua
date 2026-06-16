-- synth.lua :: procedural eldritch ambience. Fully guarded: if anything about
-- audio fails, the game runs on in silence.

local Synth = { ok = false }

local function clampf(x) if x > 1 then return 1 elseif x < -1 then return -1 else return x end end

-- build a mono SoundData of `dur` seconds from fn(t, p) -> [-1,1]
local function tone(dur, fn)
  local rate = 44100
  local n = math.floor(dur * rate)
  local sd = love.sound.newSoundData(n, rate, 16, 1)
  for i = 0, n - 1 do
    sd:setSample(i, clampf(fn(i / rate, i / n)))
  end
  return sd
end

function Synth.load()
  if not love.sound or not love.audio then return end
  local ok = pcall(function()
    -- low drone, seamless loop (integer cycle counts over the 4s buffer)
    local dur = 4
    local droneSD = tone(dur, function(t, p)
      -- frequencies expressed as integer cycle-counts / dur for a seamless loop
      local v = 0.20 * math.sin(2 * math.pi * (160 / dur) * t)  -- 40 hz
            + 0.12 * math.sin(2 * math.pi * (161 / dur) * t)    -- 40.25 hz (slow beat)
            + 0.08 * math.sin(2 * math.pi * (240 / dur) * t)    -- 60 hz
      local trem = 0.85 + 0.15 * math.sin(2 * math.pi * p)      -- one slow swell per loop
      return v * trem * 0.6
    end)
    Synth.drone = love.audio.newSource(droneSD, "static")
    Synth.drone:setLooping(true)
    Synth.drone:setVolume(0.35)

    -- a soft "blip" for accepted commands
    Synth.blipSD = tone(0.08, function(t)
      local env = math.exp(-t * 40)
      return math.sin(2 * math.pi * 320 * t) * env * 0.4
    end)
    -- a low boom for harm / death / strike
    Synth.boomSD = tone(0.55, function(t)
      local env = math.exp(-t * 7)
      return (math.sin(2 * math.pi * 70 * t) + 0.4 * math.sin(2 * math.pi * 47 * t)) * env * 0.5
    end)
    -- a soft rising chime when something is replenished (essence, grip…)
    Synth.replenishSD = tone(0.22, function(t)
      local env = math.exp(-t * 6)
      local f = 440 + 260 * (t / 0.22)
      return math.sin(2 * math.pi * f * t) * env * 0.30
    end)
    -- a short low buzz when something drains (grip down, corruption up)
    Synth.hurtSD = tone(0.16, function(t)
      local env = math.exp(-t * 9)
      local f = 210 - 90 * (t / 0.16)
      return (math.sin(2 * math.pi * f * t) + 0.3 * math.sin(2 * math.pi * f * 2.01 * t)) * env * 0.34
    end)
    -- a harsh dissonant beat for a wrong / unknown command
    Synth.errorSD = tone(0.22, function(t)
      local env = math.exp(-t * 7)
      return (math.sin(2 * math.pi * 150 * t) + math.sin(2 * math.pi * 159 * t)) * env * 0.30
    end)
  end)
  Synth.ok = ok == true
end

local function play(sd, vol)
  if not Synth.ok or not sd then return end
  pcall(function()
    local s = love.audio.newSource(sd, "static")
    s:setVolume(vol or 0.6)
    s:play()
  end)
end

function Synth.startDrone() end  -- drone disabled (the background "rumbling")
function Synth.stopDrone() if Synth.ok and Synth.drone then pcall(function() Synth.drone:stop() end) end end
function Synth.blip() play(Synth.blipSD, 0.30) end
function Synth.boom() play(Synth.boomSD, 0.6) end
function Synth.replenish() play(Synth.replenishSD, 0.4) end
function Synth.hurt() play(Synth.hurtSD, 0.45) end
function Synth.error() play(Synth.errorSD, 0.45) end

return Synth
