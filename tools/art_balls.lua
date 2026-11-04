-- Vertical Billiard: rolling-ball textures.
-- Each ball is painted as an equirectangular "skin" (64x32: longitude across,
-- latitude down) that the ball shader wraps around a sphere and rotates, so
-- the numbers, stripes and the cue ball's dots visibly roll.
-- Atlas: 4x7 cells -> 256x224. Cell 0 = player cue ball, cells 1..15 = numbers,
-- cell 16 = the plain white ball pushed around in Hardcore mode, cells 17..26 =
-- level 2's lost balls, cell 27 = the rainbow ball (greyscale here: the shader colours it).
--   aseprite -b --script-param root=<project> --script tools/art_balls.lua
local A = dofile(app.params["root"] .. "/tools/art_lib.lua")

local CW, CH = 64, 32
local c = A.canvas(CW * 4, CH * 7)

local IVORY = "f4eedc"
local INK = "1c1a1f"
local COLORS = {
  [1] = "f0b92c", [2] = "2f56c4", [3] = "d23a2c", [4] = "6d3aa0",
  [5] = "ea7428", [6] = "26874a", [7] = "8e2b2b", [8] = "1d1c22",
}

-- 3x5 digit glyphs.
local DIGITS = {
  ["0"] = { "###", "#.#", "#.#", "#.#", "###" },
  ["1"] = { ".#.", "##.", ".#.", ".#.", "###" },
  ["2"] = { "##.", "..#", ".#.", "#..", "###" },
  ["3"] = { "##.", "..#", ".#.", "..#", "##." },
  ["4"] = { "#.#", "#.#", "###", "..#", "..#" },
  ["5"] = { "###", "#..", "##.", "..#", "##." },
  ["6"] = { ".##", "#..", "###", "#.#", "###" },
  ["7"] = { "###", "..#", ".#.", ".#.", ".#." },
  ["8"] = { "###", "#.#", "###", "#.#", "###" },
  ["9"] = { "###", "#.#", "###", "..#", "##." },
}

local function dir_of(u, v)
  local lon = (u - 0.5) * 2 * math.pi
  local theta = v * math.pi
  return math.sin(theta) * math.sin(lon), math.cos(theta), math.sin(theta) * math.cos(lon)
end

-- Is the gnomonic point (tx, ty) on the cap facing +z inside the number glyphs?
local GLYPH = 0.13 -- tangent-plane size of one glyph pixel
local function glyph_hit(num, tx, ty)
  local s = tostring(num)
  local width = #s * 3 + (#s - 1)
  local gx = math.floor(tx / GLYPH + width / 2)
  local gy = math.floor(-ty / GLYPH + 2.5)
  if gy < 0 or gy > 4 or gx < 0 or gx >= width then return false end
  local idx = math.floor(gx / 4) + 1
  local col = gx % 4
  if col == 3 then return false end
  local rows = DIGITS[s:sub(idx, idx)]
  return rows[gy + 1]:sub(col + 1, col + 1) == "#"
end

-- Level 2's lost balls and the rainbow ball, each a pattern on the sphere.
local CRATERS = { { 0.7, 0.3, 0.64, 0.16 }, { -0.5, 0.6, 0.62, 0.2 }, { 0.2, -0.7, 0.68, 0.14 }, { -0.8, -0.2, 0.56, 0.18 },
  { 0.1, 0.2, -0.97, 0.2 }, { -0.4, -0.6, -0.69, 0.15 }, { 0.8, -0.3, -0.52, 0.17 }, { 0.3, 0.8, -0.52, 0.13 } }
