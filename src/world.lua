-- world.lua :: the blind realm. SEEDED + RANDOMISED each game.
-- Several FULL-SIZE sections, each a 4x4 lattice, chained one after another by
-- GATES. A gate is found only by inspecting (`seth`) the place it sits, then you
-- pass through it with the eldritch direction `klor` into the next section, which
-- bears a different name. The three sigil-shrines and the heart lie in the final,
-- deepest section. Nothing about the layout is fixed — every run has a seed.

local W = {}

W.dirVec  = { vor = { 0, -1 }, neth = { 0, 1 }, qor = { 1, 0 }, zah = { -1, 0 } }
W.dirOrder = { "vor", "neth", "qor", "zah" }       -- grid directions
W.allDirs  = { "vor", "neth", "qor", "zah", "klor" } -- + the through-gate direction
W.secW, W.secH = 4, 4
W.SECTIONS = 5

local SEC = {
  { name = "vael'thuun",   prefix = "vael" },
  { name = "korreth'warr", prefix = "korr" },
  { name = "ygnath'reach", prefix = "ygna" },
  { name = "mol'grave",    prefix = "mol" },
  { name = "si'lar'deep",  prefix = "silar" },
}
local GATEGUARD = { "vorthak", "qhulra", "ssgrael", "drennan" }
local SUFF = { "hollow","span","sink","spire","choir","seam","mire","vault",
               "fold","reach","gulf","maw","well","warren","fane","deep" }

local function descFor(typ, name, secname)
  if typ == "start" then
    return "You stir at the {" .. name .. "}, the threshold of waking. Cold {ichor} laps at your folded limbs. You are {bul'narth}, sent to climb."
  elseif typ == "entry" then
    return "You cross into {" .. secname .. "}. The dark is new here; the way behind has sealed."
  elseif typ == "gate" then
    return "The air at the {" .. name .. "} is {scarred} — a shut {gate} presses here, a way that leads onward."
  elseif typ == "hazard" then
    return "The {" .. name .. "} clings, wet and fond. To linger is to rot — {gloam} seeps in."
  elseif typ == "font" then
    return "A {" .. name .. "} wells up, bright {essence} steaming. Drink, and be filled."
  elseif typ == "shrine_za" then
    return "A {morr'sigil} hangs unlit at the {" .. name .. "}, starving for the rite. Its keeper coils to meet you."
  elseif typ == "shrine_qor" then
    return "The {qhel'sigil} coils dim at the {" .. name .. "}, awaiting {vorth}. Its keeper uncoils."
  elseif typ == "shrine_neth" then
    return "The {zyth'sigil} burns black and dormant at the {" .. name .. "}. Its keeper bars the rite."
  elseif typ == "heart" then
    return "You stand upon the {heart of si'lar}. With the three sigils lit and the {warden} folded, the {Word} may be uttered."
  end
  return "The {" .. name .. "}: still, listening. Something marks your passing."
end

