-- Vertical Billiard: rolling-ball textures.
-- Each ball is painted as an equirectangular "skin" (64x32: longitude across,
-- latitude down) that the ball shader wraps around a sphere and rotates, so
-- the numbers, stripes and the cue ball's dots visibly roll.
-- Atlas: 4x5 cells -> 256x160. Cell 0 = player cue ball, cells 1..15 = numbers,
-- cell 16 = the plain white ball pushed around in Hardcore mode.
--   aseprite -b --script-param root=<project> --script tools/art_balls.lua
local A = dofile(app.params["root"] .. "/tools/art_lib.lua")

local CW, CH = 64, 32
local c = A.canvas(CW * 4, CH * 5)

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

local function paint_ball(cell, num)
  local ox, oy = (cell % 4) * CW, math.floor(cell / 4) * CH
  for y = 0, CH - 1 do
    for x = 0, CW - 1 do
      local dx, dy, dz = dir_of((x + 0.5) / CW, (y + 0.5) / CH)
      local col
      if num == 16 then
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

for n = 0, 16 do paint_ball(n, n) end
c:save("balls")
print("Ball skins exported.")
