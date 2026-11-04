-- Vertical Billiard: terrain tiles (16x16), three zones.
-- Atlas 256x144. For zone z (0 Back Room, 1 Neon Bar, 2 Royal Club):
--   row 3z   : table block, 16 autotile variants (col = exposure mask)
--   row 3z+1 : rubber cushion block, 16 autotile variants
--   row 3z+2 : col 0 slope rising right, col 1 slope rising left,
--              col 2/3 the same slopes in cushion rubber
-- Exposure mask bits: 1 top open, 2 right open, 4 bottom open, 8 left open.
--   aseprite -b --script-param root=<project> --script tools/art_tiles.lua
local A = dofile(app.params["root"] .. "/tools/art_lib.lua")

local T = 16
local c = A.canvas(T * 16, T * 9)

local ZONES = {
  { -- Back Room: green felt, walnut rails, plank cabinet
    felt = { "17402a", "22603c", "2f7c4c", "4a9c5e", "74c07a" },
    rail = { "2a160e", "4a2a18", "6a4024", "8c5a32" },
    body = { "24140e", "331e14", "42281a", "4e3020" },
    shadow = "120a07",
    cush = { "0f2a1c", "1a422c", "27603e", "3c8456", "5aa870" },
    stud = { "b08a3c", "f2e6c4" },
    pattern = "planks",
  },
  { -- Neon Bar: wine felt, black lacquer, purple cabinet
    felt = { "3e0f20", "5e1a30", "822840", "a83a52", "d4607a" },
    rail = { "17121c", "282032", "3a2e48", "54466a" },
    body = { "15111c", "1d1726", "251e31", "2e263c" },
    shadow = "0a080e",
    cush = { "0b2c30", "12464a", "1b6668", "2b8e8a", "4cbcb2" },
    stud = { "d0d6e0", "ffffff" },
    pattern = "lacquer",
  },
  { -- Royal Club: royal-blue fast felt, gilded rails, ivory marble
    felt = { "102c62", "1a448e", "2660b8", "3c80e0", "72aaf8" },
    rail = { "5e4214", "8c6820", "b88e30", "e2c062" },
    body = { "8e8794", "b0aab0", "cdc7c4", "e2ddd4" },
    shadow = "2e2a3a",
    cush = { "3a0a16", "5a1222", "801c30", "a82c42", "d24e60" },
    stud = { "c9a040", "fff0b0" },
    pattern = "marble",
  },
}