function W.build(seed)
  seed = seed or 1
  W.sectionNames = {}
  local nodes, startId = {}, nil
  local gateCell = {}

  for si, sd in ipairs(SEC) do
    W.sectionNames[si] = sd.name
    local rng = love.math.newRandomGenerator(seed * 131 + si * 7 + 3)
    -- all cells except the entry (0,0), shuffled
    local cells = {}
    for x = 0, W.secW - 1 do for y = 0, W.secH - 1 do
      if not (x == 0 and y == 0) then cells[#cells + 1] = { x, y } end
    end end
    for i = #cells, 2, -1 do local j = rng:random(1, i); cells[i], cells[j] = cells[j], cells[i] end

    local final = (si == #SEC)
    local typeAt = {}
    typeAt["0,0"] = (si == 1) and "start" or "entry"
    local function take() local c = table.remove(cells, 1); return c[1] .. "," .. c[2], c end
    -- the forward gate must NOT sit adjacent to the entry (0,0), so the two gate
    -- tiles of a section (entry back-gate + forward gate) never touch.
    local function takeGate()
      for i = 1, #cells do
        if cells[i][1] + cells[i][2] ~= 1 then  -- (1,0)/(0,1) are the entry's neighbours
          local c = table.remove(cells, i); return c[1] .. "," .. c[2], c
        end
      end
      return take()
    end
    -- one sigil-shrine in sections 1, 3 and 5
    local shrineType = ({ [1] = "shrine_za", [3] = "shrine_qor", [5] = "shrine_neth" })[si]
    if shrineType then local kk = take(); typeAt[kk] = shrineType end
    if not final then local kk, c = takeGate(); typeAt[kk] = "gate"; gateCell[si] = c end
    if final then local kk = take(); typeAt[kk] = "heart" end
    local kk = take(); typeAt[kk] = "font"
    kk = take(); typeAt[kk] = "hazard"
    kk = take(); typeAt[kk] = "hazard"

    for x = 0, W.secW - 1 do for y = 0, W.secH - 1 do
      local key = x .. "," .. y
      local typ = typeAt[key] or "normal"
      local id = "s" .. si .. "_" .. x .. "_" .. y
      local name = sd.prefix .. "'" .. SUFF[((x * W.secH + y) % #SUFF) + 1]
      if typ == "shrine_za" then name = "morr'shrine"
      elseif typ == "shrine_qor" then name = "qhel'shrine"
      elseif typ == "shrine_neth" then name = "zyth'shrine"
      elseif typ == "heart" then name = "si'lar" end
      local n = {
        id = id, sec = si, lx = x, ly = y, name = name,
        type = (typ == "entry") and "normal" or typ,
        desc = descFor(typ, name, sd.name),
        guardian = nil, gatehere = nil,
        visited = false, exits = {}, gated = {},
      }
      nodes[id] = n
      if typ == "start" then startId = id end
    end end
  end

  -- intra-section adjacency
  for _, n in pairs(nodes) do
    for _, dir in ipairs(W.dirOrder) do
      local v = W.dirVec[dir]
      local toid = "s" .. n.sec .. "_" .. (n.lx + v[1]) .. "_" .. (n.ly + v[2])
      if nodes[toid] then n.exits[dir] = toid end
    end
  end

  -- gate links (klor), two-way; both ends inspectable
  for si = 1, #SEC - 1 do
    local gc = gateCell[si]
    local gnode = nodes["s" .. si .. "_" .. gc[1] .. "_" .. gc[2]]
    local entry = nodes["s" .. (si + 1) .. "_0_0"]
    local gid = "gate" .. si
    gnode.exits.klor = entry.id; gnode.gated.klor = gid; gnode.gatehere = gid
    entry.exits.klor = gnode.id; entry.gated.klor = gid; entry.gatehere = gid
  end

  -- FOES: every important structure is RINGED by entities on its plain neighbours;
  -- deeper sections also hold a few wanderers on random tiles. (tiles stay clear
  -- so they can be entered once the entity guarding the approach is unmade.)
  local function plain(n)  -- a tile a foe may stand on
    return n and n.type == "normal" and not n.guardian and not (n.lx == 0 and n.ly == 0)
  end
  local function ring(n, tmpl, bossTmpl)
    local first = true
    for _, dir in ipairs(W.dirOrder) do
      local nb = nodes[n.exits[dir]]
      if plain(nb) then
        if bossTmpl and first then nb.guardian = bossTmpl; first = false else nb.guardian = tmpl end
      end
    end
  end
  for _, n in pairs(nodes) do
    if n.type == "gate" then ring(n, GATEGUARD[n.sec])
    elseif n.type == "shrine_za" then ring(n, "vaelorn")
    elseif n.type == "shrine_qor" then ring(n, "qethrave")
    elseif n.type == "shrine_neth" then ring(n, "nethulu")
    elseif n.type == "heart" then ring(n, "vorm", "larth") end  -- one neighbour is the boss
  end
  -- wanderers in the deeper sections
  local rng = love.math.newRandomGenerator(seed * 977 + 13)
  for _, n in pairs(nodes) do
    if n.sec >= 3 and plain(n) and rng:random() < 0.16 then
      n.guardian = (rng:random() < 0.5) and "ghael" or "vorm"
    end
  end

  return nodes, startId
end

return W
