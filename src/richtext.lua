-- richtext.lua
-- Mixed English + Gelenath line layout.
-- Markup: text in {braces} is rendered as Gelenath runes; everything else is
-- normal english font. This produces the "half english, half gelenath" prose:
--    "You wake at the {vael'thuun}. {ichor} laps at your limbs."
-- nouns become unreadable runes until you learn the script.

local Glyph = require("src.glyph")
local R = {}

local function parse(str)
  local items, mode, buf = {}, "e", ""
  local function flush()
    for word in buf:gmatch("%S+") do
      items[#items + 1] = { t = mode, word = word }
    end
    buf = ""
  end
  for i = 1, #str do
    local c = str:sub(i, i)
    if c == "{" then flush(); mode = "g"
    elseif c == "}" then flush(); mode = "e"
    else buf = buf .. c end
  end
  flush()
  return items
end

-- wrap into lines that fit maxw. font = love Font, gs = glyph size.
function R.layout(str, font, gs, maxw)
  local items = parse(str)
  local space = font:getWidth(" ")
  local lines, cur, curw = {}, {}, 0
  for _, it in ipairs(items) do
    local w = (it.t == "g") and Glyph.width(it.word, gs) or font:getWidth(it.word)
    local add = (#cur > 0 and space or 0) + w
    if curw + add > maxw and #cur > 0 then
      lines[#lines + 1] = cur
      cur, curw, add = {}, 0, w
    end
    it.w = w
    cur[#cur + 1] = it
    curw = curw + add
  end
  if #cur > 0 then lines[#lines + 1] = cur end
  if #lines == 0 then lines[1] = {} end
  return lines
end

-- draw pre-laid lines. colE/colG are {r,g,b,a}. returns final y.
function R.draw(lines, x, y, font, gs, lineH, colE, colG)
  local space = font:getWidth(" ")
  local goff = (font:getHeight() - gs) * 0.5
  for _, line in ipairs(lines) do
    local cx = x
    for j, it in ipairs(line) do
      if j > 1 then cx = cx + space end
      if it.t == "g" then
        love.graphics.setColor(colG)
        Glyph.drawText(it.word, cx, y + goff, gs)
      else
        love.graphics.setColor(colE)
        love.graphics.print(it.word, cx, y)
      end
      cx = cx + it.w
    end
    y = y + lineH
  end
  return y
end

return R
