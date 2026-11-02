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

-- Game icon (64x64): a crowned cue ball on green felt.
do
  local c = A.canvas(64, 64)
  c:disc(32, 34, 31, "11090c"); c:disc(32, 34, 30, "1e5a38"); c:disc(31, 33, 27, "2a7a4c")
  for y = 0, 63 do for x = 0, 63 do
    local dx, dy = x + 0.5 - 32, y + 0.5 - 40
    local d = math.sqrt(dx * dx + dy * dy)
    if d <= 18 then
      local l = (-dx * 0.55 - dy * 0.65) / 18
      local col = l > 0.45 and "ffffff" or (l > 0.1 and "f4eedc" or (l > -0.3 and "d8cfb8" or "a89e8a"))
      if d > 17 then col = "1c1a1f" end
      c:px(x, y, col)
    end
  end end
  c:disc(38, 45, 3.5, "c8302e"); c:disc(24, 37, 2.2, "a82826")
  c:px(25, 30, "ffffff"); c:px(26, 30, "ffffff"); c:px(25, 31, "ffffff")
  local crown = {
    "..e.......e.......e..",
    ".eae.....eae.....eae.",
    "..a.......a.......a..",
    "..aa.....aaa.....aa..",
    ".aaaa...aaaaa...aaaa.",
    ".aabaa.aaabaaa.aabaa.",
    "aaaaaaaaaaaaaaaaaaaaa",
    "aaaaaaaaaaaaaaaaaaaaa",
    "bbbbbbbbbbbbbbbbbbbbb",
    "cdcccdcccdcccdcccdccc",
    "bbbbbbbbbbbbbbbbbbbbb",
  }
  c:grid(22, 9, crown, { a = "f2c440", b = "b08020", c = "d8a830", d = "c8302e", e = "fff6c0" })
  c:outline("11090c", 20, 6, 25, 16)
  c:save("game_icon")
end