local function special_skin(num, dx, dy, dz, x, y)
  local lon = math.atan(dx, dz)
  if num == 17 then -- Chalk: blue with dust
    return A.hash(x, y, 171) > 0.82 and "c8e4ff" or "3f86d8"
  elseif num == 18 then -- Neon: dark tubes of pink and cyan
    if math.abs(dy) < 0.06 then return "6af0ff" end
    if math.abs(math.sin(dy * 9.0)) < 0.2 then return "ff5fa2" end
    return "241238"
  elseif num == 19 then -- Checker
    local a = math.floor((lon + math.pi) / (math.pi / 4))
    local b = math.floor((math.asin(dy) + math.pi / 2) / (math.pi / 6))
    return (a + b) % 2 == 0 and "17161b" or "f4eedc"
  elseif num == 20 then -- Tournament: felt green with a gold band
    if math.abs(dy) < 0.14 then return math.abs(dy) < 0.05 and "fff0a8" or "f2c440" end
    return "1f7a48"
  elseif num == 21 then -- Marble: ivory with grey veins
    local v = math.sin(8.0 * (dx + dy * 0.5) + 3.0 * math.sin(6.0 * dz))
    if math.abs(v) < 0.09 then return "7a7468" end
    if math.abs(v) < 0.2 then return "b4ae9e" end
    return "ece6d6"
  elseif num == 22 then -- Ember: a red and orange swirl
    local t = math.sin(10.0 * dy + 5.0 * lon)
    if t > 0.75 then return "ffd24a" end
    return t > 0 and "e8501c" or "6e120e"
  elseif num == 23 then -- Ocean: rolling wave bands
    local t = math.sin(12.0 * dy + 2.0 * math.sin(6.0 * lon))
    if t > 0.85 then return "d8f4ff" end
    return t > 0 and "2f8ad0" or "174a90"
  elseif num == 24 then -- Night: navy and stars
    return A.hash(x, y, 241) > 0.9 and "fff6d8" or "141a40"
  elseif num == 25 then -- Gold: polished, with rivets
    if math.abs(math.sin(4.0 * (lon + dy * 2.0))) < 0.16 then return "fff0a8" end
    return A.hash(math.floor(x / 4), math.floor(y / 4), 251) > 0.88 and "a87818" or "e8b830"
  elseif num == 26 then -- Moon: grey with craters
    for _, k in ipairs(CRATERS) do
      local d = dx * k[1] + dy * k[2] + dz * k[3]
      local r = math.cos(k[4])
      if d > r then return d > r + (1 - r) * 0.35 and "7c786e" or "e4e0d4" end
    end
    return "b4b0a4"
  else -- Rainbow: pale, with soft bands and star marks the shader tints
    for _, a in ipairs({ { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }) do
      if dx * a[1] + dy * a[2] + dz * a[3] > 0.96 then return "ffffff" end
    end
    return math.abs(math.sin(lon * 3.0)) < 0.12 and "c8c8c8" or "ececec"
  end
end

local function paint_ball(cell, num)
  local ox, oy = (cell % 4) * CW, math.floor(cell / 4) * CH
  for y = 0, CH - 1 do
    for x = 0, CW - 1 do
      local dx, dy, dz = dir_of((x + 0.5) / CW, (y + 0.5) / CH)
      local col
      if num >= 17 then
        col = special_skin(num, dx, dy, dz, x, y)
      elseif num == 16 then
        -- Hardcore white ball: plain ivory, two faint grey great circles so it still reads as rolling.
        col = "f8f6f0"
        if math.abs(dy) < 0.05 or math.abs(dx) < 0.05 then col = "c8c4bc" end
      elseif num == 0 then
        -- Cue ball: ivory with six red "measles" dots on the axes, so any
        -- rotation reads instantly.
        col = IVORY
        for _, a in ipairs({ { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }) do
          local d = dx * a[1] + dy * a[2] + dz * a[3]
          if d > 0.955 then col = "c8302e" elseif d > 0.935 then col = "e6c8b4" end
        end
        -- Faint seam ring like a real resin ball, gives extra roll cues.
        if math.abs(dy) < 0.035 then col = "e2dac6" end
      else
        local base = COLORS[num <= 8 and num or num - 8]
        col = base
        if num > 8 and math.abs(dy) > 0.5 then col = IVORY end
        -- Number disc on both faces (+z and -z).
        for _, face in ipairs({ 1, -1 }) do
          local fz = dz * face
          if fz > 0.84 then
            col = IVORY
            local tx, ty = dx * face / fz, dy / fz
            if glyph_hit(num, tx, ty) then col = INK end
          end
        end
      end
      c:px(ox + x, oy + y, col)
    end
  end
end

for n = 0, 27 do paint_ball(n, n) end
c:save("balls")
print("Ball skins exported.")
