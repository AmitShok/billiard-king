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

-- Game icon (64x64): a classic black 8-ball, lit from the top left.
do
  local c = A.canvas(64, 64)
  local cx, cy, r = 32, 32, 30
  local black = { "050507", "0e0e12", "1a1a20", "2a2a33", "3e3e4a" }
  for y = 0, 63 do for x = 0, 63 do
    local dx, dy = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
    local d2 = dx * dx + dy * dy
    if d2 <= 1 then
      local nz = math.sqrt(1 - d2)
      local lit = math.max(0, -dx * 0.5 - dy * 0.6 + nz * 0.62)
      local col = A.ramp(black, lit * 0.95, x, y)
      -- Faint bounce light along the lower right rim.
      if d2 > 0.82 and dx + dy > 0.6 then col = "22222c" end
      c:px(x, y, col)
    end
  end end
  -- White number disc, set a little up-left of centre like a ball turned toward the light.
  local ox, oy = 29, 28
  c:disc(ox, oy, 13.5, "c8c2b4")
  c:disc(ox - 0.5, oy - 0.5, 12.5, "f4eedc")
  for y = oy - 13, oy + 13 do for x = ox - 13, ox + 13 do
    local dx, dy = x + 0.5 - ox, y + 0.5 - oy
    if dx * dx + dy * dy <= 12.5 * 12.5 and dx + dy > 9 then c:px(x, y, "ddd6c4") end
  end end
  -- A bold pixel "8".
  c:grid(ox - 6, oy - 9, {
    "..######..",
    ".########.",
    "###....###",
    "###....###",
    ".########.",
    ".########.",
    "###....###",
    "###....###",
    "###....###",
    ".########.",
    "..######..",
  }, { ["#"] = "141418" })
  -- Specular glint and rim.
  c:disc(17, 15, 3, "6a6a78"); c:disc(16.5, 14.5, 1.6, "f0f0f8")
  c:ring(cx, cy, r + 0.5, "000000")
  c:save("game_icon")
end
