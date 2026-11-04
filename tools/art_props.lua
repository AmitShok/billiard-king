-- Vertical Billiard: decor and gameplay props. Multi-frame props are horizontal strips.
--   aseprite -b --script-param root=<project> --script tools/art_props.lua
local A = dofile(app.params["root"] .. "/tools/art_lib.lua")
local OUT = "11090c"

-- Billiard lamp: brass bar with two green glass shades (48x16).
do
  local c = A.canvas(48, 16)
  local brass = { "5a4218", "8c6a28", "c49a40", "f0d080" }
  c:rect(2, 2, 44, 2, brass[3]); c:hline(2, 45, 2, brass[4]); c:hline(2, 45, 4, brass[1])
  c:rect(23, 0, 2, 2, brass[2])
  for _, cx in ipairs({ 12, 36 }) do
    c:rect(cx - 1, 4, 2, 2, brass[2])
    for y = 6, 13 do
      local hw = math.floor(3 + (y - 6) * 1.05)
      for x = cx - hw, cx + hw - 1 do
        local t = (x - (cx - hw)) / (2 * hw)
        local col = t < 0.25 and "3fa86a" or (t < 0.6 and "1f7a48" or "135432")
        if y == 6 then col = "5cc888" end
        c:px(x, y, col)
      end
    end
    c:hline(cx - 11, cx + 10, 14, brass[3]); c:hline(cx - 10, cx + 9, 15, "fff4c0")
  end
  c:outline(OUT)
  c:save("lamp")
end

-- Warm light cone thrown on the wall under a lamp (additive, 112x150).
do
  local c = A.canvas(112, 150)
  for y = 0, 149 do
    local hw = 10 + y * 0.32
    for x = 0, 111 do
      local dx = math.abs(x + 0.5 - 56) / hw
      if dx < 1 then
        -- Three soft bands, dithered only where one band meets the next.
        local t = (1 - dx * dx) * (1 - y / 150)
        local band = t + (A.bayer(x, y) - 0.5) * 0.12
        if band > 0.55 then c:px(x, y, "ffc870", 64)
        elseif band > 0.3 then c:px(x, y, "ffb860", 40)
        elseif band > 0.1 then c:px(x, y, "ffa850", 22) end
      end
    end
  end
  c:save("light_cone")
end

-- Soft round glow (additive, 64x64) for chandeliers and neon.
do
  local c = A.canvas(64, 64)
  for y = 0, 63 do for x = 0, 63 do
    local d = math.sqrt((x + 0.5 - 32) ^ 2 + (y + 0.5 - 32) ^ 2) / 32
    local t = (1 - d) * 0.9
    if t > A.bayer(x, y) * 0.8 + 0.05 then
      c:px(x, y, "ffffff", t > 0.55 and 60 or (t > 0.3 and 38 or 20))
    end
  end end
  c:save("glow")
end

-- Chain link (4x6), tiled vertically for hanging props.
do
  local c = A.canvas(4, 6)
  c:grid(0, 0, { ".ab.", "a..b", "a..b", ".ab.", ".c..", ".c.." }, { a = "8c6a28", b = "5a4218", c = "3a2a10" })
  c:save("chain")
end

-- Wall cue rack with four cues (28x64).
do
  local c = A.canvas(28, 64)
  local wood = { "2e180e", "4a2814", "6c3e20", "8e5830" }
  c:rect(1, 2, 26, 6, wood[3]); c:hline(1, 26, 2, wood[4]); c:hline(1, 26, 7, wood[1])
  c:rect(1, 54, 26, 7, wood[3]); c:hline(1, 26, 54, wood[4]); c:hline(1, 26, 60, wood[1])
  local cues = { { 5, "e8d4a8", "7a1e1e" }, { 11, "e0c890", "1e3a6a" }, { 17, "ead8b0", "22422a" }, { 23, "dcc48c", "3a2a20" } }
  for _, q in ipairs(cues) do
    local x = q[1]
    c:rect(x, 4, 1, 2, "4a8adc") -- chalked tip
    c:px(x, 6, "f4f0e8")
    c:vline(x, 7, 34, q[2]); c:vline(x + 1, 9, 34, "b8a070")
    c:vline(x, 35, 40, "f0e8d8")
    c:rect(x, 41, 2, 16, q[3]); c:px(x, 41, "d0b060"); c:vline(x, 46, 50, "c8b8a0")
    c:rect(x, 57, 2, 2, "141414")
    c:rect(x - 1, 55, 4, 1, wood[1])
  end
  c:outline(OUT)
  c:save("cue_rack")
end

-- Score wire with sliding beads (96x10).
do
  local c = A.canvas(96, 10)
  c:hline(0, 95, 4, "8a8a90"); c:hline(0, 95, 5, "4a4a52")
  c:rect(0, 1, 3, 8, "4a2a18"); c:rect(93, 1, 3, 8, "4a2a18")
  local xs = { 6, 12, 18, 24, 36, 66, 72, 78, 84 }
  for i, x in ipairs(xs) do
    local dark = i > 4 and "2a2420" or "e8dcc0"
    local mid = i > 4 and "4a4038" or "c8b898"
    c:rect(x, 2, 5, 6, mid); c:rect(x + 1, 1, 3, 8, mid)
    c:rect(x + 1, 2, 2, 2, dark)
  end
  c:outline(OUT)
  c:save("score_beads")
