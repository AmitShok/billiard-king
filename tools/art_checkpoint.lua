-- Vertical Billiard: Training mode checkpoint flag.
--   flag_pole   (7x30)  brass pole with a cue-ball finial and a chalk-cube foot
--   flag_cloth  (16x10, 2 frames) felt pennant with a cue-ball emblem: lit (newest flag) / faded (older flags)
--   spark_green (15x5, 3 frames) sparks when a flag is planted
-- The cloth waves in code (CheckpointFlag shifts each 1px column), so it moves with the wind.
--   aseprite -b --script-param root=<project> --script tools/art_checkpoint.lua
local A = dofile(app.params["root"] .. "/tools/art_lib.lua")
local OUT = "11090c"

-- Pole: finial on top, brass shaft, chalk cube at the foot.
do
  local c = A.canvas(7, 30)
  c:grid(0, 0, {
    "..aaa..",
    ".abbba.",
    ".abcba.",
    ".abbba.",
    "..aaa..",
  }, { a = OUT, b = "f4eedc", c = "ffffff" })
  for y = 5, 25 do
    c:px(2, y, OUT)
    c:px(3, y, y % 6 == 1 and "f6e2a0" or "d8a84c")
    c:px(4, y, "8a5a22")
  end
  c:grid(0, 25, {
    "aaaaaaa",
    "abbbbca",
    "abbbbca",
    "acccdda",
    "aaaaaaa",
  }, { a = OUT, b = "8ad0f0", c = "4c8cc0", d = "2a5a8a" })
  c:save("flag_pole")
end

-- Cloth: two frames side by side.
do
  local c = A.canvas(32, 10)
  local function cloth(ox, felt, dark, trim, ball)
    for y = 1, 8 do for x = 0, 14 do
      -- Swallowtail pennant: the fly end is notched.
      local notch = x >= 11 and math.abs(y - 4.5) < (x - 10) * 0.8
      if not notch then
        local col = felt
        if y == 1 or y == 8 then col = trim
        elseif (x + y) % 5 == 0 then col = dark end
        c:px(ox + x, y, col)
      end
    end end
    c:disc(ox + 5, 4.5, 2.2, ball)
    c:px(ox + 4, 3, "ffffff")
  end
  cloth(0, "2fae5a", "238a46", "f2d27a", "f4eedc")
  cloth(16, "4a6a56", "3c5848", "8a7a5a", "a8a496")
  c:outline(OUT, 0, 0, 16, 10)
  c:outline(OUT, 16, 0, 16, 10)
  c:save("flag_cloth")
end

-- Green sparks (3 frames of 5x5).
do
  local c = A.canvas(15, 5)
  c:grid(0, 0, { "..a..", ".aba.", "abcba", ".aba.", "..a.." }, { a = "2fae5a", b = "9ff0b4", c = "ffffff" })
  c:grid(5, 0, { ".....", "..a..", ".aba.", "..a..", "....." }, { a = "2fae5a", b = "ffffff" })
  c:grid(10, 0, { ".....", ".....", "..a..", ".....", "....." }, { a = "9ff0b4" })
  c:save("spark_green")
end

print("Checkpoint art exported.")
