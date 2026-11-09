-- Vertical Billiard: art for the zones that replaced borrowed Back Room / Neon /
-- Royal pieces in levels 3 and 4.
--   Backdrops (512x288): bg_observatory  bg_station  bg_fire_escape  bg_bell_tower
--   Props: lantern  bell  star_chart  porthole  flower_pot  telescope (2 frames: mount, tube)
--          orrery  console (2 frames: lights on / swapped)  gear  spark_blue (3 frames)
--   aseprite -b --script-param root=<project> --script tools/art_themes.lua
local A = dofile(app.params["root"] .. "/tools/art_lib.lua")
local W, H = 512, 288
local OUT = "11090c"

local function stars(c, count, seed, x0, y0, w, h, inside)
  for i = 0, count do
    local x = x0 + math.floor(A.hash(i, 1, seed) * w)
    local y = y0 + math.floor(A.hash(i, 2, seed) * h)
    if not inside or inside(x, y) then
      local b = A.hash(i, 3, seed)
      c:px(x, y, b > 0.85 and "fff6d8" or (b > 0.5 and "a8a8d0" or "5a5a88"))
    end
  end
end

-- Observatory: inside a dome. Brass ribs curve up, the shutter slit shows stars,
-- a faint star chart is painted between the ribs.
do
  local c = A.canvas(W, H)
  local wall = { "0c0c22", "121230", "18183e", "20204c" }
  for y = 0, H - 1 do for x = 0, W - 1 do
    local glow = 1 - math.abs(x - 256) / 300
    c:px(x, y, A.ramp(wall, 0.25 + glow * 0.45, x, y))
  end end
  -- Shutter slit down the middle, full of stars.
  c:rect(232, 0, 48, H, "05050f")
  stars(c, 60, 81, 232, 0, 48, H)
  c:vline(231, 0, H - 1, "7a5c1e"); c:vline(280, 0, H - 1, "7a5c1e")
  c:vline(230, 0, H - 1, "3e2e10"); c:vline(281, 0, H - 1, "3e2e10")
  -- Curved brass ribs either side.
  for _, base in ipairs({ 40, 120, 190, 322, 392, 472 }) do
    for y = 0, H - 1 do
      local bend = math.floor(math.sin(y / H * math.pi) * (base < 256 and -10 or 10))
      c:px(base + bend, y, "6e5420"); c:px(base + bend + 1, y, "3a2c10")
      if y % 24 == 0 then c:px(base + bend, y, "e0bc5a") end
    end
  end
  -- Constellations painted on the dome.
  local figures = { { { 70, 60 }, { 92, 48 }, { 104, 70 }, { 84, 90 } }, { { 140, 150 }, { 162, 130 }, { 176, 160 } },
    { { 340, 70 }, { 360, 92 }, { 352, 120 }, { 372, 128 } }, { { 420, 190 }, { 446, 176 }, { 452, 206 }, { 430, 220 } } }
  for _, f in ipairs(figures) do
    for i = 1, #f - 1 do
      local a, b = f[i], f[i + 1]
      for t = 0, 20 do
        local x = a[1] + (b[1] - a[1]) * t / 20
        local y = a[2] + (b[2] - a[2]) * t / 20
        if t % 3 == 0 then c:px(x, y, "3a3a78") end
      end
    end
    for _, p in ipairs(f) do c:px(p[1], p[2], "c8c8f0"); c:px(p[1] + 1, p[2], "6a6aa8") end
  end
  c:save("bg_observatory")
end

-- Station: hull panels in pale steel, a row of portholes onto space and a
-- crescent of the green-felt world, little status lights.
do
  local c = A.canvas(W, H)
  local steel = { "1c2430", "26303e", "303c4c", "3c4a5c" }
  for y = 0, H - 1 do for x = 0, W - 1 do
    local col = A.ramp(steel, 0.45 + math.sin(x * 0.01) * 0.1, x, y)
    if x % 64 == 0 or y % 48 == 0 then col = "151b24" end
    if (x % 64 == 1) or (y % 48 == 1) then col = "4c5c70" end
    if (x % 64 == 4 or x % 64 == 59) and (y % 48 == 4 or y % 48 == 43) then col = "8a98ac" end
    c:px(x, y, col)
  end end
  for i = 0, 3 do
    local cx, cy = 64 + i * 128, 96
    c:disc(cx, cy, 22, "151b24"); c:disc(cx, cy, 20, "8a98ac"); c:disc(cx, cy, 18, "4c5c70")
    c:disc(cx, cy, 16, "04050c")
    stars(c, 30, 90 + i, cx - 16, cy - 16, 32, 32, function(x, y) return (x - cx) ^ 2 + (y - cy) ^ 2 < 15 * 15 end)
    if i == 2 then
      for y = cy - 15, cy + 15 do for x = cx - 15, cx + 15 do
        local dx, dy = x + 0.5 - (cx + 6), y + 0.5 - (cy + 8)
        if dx * dx + dy * dy < 100 and (x - cx) ^ 2 + (y - cy) ^ 2 < 15 * 15 then c:px(x, y, A.ramp({ "14504a", "1f7a58", "3fa878" }, 0.6 - dx / 20, x, y)) end
      end end
    end
    for a = 0, 7 do
      local ang = a * math.pi / 4
      c:px(cx + math.cos(ang) * 19, cy + math.sin(ang) * 19, "d8e0ec")
    end
  end
  for i = 0, 20 do
    local x = math.floor(A.hash(i, 1, 93) * W)
    local y = 160 + math.floor(A.hash(i, 2, 93) * 120)
    c:rect(x, y, 2, 2, A.hash(i, 3, 93) > 0.5 and "4cbcb2" or "6af0ff")
  end
  c:save("bg_station")