end

-- Neon "POOL" sign, two frames: lit / flickered off (60x24 each).
do
  local c = A.canvas(120, 24)
  local letters = {
    { "####.", "#...#", "####.", "#....", "#...." },
    { ".###.", "#...#", "#...#", "#...#", ".###." },
    { ".###.", "#...#", "#...#", "#...#", ".###." },
    { "#....", "#....", "#....", "#....", "#####" },
  }
  for f = 0, 1 do
    local ox = f * 60
    c:rect(ox + 2, 2, 56, 20, "1a1424"); c:rect(ox + 3, 3, 54, 18, "100c18")
    local tube = f == 0 and "ff6ab4" or "5a2a44"
    local core = f == 0 and "ffe0f0" or "6a3a54"
    for i, g in ipairs(letters) do
      for gy, row in ipairs(g) do for gx = 1, 5 do
        if row:sub(gx, gx) == "#" then
          local x, y = ox + 6 + (i - 1) * 13 + (gx - 1) * 2, 5 + (gy - 1) * 3
          c:rect(x, y, 2, 2, tube)
          c:px(x, y, core)
        end
      end end
    end
    c:px(ox + 1, 0, "6a6a70"); c:px(ox + 58, 0, "6a6a70")
  end
  c:save("neon_pool")
end

-- Neon 8-ball roundel, two frames (32x32 each).
do
  local c = A.canvas(64, 32)
  for f = 0, 1 do
    local ox = f * 32
    local tube = f == 0 and "6af0ff" or "1e4a54"
    local glow = f == 0 and "e8ffff" or "2a5a64"
    c:ring(ox + 16, 16, 14, tube); c:ring(ox + 16, 16, 13, glow)
    c:ring(ox + 16, 12, 4, f == 0 and "fff27a" or "5a5428")
    c:ring(ox + 16, 20, 5, f == 0 and "fff27a" or "5a5428")
  end
  c:save("neon_eight")
end

-- Crystal chandelier (48x36).
do
  local c = A.canvas(48, 36)
  local gold = { "5e4214", "a07a2a", "e0bc5a", "fff0a8" }
  c:rect(23, 0, 2, 8, gold[2])
  c:ellipse(24, 10, 4, 3, gold[3])
  for i = 0, 4 do
    local x = 6 + i * 9
    c:line(24, 12, x, 18, gold[2])
    c:rect(x - 2, 18, 5, 2, gold[3]); c:hline(x - 2, x + 2, 18, gold[4])
    c:rect(x, 14, 1, 4, "fff8e0"); c:px(x, 13, "ffd060")
    for d = 0, 2 do c:px(x - 1 + d, 21 + d * 2, d == 1 and "e0f4ff" or "9ac8e8") end
  end
  c:ellipse(24, 26, 10, 3, gold[2]); c:hline(15, 33, 25, gold[4])
  for i = 0, 6 do
    local x = 14 + i * 3
    c:vline(x, 29, 31 + (i % 3) * 1, i % 2 == 0 and "c8e8ff" or "80b0d8")
  end
  c:px(24, 34, "ffffff")
  c:outline(OUT)
  c:save("chandelier")
end

-- Gilt portrait of the Founder: a crowned 8-ball (28x34).
do
  local c = A.canvas(28, 34)
  local gold = { "5e4214", "a07a2a", "e0bc5a", "fff0a8" }
  c:rect(0, 0, 28, 34, gold[2]); c:rect(1, 1, 26, 32, gold[3])
  c:rect(2, 2, 24, 30, gold[1]); c:rect(3, 3, 22, 28, "2a1e30")
  for y = 3, 30 do for x = 3, 24 do if A.bayer(x, y) < (y - 3) / 40 then c:px(x, y, "3a2a40") end end end
  c:disc(14, 20, 7, "1d1c22"); c:disc(12, 18, 2, "4a4a58"); c:disc(14, 20, 3, "f4eedc")
  c:rect(13, 19, 2, 1, "1d1c22"); c:rect(13, 21, 2, 1, "1d1c22")
  c:grid(8, 7, { "a..a..a", "aa.a.aa", "aaaaaaa", "bbbbbbb" }, { a = "f2c440", b = "b08020" })
  c:hline(1, 26, 1, gold[4]); c:vline(1, 1, 32, gold[4])
  c:save("portrait")
end

