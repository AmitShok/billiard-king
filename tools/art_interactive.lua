-- Billiard King: art for the reactive decor.
--   window.png      2 frames of 40x52: intact glass / shattered (jagged shards in the frame)
--   glass_shard.png 4 frames of 4x4 falling glass bits
--   spark.png       3 frames of 5x5 neon sparks
--   score_wire.png  96x10 wire and end posts without beads
--   bead.png        2 frames of 6x8: ivory bead / walnut bead
--   aseprite -b --script-param root=<project> --script tools/art_interactive.lua
local A = dofile(app.params["root"] .. "/tools/art_lib.lua")
local OUT = "11090c"

-- Night window: frame 0 intact, frame 1 shattered.
do
  local c = A.canvas(80, 52)
  local wood = { "2a160e", "4a2a18", "6a4024", "8c5a32" }
  for f = 0, 1 do
    local ox = f * 40
    c:rect(ox, 0, 40, 52, wood[2]); c:rect(ox + 1, 1, 38, 50, wood[3]); c:hline(ox + 1, ox + 38, 1, wood[4])
    -- The night outside (the same view in both frames).
    for y = 3, 46 do for x = 3, 36 do
      local col = "0c1028"
      if A.bayer(x, y) < (y - 3) / 60 then col = "1a1a40" end
      if A.hash(x, y, 77) > 0.985 then col = "9a9ac8" end
      c:px(ox + x, y, col)
    end end
    for i = 0, 4 do
      local bx, bh = 3 + i * 7, 8 + math.floor(A.hash(i, 0, 5) * 16)
      c:rect(ox + bx, 47 - bh, 6, bh, "141230")
      for wy = 47 - bh + 2, 45, 4 do if A.hash(bx, wy, 3) > 0.5 then c:px(ox + bx + 2, wy, "c8a050") end end
    end
    -- Four panes between the mullions.
    local panes = { { 3, 3, 16, 21 }, { 21, 3, 16, 21 }, { 3, 26, 16, 21 }, { 21, 26, 16, 21 } }
    for pi, p in ipairs(panes) do
      local px0, py0, pw, ph = p[1], p[2], p[3], p[4]
      for y = py0, py0 + ph - 1 do for x = px0, px0 + pw - 1 do
        local lx, ly = x - px0, y - py0
        if f == 0 then
          -- Intact: faint glass sheen and a diagonal glint.
          local d = lx + ly
          if (d == 9 or d == 10) and lx < 9 then c:px(ox + x, y, "5a6a98", 140) end
          if d == 13 and lx < 11 and lx > 3 then c:px(ox + x, y, "3a4a78", 110) end
        else
          -- Shattered: jagged shards still stuck in the frame, a hole in the middle.
          local edge = math.min(lx, ly, pw - 1 - lx, ph - 1 - ly)
          local h = A.hash(math.floor((lx + ly * 3) / 2), pi, 41)
          local jag = math.floor(h * 2.5)
          if h > 0.82 then jag = jag + 4 end
          if edge < jag then
            c:px(ox + x, y, ((lx + ly) % 4 == 0) and "b8c8e8" or "4a5a90", 200)
          elseif edge == jag and A.hash(x, y, 9) > 0.5 then
            c:px(ox + x, y, "e8f0ff")
          end
        end
      end end
    end
    c:vline(ox + 19, 3, 46, wood[2]); c:vline(ox + 20, 3, 46, wood[1]); c:hline(ox + 3, ox + 36, 24, wood[2]); c:hline(ox + 3, ox + 36, 25, wood[1])
    c:rect(ox, 47, 40, 5, wood[3]); c:hline(ox, ox + 39, 47, wood[4]); c:hline(ox, ox + 39, 51, wood[1])
    if f == 0 then
      for y = 4, 20 do if y % 3 ~= 0 then c:px(ox + 5 + (y // 3), y, "3a3a6a") end end
    end
  end
  c:save("window")
end

-- Glass shards (4 frames of 4x4).
do
  local c = A.canvas(16, 4)
  local shapes = {
    { "ab..", "bba.", ".b..", "...." },
    { ".a..", "aab.", ".bb.", "..b." },
    { "a...", "ba..", "bbb.", "...." },
    { "..a.", ".ab.", "abb.", "...." },
  }
  for i, s in ipairs(shapes) do c:grid((i - 1) * 4, 0, s, { a = "f0f6ff", b = "8aa0d0" }) end
  c:save("glass_shard")
end

-- Neon sparks (3 frames of 5x5).
do
  local c = A.canvas(15, 5)
  c:grid(0, 0, { "..a..", ".aba.", "abcba", ".aba.", "..a.." }, { a = "ff6ab4", b = "ffc0e0", c = "ffffff" })
  c:grid(5, 0, { ".....", "..a..", ".aba.", "..a..", "....." }, { a = "ff6ab4", b = "ffffff" })
  c:grid(10, 0, { ".....", ".....", "..a..", ".....", "....." }, { a = "ffc0e0" })
  c:save("spark")
end

-- Score wire without beads, and the beads on their own.
do
  local c = A.canvas(96, 10)
  c:hline(0, 95, 4, "8a8a90"); c:hline(0, 95, 5, "4a4a52")
  c:rect(0, 1, 3, 8, "4a2a18"); c:rect(93, 1, 3, 8, "4a2a18")
  c:outline(OUT)
  c:save("score_wire")
end
do
  local c = A.canvas(12, 8)
  for f = 0, 1 do
    local ox = f * 6
    local mid = f == 0 and "c8b898" or "4a4038"
    local hi = f == 0 and "e8dcc0" or "2a2420"
    c:rect(ox, 1, 5, 6, mid); c:rect(ox + 1, 0, 3, 8, mid)
    c:rect(ox + 1, 1, 2, 2, hi)
    c:vline(ox + 4, 1, 6, f == 0 and "9a8a70" or "2a2420")
  end
  c:save("bead")
end

print("Interactive props exported.")