end

-- Fire escape: blue-grey stucco tenement in the rain, iron stairs zigzagging
-- across it, lit windows with curtains, a drainpipe.
do
  local c = A.canvas(W, H)
  local stucco = { "161c26", "1c2430", "222c3a", "283444" }
  for y = 0, H - 1 do for x = 0, W - 1 do
    c:px(x, y, A.ramp(stucco, 0.5 + A.hash(x // 3, y // 3, 101) * 0.25 - 0.12, x, y))
  end end
  -- Windows in a grid, some lit with warm curtains.
  for row = 0, 3 do for col = 0, 6 do
    local x, y = 18 + col * 72, 12 + row * 72
    c:rect(x, y, 30, 40, "0c1018")
    if A.hash(col, row, 103) > 0.45 then
      c:rect(x + 2, y + 2, 26, 36, "6a5032")
      c:rect(x + 2, y + 2, 8, 36, "8a3a4a"); c:rect(x + 20, y + 2, 8, 36, "8a3a4a")
    else
      c:rect(x + 2, y + 2, 26, 36, "121822")
    end
    c:vline(x + 15, y, y + 39, "0c1018"); c:hline(x, x + 29, y + 20, "0c1018")
    c:hline(x - 2, x + 31, y + 40, "3a4452")
  end end
  -- Iron fire escape: landings and diagonal stairs.
  for row = 0, 3 do
    local y = 58 + row * 72
    c:rect(0, y, W, 2, "0a0c10"); c:hline(0, W - 1, y - 6, "0a0c10")
    for x = 0, W - 1, 6 do c:vline(x, y - 6, y, "0a0c10") end
    local dir = row % 2 == 0 and 1 or -1
    local sx = row % 2 == 0 and 300 or 210
    for s = 0, 70 do
      c:px(sx + dir * s, y + s, "0a0c10"); c:px(sx + dir * s, y + s - 1, "0a0c10")
      if s % 6 == 0 then c:hline(sx + dir * s - 3, sx + dir * s + 3, y + s, "0a0c10") end
    end
  end
  c:vline(496, 0, H - 1, "2c3440"); c:vline(497, 0, H - 1, "3a4452"); c:vline(498, 0, H - 1, "1a2028")
  -- Rain is animated in game (RainLayer), not baked in.
  c:save("bg_fire_escape")
end

-- Bell tower: inside a timber frame, cross bracing, louvred openings with the
-- storm outside, the great bell's silhouette up in the dark.
do
  local c = A.canvas(W, H)
  local dark = { "100c0a", "16110e", "1c1612", "241c16" }
  for y = 0, H - 1 do for x = 0, W - 1 do
    c:px(x, y, A.ramp(dark, 0.5, x, y))
  end end
  -- Louvred openings with stormy light.
  for _, ox in ipairs({ 60, 380 }) do
    c:rect(ox, 40, 72, 120, "1a2a34")
    for y = 44, 156, 8 do
      c:rect(ox + 2, y, 68, 4, "2a3e4a"); c:hline(ox + 2, ox + 69, y + 4, "0a0c10"); c:hline(ox + 2, ox + 69, y + 5, "0a0c10")
    end
    c:rect(ox - 4, 36, 80, 4, "3a2a1c"); c:rect(ox - 4, 160, 80, 4, "3a2a1c")
  end
  -- Timber posts and cross bracing.
  local wood = { "2a1c12", "3a2818", "4a3420" }
  for _, x in ipairs({ 0, 170, 342, 500 }) do c:rect(x, 0, 12, H, wood[2]); c:vline(x, 0, H - 1, wood[3]); c:vline(x + 11, 0, H - 1, wood[1]) end
  for i = 0, 1 do
    local y0 = i * 144
    for t = 0, 160 do
      c:rect(182 + t, y0 + t * 0.9, 6, 3, wood[2])
      c:rect(330 - t, y0 + t * 0.9, 6, 3, wood[1])
    end
  end
  for _, y in ipairs({ 0, 144 }) do c:rect(0, y, W, 8, wood[2]); c:hline(0, W - 1, y, wood[3]) end
  -- The bell's silhouette and rope.
  c:vline(256, 20, H - 1, "4a3a26")
  for y = 30, 78 do
    local hw = 10 + (y - 30) * 0.55 + ((y > 68) and (y - 68) * 1.2 or 0)
    c:hline(256 - hw, 256 + hw, y, y < 32 and "3a2c14" or "2a1e0e")
  end
  c:hline(240, 272, 80, "4a3818")
  c:save("bg_bell_tower")
end

-- Hanging lantern: iron cage, warm glass (16x22).
do
  local c = A.canvas(16, 22)
  c:rect(6, 0, 4, 2, "3a3e46")
  c:rect(3, 2, 10, 2, "2a2e36")
  c:rect(4, 4, 8, 13, "ffc870"); c:rect(5, 5, 6, 11, "ffe4a8"); c:rect(7, 6, 2, 8, "fff6d8")
  for y = 4, 16, 4 do c:hline(4, 11, y, "2a2e36") end
  c:vline(4, 4, 16, "2a2e36"); c:vline(11, 4, 16, "2a2e36"); c:vline(8, 4, 16, "3a3e46")
  c:rect(2, 17, 12, 2, "2a2e36"); c:rect(6, 19, 4, 2, "3a3e46")
  c:outline(OUT)
  c:save("lantern")
end

-- Bell: bronze with a lip and clapper (24x26).
do
  local c = A.canvas(24, 26)
  local bronze = { "4a3008", "7a5414", "b07a26", "e0aa48", "ffd890" }
  c:rect(10, 0, 4, 3, "3a2a14")
  for y = 3, 21 do
    local hw = 4 + (y - 3) * 0.35 + ((y > 17) and (y - 17) * 1.6 or 0)
    for x = math.floor(12 - hw), math.ceil(12 + hw) - 1 do
      local t = 0.75 - (x - (12 - hw)) / (2 * hw) * 0.7
      c:px(x, y, A.ramp(bronze, t, x, y))
    end
  end
  c:hline(2, 21, 21, bronze[2]); c:hline(3, 20, 20, bronze[4])
  c:disc(12, 23.5, 2, "3a2a14")
  c:outline(OUT)
  c:save("bell")
end

-- Star chart in a brass frame (28x34).
do
  local c = A.canvas(28, 34)
  c:rect(0, 0, 28, 34, "6e5420"); c:rect(1, 1, 26, 32, "c49a40"); c:rect(2, 2, 24, 30, "0e1030")
  for y = 2, 31 do for x = 2, 25 do if A.bayer(x, y) < (y - 2) / 50 then c:px(x, y, "161a44") end end end
  c:ring(14, 17, 10, "3a3a78")
  local pts = { { 8, 10 }, { 13, 7 }, { 19, 11 }, { 17, 18 }, { 10, 22 }, { 18, 26 } }
  for i = 1, #pts - 1 do
    local a, b = pts[i], pts[i + 1]
    c:line(a[1], a[2], b[1], b[2], "4a4a90")
  end
  for _, p in ipairs(pts) do c:px(p[1], p[2], "fff6d8") end
  c:hline(1, 26, 1, "fff0a8")
  c:save("star_chart")
end

-- Porthole (28x28): steel ring with bolts, a slice of space.
do
  local c = A.canvas(28, 28)
  c:disc(14, 14, 13.5, OUT); c:disc(14, 14, 12.5, "8a98ac"); c:disc(14, 14, 10.5, "4c5c70"); c:disc(14, 14, 9.5, "04050c")
  stars(c, 18, 111, 4, 4, 20, 20, function(x, y) return (x - 14) ^ 2 + (y - 14) ^ 2 < 9 * 9 end)
  for a = 0, 7 do local ang = a * math.pi / 4; c:px(14 + math.cos(ang) * 11.5, 14 + math.sin(ang) * 11.5, "d8e0ec") end
  for i = 0, 5 do c:px(8 + i, 7 + i // 2, "6a7ab0") end
  c:save("porthole")
end

-- Flower pot on a sill (10x12).
do
  local c = A.canvas(10, 12)
  c:grid(0, 0, {
    "...bb.b...",
    "..bgbbgb..",
    ".bgbgbgbb.",
    "..bgggb...",
    "....g.....",
    ".hhhhhhhh.",
    ".hppppppp.",
    "..ppppph..",
    "..ppppph..",
    "..ppppph..",
    "...pppp...",
    "..........",
  }, { b = "4ab874", g = "1f7a48", h = "c86a3a", p = "9a4a26" })
  c:outline(OUT)
  c:save("flower_pot")
end

-- Telescope: frame 0 the tripod mount, frame 1 the brass tube centred on its pivot (36x36 each).
do
  local c = A.canvas(72, 36)
  local brass = { "5a4218", "8c6a28", "c49a40", "f0d080" }
  c:line(18, 18, 8, 35, brass[1]); c:line(18, 18, 28, 35, brass[1]); c:line(18, 18, 18, 35, brass[2])
  c:disc(18, 18, 3, brass[2]); c:disc(17.5, 17.5, 1.5, brass[4])
  c:outline(OUT, 0, 0, 36, 36)
  local ox = 36
  for x = 4, 31 do
    local hw = x < 10 and 2 or (x < 24 and 3 or 4)
    c:vline(ox + x, 18 - hw, 17 + hw, brass[3]); c:px(ox + x, 18 - hw, brass[4]); c:px(ox + x, 17 + hw, brass[1])
  end
  c:vline(ox + 10, 15, 20, brass[1]); c:vline(ox + 24, 14, 21, brass[1])
  c:rect(ox + 31, 14, 2, 8, "2a2e36"); c:rect(ox + 3, 16, 2, 4, "2a2e36")
  c:outline(OUT, ox, 0, 36, 36)
  c:save("telescope")
end

-- Orrery base: a brass stand and ring; the planets are drawn in code (28x28).
do
  local c = A.canvas(28, 28)
  c:rect(10, 24, 8, 3, "6e5420"); c:hline(10, 17, 24, "e0bc5a")
  c:vline(13, 14, 24, "8c6a28"); c:vline(14, 14, 24, "5a4218")
  c:disc(14, 14, 3.5, "f0b92c"); c:disc(13, 13, 1.5, "fff0a8")
  c:outline(OUT)
  c:save("orrery")
end

-- Console: two frames of status lights (32x22). Cyan, green and white only:
-- red and yellow belong to traps.
do
  local c = A.canvas(64, 22)
  for f = 0, 1 do
    local ox = f * 32
    c:rect(ox, 2, 32, 20, "3c4a5c"); c:rect(ox + 1, 3, 30, 18, "26303e"); c:hline(ox + 1, ox + 30, 3, "8a98ac")
    c:rect(ox + 3, 5, 14, 9, "04080c")
    for i = 0, 5 do
      local on = (i + f) % 2 == 0
      c:rect(ox + 20 + (i % 3) * 4, 6 + (i // 3) * 5, 2, 2, on and (i < 3 and "6af0ff" or "6ae8a8") or "1c2a34")
    end
    for x = 4, 15 do
      local y = 9 + math.floor(math.sin((x + f * 4) * 0.8) * 3)
      c:px(ox + x, y, "6ae8a8")
    end
    c:rect(ox + 4, 16, 24, 3, "1c2430")
    for k = 0, 5 do c:rect(ox + 5 + k * 4, 16, 2, 2, "8a98ac") end
  end
  c:save("console")
end

-- Gear (24x24): an iron cog with eight teeth.
do
  local c = A.canvas(24, 24)
  for y = 0, 23 do for x = 0, 23 do
    local dx, dy = x + 0.5 - 12, y + 0.5 - 12
    local d = math.sqrt(dx * dx + dy * dy)
    local a = math.atan(dy, dx)
    local tooth = math.cos(a * 8) > 0.3
    if d < 8.5 or (tooth and d < 11) then
      local shade = 0.55 - (dx + dy) / 30
      c:px(x, y, A.ramp({ "2a2e36", "3a3e46", "54586a", "7a7e90" }, shade, x, y))
    end
    if d < 3 then c:px(x, y, "151820") end
  end end
  c:ring(12, 12, 6, "2a2e36")
  c:outline(OUT)
  c:save("gear")
end

-- Cyan sparks for the console (3 frames of 5x5).
do
  local c = A.canvas(15, 5)
  c:grid(0, 0, { "..a..", ".aba.", "abcba", ".aba.", "..a.." }, { a = "4cbcb2", b = "a8f4ff", c = "ffffff" })
  c:grid(5, 0, { ".....", "..a..", ".aba.", "..a..", "....." }, { a = "4cbcb2", b = "ffffff" })
  c:grid(10, 0, { ".....", ".....", "..a..", ".....", "....." }, { a = "a8f4ff" })
  c:save("spark_blue")
end

print("Theme art exported.")