-- Golden crown (20x16), 4 frames of a travelling glint (80x16).
do
  local c = A.canvas(80, 16)
  local rows = {
    "...e......e......e..",
    "..eae....eae....eae.",
    "...a......a......a..",
    "...aa....aaa....aa..",
    "..aaaa..aaaaa..aaaa.",
    "..abaaa.aabaa.aaaba.",
    ".aaaaaaaaaaaaaaaaaaa",
    ".aaaaaaaaaaaaaaaaaaa",
    ".bbbbbbbbbbbbbbbbbbb",
    ".cdcccdcccdcccdcccdc",
    ".cccccccccccccccccccc",
    ".bbbbbbbbbbbbbbbbbbb",
  }
  for f = 0, 3 do
    local pal = { a = "f2c440", b = "b08020", c = "d8a830", d = "c8302e", e = "fff6c0" }
    c:grid(f * 20, 2, rows, pal)
    local gx = f * 20 + 3 + f * 5
    for y = 8, 13 do c:px(gx + (13 - y) // 2, y, "fffbe0") end
  end
  c:outline(OUT)
  c:save("crown")
end

-- Pocket, side view (24x20): the mouth cut into the felt (surface at row 6)
-- with a woven net bag hanging into the table below. Gold variant for the goal.
for _, v in ipairs({ { "pocket", { "2a1a0e", "6a4a28", "b08a48" }, { "3a2414", "7a5634" } }, { "pocket_gold", { "5a3a08", "c8962a", "ffe080" }, { "4a0e18", "a02a3a" } } }) do
  local c = A.canvas(24, 20)
  local rim, net = v[2], v[3]
  for y = 8, 19 do
    local hw = 7.5 - (y - 8) * 0.32
    if y >= 17 then hw = hw - (y - 16) * 1.2 end
    for x = 0, 23 do
      local dx = x + 0.5 - 12
      if math.abs(dx) <= hw then
        local strand = (x + y) % 4 == 0 or (x - y) % 4 == 0
        c:px(x, y, strand and net[2] or net[1], strand and 255 or 215)
      end
    end
  end
  c:ellipse(12, 6, 9.5, 3.5, rim[1])
  c:ellipse(12, 6, 8.5, 2.8, rim[2])
  c:ellipse(12, 5.5, 8.5, 2.2, rim[3])
  c:ellipse(12, 6.5, 7, 2.2, "050303")
  c:ellipse(12, 7.5, 5, 1.5, "000000")
  c:px(5, 5, "fff4d0"); c:px(6, 4, "fff4d0")
  c:save(v[1])
end

-- Bumper ring: brass collar the big pinned bumper balls sit in (32x32).
do
  local c = A.canvas(32, 32)
  c:disc(16, 16, 15.5, "2a1c0a"); c:disc(16, 16, 14.5, "8c6a28"); c:disc(15.5, 15.5, 14, "e0bc5a")
  c:disc(16, 16, 13, "a07a2a"); c:disc(16, 16, 12, "000000", 0)
  for i = 0, 11 do
    local ang = i * math.pi / 6
    c:px(16 + math.cos(ang) * 13.5, 16 + math.sin(ang) * 13.5, "fff0a8")
  end
  for y = 0, 31 do for x = 0, 31 do
    local d = math.sqrt((x + 0.5 - 16) ^ 2 + (y + 0.5 - 16) ^ 2)
    if d < 12 then c:px(x, y, "000000", 0) end
  end end
  c:save("bumper_ring")
end

-- Wall clock (20x20). The window lives in art_interactive.lua.
do
  local c = A.canvas(20, 20)
  c:disc(10, 10, 9.5, "3a2414"); c:disc(10, 10, 8.5, "8c5a30"); c:disc(10, 10, 7.5, "e8dcc0")
  for i = 0, 11 do local a = i * math.pi / 6; c:px(10 + math.cos(a) * 6, 10 + math.sin(a) * 6, "6a5a4a") end
  c:line(10, 10, 10, 5, "1c1a1f"); c:line(10, 10, 13, 12, "1c1a1f"); c:px(10, 10, "c8302e")
  c:save("clock")
end

-- Chalk cube (6x6) and a wooden triangle rack lying flat (24x10).
do
  local c = A.canvas(6, 6)
  c:grid(0, 0, { ".aaaa.", "abbbba", "abccba", "abccba", "abbbba", ".dddd." }, { a = "8ac0f0", b = "4a90dc", c = "2c6ab8", d = "1c3a6a" })
  c:save("chalk")
end
do
  local c = A.canvas(24, 20)
  local wood = { "4a2a18", "8c5a32", "b07a48" }
  for i = 0, 19 do
    local hw = i * 0.6
    c:px(12 - hw, i, wood[2]); c:px(11 - hw, i, wood[1]); c:px(12 + hw, i, wood[2]); c:px(13 + hw, i, wood[1])
  end
  c:hline(0, 23, 18, wood[3]); c:hline(0, 23, 19, wood[1])
  c:save("rack")
end

-- Dust puff frames for landings (4 frames of 16x8).
do
  local c = A.canvas(64, 8)
  for f = 0, 3 do
    local spread = 2 + f * 2
    for i = 0, 5 do
      local x = f * 16 + 8 + (i - 2.5) * spread * 0.55
      local y = 6 - (i % 2) - f * 0.6
      local r = math.max(0.6, 2.2 - f * 0.5)
      c:disc(x, y, r, f < 2 and "d8d0c0" or "a8a090", f < 3 and 255 or 160)
    end
  end
  c:save("dust")
end

print("Props exported.")
