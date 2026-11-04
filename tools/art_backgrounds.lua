-- Vertical Billiard: per-zone backdrops, 512x288 (one screen), tiling vertically
-- so the tower reads as one continuous building.
--   bg_backroom.png  bg_neonbar.png  bg_royal.png  bg_summit.png
--   aseprite -b --script-param root=<project> --script tools/art_backgrounds.lua
local A = dofile(app.params["root"] .. "/tools/art_lib.lua")
local W, H = 512, 288

-- Back Room: old soot-stained brick, staggered courses, a few patched bricks.
do
  local c = A.canvas(W, H)
  local bricks = { "251714", "2c1b17", "33201b", "3b241e", "432a22" }
  local mortar, mortar_lit = "150d0b", "1d1310"
  for y = 0, H - 1 do
    local course = y // 8
    for x = 0, W - 1 do
      local bx = (x + (course % 2) * 8) // 16
      local lx, ly = (x + (course % 2) * 8) % 16, y % 8
      local col
      if ly == 7 or lx == 15 then
        col = mortar
      elseif ly == 6 or lx == 14 then
        col = mortar_lit
      else
        local h = A.hash(bx, course, 3)
        local base = 2 + math.floor(h * 2.99)
        -- Large-scale soot blotches keep the wall from looking flat.
        local soot = math.sin(x * 0.021 + y * 0.013) + math.sin(x * 0.007 - y * 0.031)
        if soot > 1.1 then base = base - 1 end
        if ly == 0 and A.hash(x, course, 5) > 0.4 then base = base + 1 end
        if A.hash(x, y, 6) > 0.93 then base = base - 1 end
        if A.hash(bx, course, 8) > 0.97 then base = 5 end
        col = bricks[math.max(1, math.min(5, base))]
      end
      c:px(x, y, col)
    end
  end
  c:save("bg_backroom")
end

-- Neon Bar: plum flock wallpaper with a repeating diamond motif.
do
  local c = A.canvas(W, H)
  local base, mid, hi, line = "160f22", "1c1430", "241a3c", "2c2048"
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local col = base
      if (x // 16) % 2 == 0 then col = mid end
      local mx, my = x % 32 - 16, y % 32 - 16
      local d = math.abs(mx) + math.abs(my)
      if d == 9 or d == 4 then col = hi end
      if d == 0 then col = line end
      if x % 32 == 0 then col = "120c1a" end
      if A.hash(x, y, 31) > 0.97 then col = base end
      c:px(x, y, col)
    end
  end
  c:save("bg_neonbar")
end

-- Royal Club: navy damask with gilt pilasters.
do
  local c = A.canvas(W, H)
  local base, motif, edge = "111a3c", "18244e", "1f2e5e"
  local gold = { "2a2238", "3e3448", "5a4a3a", "7a6440" }
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local col = base
      local mx, my = (x % 48) - 24, (y % 48) - 24
      if (y // 48) % 2 == 1 then mx = ((x + 24) % 48) - 24 end
      -- Damask lobe: a pinched diamond with curled sides.
      local r = math.abs(mx) * 1.3 + math.abs(my) * 0.8
      local curl = math.sin(math.atan(my, mx) * 4) * 2.5
      if r + curl < 13 then col = motif end
      if math.abs(r + curl - 13) < 0.8 then col = edge end
      if math.abs(mx) < 1 and math.abs(my) < 6 then col = edge end
      c:px(x, y, col)
    end
  end
  for _, px0 in ipairs({ 120, 376 }) do
    for y = 0, H - 1 do
      for i = 0, 15 do
        local col = gold[2]
        if i == 0 or i == 15 then col = gold[1] elseif i == 2 or i == 13 then col = gold[4] elseif i == 7 or i == 8 then col = gold[1] end
        if (i >= 4 and i <= 11) and (i ~= 7 and i ~= 8) then col = (y % 6 == 0) and gold[1] or gold[3] end
        c:px(px0 + i, y, col)
      end
    end
  end
  c:save("bg_royal")
end

-- Summit: night sky over the city, a fat moon, stars.
do
  local c = A.canvas(W, H)
  local sky = { "070818", "0c0e24", "141432", "1e1a40", "2c2250", "40305e" }
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      c:px(x, y, A.ramp(sky, y / H * 1.05, x, y))
    end
  end
  for i = 0, 140 do
    local x = math.floor(A.hash(i, 1, 41) * W)
    local y = math.floor(A.hash(i, 2, 41) * H * 0.75)
    local b = A.hash(i, 3, 41)
    c:px(x, y, b > 0.85 and "fff6d8" or (b > 0.5 and "a8a8d0" or "5a5a88"))
    if b > 0.95 then c:px(x - 1, y, "5a5a88"); c:px(x + 1, y, "5a5a88"); c:px(x, y - 1, "5a5a88"); c:px(x, y + 1, "5a5a88") end
  end
  -- Moon with craters and a soft halo.
  c:disc(408, 64, 40, "1c1a44"); c:disc(408, 64, 32, "26244e")
  c:disc(408, 64, 24, "f2ead0"); c:disc(414, 60, 24, "f2ead0")
  c:disc(400, 58, 5, "d8cfb2"); c:disc(418, 74, 4, "d8cfb2"); c:disc(422, 52, 3, "d8cfb2")
  for y = 40, 88 do for x = 384, 432 do
    local dx, dy = x + 0.5 - 408, y + 0.5 - 64
    if dx * dx + dy * dy <= 24 * 24 and dx < -14 + dy * 0.2 and A.bayer(x, y) > 0.4 then c:px(x, y, "c8bea0") end
  end end
  -- City skyline: two depths of towers with lit windows.
  for layer = 1, 2 do
    local col = layer == 1 and "1a1636" or "0e0c22"
    local x = 0
    local seed = layer * 17
    while x < W do
      local w = 18 + math.floor(A.hash(x, seed, 7) * 30)
      local h = (layer == 1 and 40 or 20) + math.floor(A.hash(x, seed, 9) * (layer == 1 and 50 or 40))
      c:rect(x, H - h, w - 2, h, col)
      for wy = H - h + 4, H - 4, 6 do for wx = x + 3, x + w - 6, 5 do
        if A.hash(wx, wy, seed) > 0.72 then c:rect(wx, wy, 2, 3, layer == 1 and "6a5a3a" or "c8a050") end
      end end
      x = x + w
    end
  end
  c:save("bg_summit")
end

print("Backgrounds exported.")
