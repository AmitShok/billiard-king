-- Billiard King: UI pieces.
--   panel.png      24x24 nine-slice: walnut frame, felt inset (8px margins)
--   panel_focus.png 24x24 brass-edged variant for focused buttons
--   spin_icon.png  5 frames of 13x13: cue-ball strike point, draw 2 .. follow 2
--   aseprite -b --script-param root=<project> --script tools/art_ui.lua
local A = dofile(app.params["root"] .. "/tools/art_lib.lua")

local function panel(name, edge_hi, edge, felt)
  local c = A.canvas(24, 24)
  local wood = { "1a0e08", "3a2014", "5a3420", "7a4a2c" }
  c:rect(0, 0, 24, 24, wood[1])
  c:rect(1, 1, 22, 22, wood[3])
  c:hline(1, 22, 1, wood[4]); c:vline(1, 1, 22, wood[4])
  c:hline(1, 22, 22, wood[2]); c:vline(22, 1, 22, wood[2])
  c:rect(4, 4, 16, 16, edge)
  c:hline(4, 19, 4, edge_hi); c:vline(4, 4, 19, edge_hi)
  c:rect(5, 5, 14, 14, felt[1])
  for y = 5, 18 do for x = 5, 18 do
    if A.hash(x, y, 12) > 0.8 then c:px(x, y, felt[2]) end
  end end
  c:hline(5, 18, 5, "0a0806")
  c:px(2, 2, "f2e6c4"); c:px(21, 2, "f2e6c4"); c:px(2, 21, "f2e6c4"); c:px(21, 21, "f2e6c4")
  c:save(name)
end
panel("panel", "2a1a10", "120a06", { "16382a", "1a4030" })
panel("panel_focus", "fff0a8", "c49a40", { "1e5038", "225840" })

do
  local c = A.canvas(13 * 5, 13)
  for f = 0, 4 do
    local ox = f * 13
    c:disc(ox + 6.5, 6.5, 6, "1c1a1f"); c:disc(ox + 6.5, 6.5, 5, "f4eedc")
    c:px(ox + 4, 4, "ffffff")
    c:hline(ox + 3, ox + 9, 6, "d8d0bc")
    local dy = ({ 3, 1.5, 0, -1.5, -3 })[f + 1]
    c:disc(ox + 6.5, 6.5 + dy, 1.5, "c8302e")
  end
  c:save("spin_icon")
end
print("UI exported.")

-- Game icon (64x64): a black 8-ball wearing a gold crown.
do
  local c = A.canvas(64, 64)
  local cx, cy, r = 32, 38, 25
  local black = { "050507", "0e0e12", "1a1a20", "2a2a33", "3e3e4a" }
  for y = 0, 63 do for x = 0, 63 do
    local dx, dy = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
    local d2 = dx * dx + dy * dy
    if d2 <= 1 then
      local nz = math.sqrt(1 - d2)
      local lit = math.max(0, -dx * 0.5 - dy * 0.6 + nz * 0.62)
      local col = A.ramp(black, lit * 0.95, x, y)
      if d2 > 0.82 and dx + dy > 0.6 then col = "22222c" end
      c:px(x, y, col)
    end
  end end
  -- White number disc and a bold "8".
  local ox, oy = 30, 40
  c:disc(ox, oy, 11.5, "c8c2b4")
  c:disc(ox - 0.5, oy - 0.5, 10.5, "f4eedc")
  for y = oy - 11, oy + 11 do for x = ox - 11, ox + 11 do
    local dx, dy = x + 0.5 - ox, y + 0.5 - oy
    if dx * dx + dy * dy <= 10.5 * 10.5 and dx + dy > 7.5 then c:px(x, y, "ddd6c4") end
  end end
  c:grid(ox - 5, oy - 7, {
    ".######.",
    "###..###",
    "###..###",
    ".######.",
    ".######.",
    "###..###",
    "###..###",
    "###..###",
    ".######.",
  }, { ["#"] = "141418" })
  c:disc(20, 24, 2.5, "6a6a78"); c:disc(19.5, 23.5, 1.3, "f0f0f8")
  c:ring(cx, cy, r + 0.5, "000000")

  -- Gold crown sitting on top of the ball, slightly tipped back.
  local crown = {
    "....e.........e.........e....",
    "...eae.......eae.......eae...",
    "....a.........a.........a....",
    "....aa.......aaa.......aa....",
    "...aaaa.....aaaaa.....aaaa...",
    "...aabaa...aaabaaa...aabaa...",
    "..aaaaaaa.aaaaaaaaa.aaaaaaa..",
    "..aaaaaaaaaaaaaaaaaaaaaaaaa..",
    "..aaaaaaaaaaaaaaaaaaaaaaaaa..",
    "..bbbbbbbbbbbbbbbbbbbbbbbbb..",
    "..cccdccccccfccccccdccccccc..",
    "..ccdddcccccfffcccdddcccccc..",
    "..cccdccccccfccccccdccccccc..",
    "..bbbbbbbbbbbbbbbbbbbbbbbbb..",
  }
  c:grid(18, 3, crown, { a = "f2c440", b = "a87818", c = "d8a830", d = "c8302e", e = "fff6c0", f = "3a7ad8" })
  -- Shine down the left of the band and points.
  for y = 9, 15 do c:px(21, y, "ffe890") end
  c:outline("11090c", 16, 1, 33, 18)
  c:save("game_icon")
end
