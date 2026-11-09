-- Vertical Billiard: moving platforms and traps.
--   moving_platform.png  48x80: columns left/middle/right, rows = zone (0 Back Room, 1 Neon Bar, 2 Royal Club, 3 Moon, 4 Storm).
--                        Felt deck on a bright brass carriage with wheels, so it reads as machinery.
--   spike_ball.png       2 frames of 28x28: a red spiked ball. Danger colours (hot red and warning
--                        yellow) are reserved for traps; no decoration uses them.
--   spinner_hub.png      18x18: the steel-and-red hub of a spinning arm trap (arms are drawn in code).
--   aseprite -b --script-param root=<project> --script tools/art_traps.lua
local A = dofile(app.params["root"] .. "/tools/art_lib.lua")
local OUT = "11090c"

-- Moving platform tiles.
do
  local c = A.canvas(48, 144)
  local felts = {
    { "74c07a", "4a9c5e", "2f7c4c" },
    { "d4607a", "a83a52", "822840" },
    { "72aaf8", "3c80e0", "2660b8" },
    { "d8deea", "9aa2b6", "737a90" },
    { "7cc0b4", "45908c", "2c6a6e" },
    { "8a8ae0", "4c4cb0", "34348c" },
    { "7cd8d0", "34a0a0", "1e7a80" },
    { "8cae6c", "547a44", "3a5a30" },
    { "b070a0", "804070", "602a52" },
  }
  local brass = { "5a4218", "8c6a28", "c49a40", "f0d080" }
  for z = 0, 8 do
    local f = felts[z + 1]
    for part = 0, 2 do
      local ox, oy = part * 16, z * 16
      -- Felt deck.
      c:rect(ox, oy, 16, 1, f[1]); c:rect(ox, oy + 1, 16, 2, f[2]); c:rect(ox, oy + 3, 16, 1, f[3])
      -- Brass beam with rivets.
      c:rect(ox, oy + 4, 16, 6, brass[3]); c:hline(ox, ox + 15, oy + 4, brass[4]); c:hline(ox, ox + 15, oy + 9, brass[1])
      c:rect(ox, oy + 5, 16, 1, brass[3])
      for x = 2, 14, 6 do c:px(ox + x, oy + 7, brass[4]); c:px(ox + x, oy + 8, brass[1]) end
      -- Dark underside with hazard-free cross bracing.
      c:rect(ox, oy + 10, 16, 3, "2a2018")
      for x = 0, 15 do if (x + 0) % 4 == 0 then c:px(ox + x, oy + 11, brass[2]) end end
      -- Carriage wheels on the end pieces, a single centre wheel in the middle.
      local wheels = part == 1 and { 8 } or { 8 }
      for _, wx in ipairs(wheels) do
        c:disc(ox + wx, oy + 13, 2.6, "11090c"); c:disc(ox + wx, oy + 13, 1.6, brass[2]); c:px(ox + wx, oy + 13, brass[4])
      end
      -- Rounded ends.
      if part == 0 then
        c:px(ox, oy, "00000000", 0); c:px(ox, oy + 12, "00000000", 0)
        c:vline(ox, oy + 1, oy + 11, OUT)
      elseif part == 2 then
        c:px(ox + 15, oy, "00000000", 0); c:px(ox + 15, oy + 12, "00000000", 0)
        c:vline(ox + 15, oy + 1, oy + 11, OUT)
      end
    end
  end
  c:save("moving_platform")
end

-- Spiked ball trap: two frames with the spikes turned 22.5 degrees.
do
  local c = A.canvas(56, 28)
  for f = 0, 1 do
    local ox = f * 28
    local cx, cy = ox + 14, 14
    for i = 0, 7 do
      local a = i * math.pi / 4 + f * math.pi / 8
      local dx, dy = math.cos(a), math.sin(a)
      -- A tapering spike: yellow core, white tip.
      for t = 7, 13 do
        local w = (13 - t) / 3.2
        for s = -2, 2 do
          local o = s * 0.5
          if math.abs(o) <= w then
            c:px(cx + dx * t - dy * o, cy + dy * t + dx * o, t > 11 and "fff4c0" or "ffc21a")
          end
        end
      end
    end
    c:disc(cx, cy, 8.5, OUT)
    c:disc(cx, cy, 7.5, "b01018")
    c:disc(cx - 1, cy - 1, 5.5, "e02028")
    c:disc(cx - 2.5, cy - 2.5, 2, "ff8a80")
    -- A warning X across the face.
    for d = -3, 3 do
      c:px(cx + d + 1, cy + d + 1, "ffc21a")
      c:px(cx + d + 1, cy - d + 1, "ffc21a")
    end
    c:outline(OUT, ox, 0, 28, 28)
  end
  c:save("spike_ball")
end

-- Spinner hub.
do
  local c = A.canvas(18, 18)
  c:disc(9, 9, 8.5, OUT)
  c:disc(9, 9, 7.5, "ffc21a")
  for y = 0, 17 do for x = 0, 17 do
    local dx, dy = x + 0.5 - 9, y + 0.5 - 9
    if dx * dx + dy * dy <= 7.5 * 7.5 and (x + y) % 6 < 3 then c:px(x, y, "d01820") end
  end end
  c:disc(9, 9, 4, OUT)
  c:disc(9, 9, 3, "8a8a96")
  c:disc(8.5, 8.5, 1.5, "e4e4ee")
  c:save("spinner_hub")
end

print("Trap art exported.")
