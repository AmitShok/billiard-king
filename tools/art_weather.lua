-- Vertical Billiard: props for the moon, space and storm sections.
--   asteroid.png    3 frames of 28x24: chunks of felt-capped moon rock
--   satellite.png   36x18: gold solar panels around a small 8-ball body
--   moon_flag.png   3 frames of 26x30: a pennant with an 8-ball, waving
--   vane.png        2 frames of 32x32: frame 0 the fixed post, frame 1 the arrow that turns
--   aseprite -b --script-param root=<project> --script tools/art_weather.lua
local A = dofile(app.params["root"] .. "/tools/art_lib.lua")
local OUT = "11090c"

-- Asteroids: lumpy rock with craters and a tuft of worn felt, three shapes.
do
  local c = A.canvas(84, 24)
  local rock = { "3a3c4a", "565a6c", "787d90", "9ea3b4" }
  local lobes = {
    { { 14, 12, 9 }, { 8, 13, 5 }, { 20, 10, 5 } },
    { { 13, 12, 8 }, { 19, 15, 6 }, { 9, 8, 5 } },
    { { 14, 13, 7 }, { 8, 11, 4 }, { 21, 13, 4 }, { 15, 7, 4 } },
  }
  for f = 0, 2 do
    local ox = f * 28
    for _, l in ipairs(lobes[f + 1]) do
      for y = 0, 23 do for x = 0, 27 do
        local dx, dy = x + 0.5 - l[1], y + 0.5 - l[2]
        if dx * dx + dy * dy <= l[3] * l[3] then
          local shade = 0.5 - (dx + dy) / (l[3] * 3.2) + A.hash(x, y, 300 + f) * 0.12
          c:px(ox + x, y, A.ramp(rock, shade, x, y))
        end
      end end
    end
    -- Craters.
    local holes = { { 11, 12, 2.2 }, { 17, 14, 1.6 }, { 14, 8, 1.3 } }
    for _, h in ipairs(holes) do
      if c:alpha_at(ox + h[1], h[2]) > 0 then
        c:disc(ox + h[1], h[2], h[3], rock[1]); c:disc(ox + h[1] + 0.5, h[2] + 0.5, h[3] - 0.7, rock[2])
      end
    end
    c:outline(OUT, ox, 0, 28, 24)
  end
  c:save("asteroid")
end

-- Satellite: gold panels, a dark ball for a body, one antenna.
do
  local c = A.canvas(36, 18)
  local gold = { "5e4214", "a07a2a", "e0bc5a", "fff0a8" }
  for _, ox in ipairs({ 1, 23 }) do
    c:rect(ox, 5, 12, 9, gold[2])
    for x = 0, 11, 3 do c:vline(ox + x, 5, 13, gold[1]) end
    c:hline(ox, ox + 11, 9, gold[1])
    c:hline(ox, ox + 11, 5, gold[4])
    for y = 6, 12 do if (y + ox) % 3 == 0 then c:px(ox + 1, y, gold[3]) end end
  end
  c:rect(13, 9, 10, 1, "8a8a96")
  c:disc(18, 9, 6, "1d1c22"); c:disc(16.5, 7.5, 1.6, "5a5a68")
  c:disc(18, 9, 2.5, "f4eedc"); c:rect(17, 8, 2, 1, "1d1c22"); c:rect(17, 10, 2, 1, "1d1c22")
  c:line(18, 3, 22, 0, "c8c8d4"); c:px(22, 0, "ffffff")
  c:outline(OUT)
  c:save("satellite")
end

-- Moon flag: pole and pennant with an 8-ball, three frames of ripple.
do
  local c = A.canvas(78, 30)
  for f = 0, 2 do
    local ox = f * 26
    c:vline(ox + 3, 1, 29, "c8c8d4"); c:vline(ox + 2, 1, 29, "6a6a78")
    c:px(ox + 3, 0, "fff0a8")
    for x = 0, 19 do
      local wave = math.floor(math.sin((x / 4.0) + f * 2.1) * (x / 12.0) + 0.5)
      for y = 2, 13 do
        local col = (y < 4 or y > 11) and "1f7a48" or "2a9a5c"
        c:px(ox + 4 + x, y + wave, col)
      end
      c:px(ox + 4 + x, 2 + wave, "4ab874")
      c:px(ox + 4 + x, 13 + wave, "135432")
    end
    local bx = ox + 13
    local by = 8 + math.floor(math.sin((9 / 4.0) + f * 2.1) * (9 / 12.0) + 0.5)
    c:disc(bx, by, 4, "1d1c22"); c:disc(bx, by, 1.7, "f4eedc"); c:px(bx - 3, by - 3, "5a5a68")
  end
  c:save("moon_flag")
end

-- Weather vane: brass post with an 8-ball finial; the arrow turns separately.
do
  local c = A.canvas(64, 32)
  local brass = { "5a4218", "8c6a28", "c49a40", "f0d080" }
  c:vline(16, 16, 31, brass[3]); c:vline(15, 16, 31, brass[1])
  c:rect(12, 29, 8, 3, brass[2]); c:hline(12, 19, 29, brass[4])
  c:disc(16, 16, 3.5, "1d1c22"); c:disc(16, 16, 1.5, "f4eedc"); c:px(14, 14, "5a5a68")
  c:outline(OUT, 0, 0, 32, 32)
  -- Arrow, pointing right, centred on its pivot.
  local ox = 32
  c:hline(ox + 4, ox + 26, 16, brass[3]); c:hline(ox + 4, ox + 26, 15, brass[4])
  for i = 0, 4 do c:vline(ox + 26 + i, 16 - (4 - i), 15 + (4 - i), brass[3]) end
  for i = 0, 3 do
    c:px(ox + 4 + i * 2, 13, brass[2]); c:px(ox + 4 + i * 2, 14, brass[2])
    c:px(ox + 4 + i * 2, 17, brass[2]); c:px(ox + 4 + i * 2, 18, brass[2])
  end
  c:outline(OUT, ox, 0, 32, 32)
  c:save("vane")
end

print("Weather props exported.")