local function body_color(z, x, y)
  local p = ZONES[z].body
  local pat = ZONES[z].pattern
  if pat == "planks" then
    -- Vertical walnut planks with grain streaks and a dark seam.
    if x % 8 == 7 then return p[1] end
    local g = A.hash(x, math.floor(y / 3), 11)
    if g < 0.18 then return p[2] elseif g > 0.86 then return p[4] end
    if x % 8 == 0 then return p[4] end
    return p[3]
  elseif pat == "lacquer" then
    -- Deep lacquer with slim vertical inlay lines and a soft sheen band.
    if x % 8 == 3 then return p[3] end
    if (y + x // 2) % 16 == 0 and A.hash(x, y, 4) > 0.5 then return p[4] end
    return A.hash(x, y, 9) > 0.9 and p[1] or p[2]
  else
    -- Ivory marble: periodic veins so tiles join seamlessly.
    local v = math.sin(2 * math.pi * (x + y) / 16 + 1.1 * math.sin(2 * math.pi * y / 16))
    if math.abs(v) < 0.12 then return p[1] end
    if math.abs(v) < 0.3 then return p[2] end
    return A.hash(x, y, 21) > 0.82 and p[3] or p[4]
  end
end

local function draw_table(z, ox, oy, mask)
  local Z = ZONES[z]
  local top, right, bottom, left = mask & 1 ~= 0, mask & 2 ~= 0, mask & 4 ~= 0, mask & 8 ~= 0
  for y = 0, T - 1 do
    for x = 0, T - 1 do
      c:px(ox + x, oy + y, body_color(z, x, y))
    end
  end
  if left then
    c:vline(ox, oy, oy + T - 1, Z.rail[1]); c:vline(ox + 1, oy, oy + T - 1, Z.rail[4]); c:vline(ox + 2, oy, oy + T - 1, Z.rail[3])
  end
  if right then
    c:vline(ox + T - 1, oy, oy + T - 1, Z.shadow); c:vline(ox + T - 2, oy, oy + T - 1, Z.rail[2]); c:vline(ox + T - 3, oy, oy + T - 1, Z.rail[3])
  end
  if bottom then
    c:hline(ox, ox + T - 1, oy + T - 1, Z.shadow); c:hline(ox, ox + T - 1, oy + T - 2, Z.rail[1]); c:hline(ox, ox + T - 1, oy + T - 3, Z.rail[2])
    if left then c:px(ox, oy + T - 1, "00000000", 0) end
    if right then c:px(ox + T - 1, oy + T - 1, "00000000", 0) end
  end
  if top then
    -- Felt surface with a cushion lip, like the playing edge of a table.
    local rows = { Z.felt[5], Z.felt[4], Z.felt[3], Z.felt[3], Z.felt[2], Z.felt[1], Z.rail[4], Z.rail[2] }
    for i, col in ipairs(rows) do
      for x = 0, T - 1 do
        local cc = col
        if i == 4 and (x + oy) % 2 == 0 then cc = Z.felt[2] end
        c:px(ox + x, oy + i - 1, cc)
      end
    end
    -- Felt drapes over open sides.
    if left then
      c:px(ox, oy, "00000000", 0)
      for y = 1, 6 do c:px(ox, oy + y, Z.felt[1]); c:px(ox + 1, oy + y, y < 3 and Z.felt[4] or Z.felt[2]) end
    end
    if right then
      c:px(ox + T - 1, oy, "00000000", 0)
      for y = 1, 6 do c:px(ox + T - 1, oy + y, Z.felt[1]); c:px(ox + T - 2, oy + y, Z.felt[2]) end
    end
    -- Mother-of-pearl sight on the rail.
    c:px(ox + 7, oy + 6, Z.stud[2]); c:px(ox + 8, oy + 6, Z.stud[1])
  end
end

local function draw_cushion(z, ox, oy, mask)
  local P = ZONES[z].cush
  local S = ZONES[z].stud
  local top, right, bottom, left = mask & 1 ~= 0, mask & 2 ~= 0, mask & 4 ~= 0, mask & 8 ~= 0
  for y = 0, T - 1 do
    for x = 0, T - 1 do
      -- Rubber with a pillowy bulge: lighter toward open top/left edges.
      local t = 0.45
      if top then t = t + math.max(0, (5 - y) / 10) end
      if left then t = t + math.max(0, (5 - x) / 14) end
      if bottom then t = t - math.max(0, (y - 10) / 12) end
      if right then t = t - math.max(0, (x - 10) / 14) end
      c:px(ox + x, oy + y, A.ramp(P, t, x, y))
    end
  end
  if top then c:hline(ox + 1, ox + T - 2, oy, P[5]) end
  if left then c:vline(ox, oy + 1, oy + T - 2, P[4]) end
  if bottom then c:hline(ox, ox + T - 1, oy + T - 1, P[1]) end
  if right then c:vline(ox + T - 1, oy, oy + T - 1, P[1]) end
  if top and left then c:px(ox, oy, "00000000", 0) end
  if top and right then c:px(ox + T - 1, oy, "00000000", 0) end
  if bottom and left then c:px(ox, oy + T - 1, "00000000", 0) end
  if bottom and right then c:px(ox + T - 1, oy + T - 1, "00000000", 0) end
  -- Brass stud with pearl glint.
  c:rect(ox + 7, oy + 7, 2, 2, S[1]); c:px(ox + 7, oy + 7, S[2])
  c:px(ox + 6, oy + 8, P[1]); c:px(ox + 9, oy + 8, P[1])
end

-- Slope: solid below the diagonal. rising_right: surface from (0,16) to (16,0).
local function draw_slope(z, ox, oy, rising_right, cushion)
  local Z = ZONES[z]
  for y = 0, T - 1 do
    for x = 0, T - 1 do
      local sx = rising_right and x or (T - 1 - x)
      local depth = (sx + y) - (T - 1) -- 0 on the surface diagonal, grows inward
      if depth >= 0 then
        local col
        if cushion then
          col = depth == 0 and Z.cush[5] or (depth < 3 and Z.cush[4] or A.ramp(Z.cush, 0.45 - depth / 40, x, y))
        else
          local felt = { Z.felt[5], Z.felt[4], Z.felt[3], Z.felt[2], Z.felt[1], Z.rail[4], Z.rail[2] }
          col = felt[depth + 1] or body_color(z, x, y)
        end
        c:px(ox + x, oy + y, col)
      end
    end
  end
end

for z = 1, 3 do
  local row = (z - 1) * 3
  for mask = 0, 15 do
    draw_table(z, mask * T, row * T, mask)
    draw_cushion(z, mask * T, (row + 1) * T, mask)
  end
  draw_slope(z, 0, (row + 2) * T, true, false)
  draw_slope(z, T, (row + 2) * T, false, false)
  draw_slope(z, 2 * T, (row + 2) * T, true, true)
  draw_slope(z, 3 * T, (row + 2) * T, false, true)
end

c:save("tiles")
print("Tiles exported.")
