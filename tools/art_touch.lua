-- Vertical Billiard: on-screen buttons for touchscreens (phones and tablets).
--   touch_buttons (280x56) ten 28x28 round brass buttons; top row idle, bottom row pressed.
--     columns: aim left, aim right, spin up, spin down, look up, look down,
--              pause, plant flag, back to flag, remove flag
--   touch_strike  (88x44)  the big strike button; idle, pressed
-- The game shows them only on touch devices (see scripts/ui/touch_controls.gd).
--   aseprite -b --script-param root=<project> --script tools/art_touch.lua
local A = dofile(app.params["root"] .. "/tools/art_lib.lua")
local OUT = "11090c"

-- Round brass rim (light on top, dark below) around a disc of felt.
local function base(c, ox, oy, size, pressed)
  local cx, cy, r = ox + size / 2, oy + size / 2, size / 2 - 1
  c:disc(cx, cy, r, OUT)
  c:disc(cx, cy + 0.5, r - 1, pressed and "c08a3a" or "8a5a22")
  c:disc(cx, cy - 0.5, r - 1, pressed and "f6e2a0" or "d8a84c")
  c:disc(cx, cy, r - 2.5, OUT)
  c:disc(cx, cy, r - 3, pressed and "2fae5a" or "1d4a32")
  -- A soft sheen on the upper left of the felt.
  local fr = r - 3
  for y = oy, oy + size - 1 do
    for x = ox, ox + size - 1 do
      local dx, dy = x + 0.5 - cx, y + 0.5 - cy
      local d = math.sqrt(dx * dx + dy * dy)
      if d < fr - 1 and dx + dy < -fr * 0.7 and A.bayer(x, y) < 0.5 then
        c:px(x, y, pressed and "52c878" or "2a6444")
      end
    end
  end
end

local function flip_x(rows)
  local out = {}
  for i, r in ipairs(rows) do out[i] = r:reverse() end
  return out
end

local function flip_y(rows)
  local out = {}
  for i = #rows, 1, -1 do out[#out + 1] = rows[i] end
  return out
end

local ARROW = {
  "......a....",
  ".....aa....",
  "....aaa....",
  "...aaaaaaa.",
  "..aaaaaaaa.",
  ".aaaaaaaaa.",
  "..aaaaaaaa.",
  "...aaaaaaa.",
  "....aaa....",
  ".....aa....",
  "......a....",
}
local SPIN = {
  ".....a.....",
  "....aaa....",
  "...aa.aa...",
  "..aa...aa..",
  "...........",
  "....bbb....",
  "...bbbbb...",
  "...bbcbb...",
  "...bbbbb...",
  "....bbb....",
  "...........",
}
local LOOK = {
  ".....a.....",
  "....aaa....",
  "...a.a.a...",
  ".....a.....",
  "...........",
  "...bbbbb...",
  ".bb.....bb.",
  "b...ccc...b",
  ".bb.....bb.",
  "...bbbbb...",
  "...........",
}
local PAUSE = {
  "...........",
  "...........",
  "..aaa.aaa..",
  "..aaa.aaa..",
  "..aaa.aaa..",
  "..aaa.aaa..",
  "..aaa.aaa..",
  "..aaa.aaa..",
  "..aaa.aaa..",
  "...........",
  "...........",
}
local PLANT = {
  ".a.........",
  ".abbbb.....",
  ".abbbbb....",
  ".abbbb.....",
  ".a.....c...",
  ".a.....c...",
  ".a...ccccc.",
  ".a.....c...",
  ".a.....c...",
  "aaa........",
  "...........",
}
local RETURN = {
  ".a.........",
  ".abbbb.....",
  ".abbbbb....",
  ".abbbb.....",
  ".a...c.....",
  ".a..cc.....",
  ".a.cccccc..",
  ".a..cc...c.",
  ".a...c...c.",
  "aaa....cc..",
  "...........",
}
local REMOVE = {
  ".a.........",
  ".abbbb.....",
  ".abbbbb....",
  ".abbbb.....",
  ".a.........",
  ".a...d...d.",
  ".a....d.d..",
  ".a.....d...",
  ".a....d.d..",
  "aaa..d...d.",
  "...........",
}

local ICONS = {
  ARROW, flip_x(ARROW), SPIN, flip_y(SPIN), LOOK, flip_y(LOOK),
  PAUSE, PLANT, RETURN, REMOVE,
}

do
  local c = A.canvas(280, 56)
  for row = 0, 1 do
    local pressed = row == 1
    local pal = {
      a = pressed and "ffffff" or "f4eedc",
      b = pressed and "ffffff" or "f4eedc",
      c = "e04848",
      d = "e04848",
    }
    for i, icon in ipairs(ICONS) do
      local ox, oy = (i - 1) * 28, row * 28
      base(c, ox, oy, 28, pressed)
      local p = pal
      if icon == PLANT or icon == RETURN or icon == REMOVE then
        p = { a = pal.a, b = pressed and "9ff0b4" or "2fae5a", c = "f2d27a", d = "e04848" }
      end
      -- The icon sits in the middle, nudged up a pixel when idle so it "presses in".
      c:grid(ox + 9, oy + (pressed and 9 or 8), icon, p)
    end
  end
  c:save("touch_buttons")
end

-- The strike button: a cue driving into the cue ball.
do
  local c = A.canvas(88, 44)
  for f = 0, 1 do
    local ox = f * 44
    local pressed = f == 1
    base(c, ox, 0, 44, pressed)
    local push = pressed and 2 or 0
    -- Cue: a 3px shaft from the lower left (dark butt, tan shaft) with a chalked tip.
    for t = 0, 16 do
      local x, y = ox + 7 + t + push, 37 - t - push
      local butt = t < 5
      c:px(x, y - 1, butt and "7a5028" or "f0d8a8")
      c:px(x, y, butt and "5a3a1a" or "e0c08a")
      c:px(x + 1, y, butt and "3a2410" or "b8945a")
    end
    c:px(ox + 24 + push, 20 - push, "4c8cc0")
    c:px(ox + 24 + push, 19 - push, "8ad0f0")
    c:px(ox + 25 + push, 20 - push, "2a5a8a")
    -- Cue ball, touching the tip; pushed further when pressed.
    local bx, by = ox + 29.5 + push, 14.5 - push
    c:disc(bx, by, 6.5, OUT)
    c:disc(bx, by, 5.5, pressed and "ffffff" or "f4eedc")
    c:px(math.floor(bx) - 2, math.floor(by) - 3, "ffffff")
    c:px(math.floor(bx) - 3, math.floor(by) - 2, "ffffff")
    if pressed then
      -- Impact lines.
      c:px(ox + 38, 9, "f2d27a"); c:px(ox + 39, 8, "f2d27a")
      c:px(ox + 39, 14, "f2d27a"); c:px(ox + 40, 14, "f2d27a")
    end
  end
  c:save("touch_strike")
end

print("Touch button art exported.")
