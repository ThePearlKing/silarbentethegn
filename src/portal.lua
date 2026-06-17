-- portal.lua :: integration with games.brassey.io (love.js web runtime).
-- The runtime intercepts print() lines with magic prefixes and forwards them to the
-- host page (achievement unlocks, screen FX). We ONLY emit when actually embedded —
-- the portal pre-creates a "__loveweb__" dir in the save folder before love.load —
-- so on desktop and in headless tests this is completely silent.

local P = { enabled = false, done = {}, unlocked = {}, handle = nil, signedIn = false }

function P.init()
  local info = love.filesystem.getInfo and love.filesystem.getInfo("__loveweb__")
  P.enabled = info ~= nil
  -- read player identity (pre-written by the portal). tiny flat JSON -> patterns.
  local ok, raw = pcall(love.filesystem.read, "__loveweb__/identity.json")
  if ok and raw then
    P.signedIn = raw:match('"signedIn"%s*:%s*true') ~= nil
    P.handle = raw:match('"handle"%s*:%s*"([^"]*)"')
  end
  P.refresh()
end

-- read which achievements the portal says are already unlocked (across sessions)
function P.refresh()
  local ok, raw = pcall(love.filesystem.read, "__loveweb__/achievements.json")
  if ok and raw then
    for key in raw:gmatch('"key"%s*:%s*"([^"]*)"') do P.unlocked[key] = true end
  end
end

function P.isUnlocked(key) return P.unlocked[key] == true or P.done[key] == true end

-- unlock an achievement (once per session; the portal dedupes across sessions)
function P.unlock(key)
  if P.done[key] then return end
  P.done[key] = true
  if P.enabled then print("[[LOVEWEB_ACH]]unlock " .. key) end
end

return P
