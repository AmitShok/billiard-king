-- Vertical Billiard: shared helpers for the hand-authored pixel art.
-- Every script builds a real .aseprite source in assets/source/ and exports
-- the PNG the game loads from assets/textures/. Drawing is deterministic
-- (fixed-seed hash noise) so re-running a script reproduces the same art.
--   aseprite -b --script-param root=<project> --script tools/<script>.lua

local M = {}

M.root = app.params["root"] or "."

function M.hex(h, a)
  local r = tonumber(h:sub(1, 2), 16)
  local g = tonumber(h:sub(3, 4), 16)
  local b = tonumber(h:sub(5, 6), 16)
  local alpha = a or (#h >= 8 and tonumber(h:sub(7, 8), 16)) or 255
  return app.pixelColor.rgba(r, g, b, alpha)
end

-- Canvas wraps one Aseprite sprite + image with clipped drawing helpers.
local Canvas = {}
Canvas.__index = Canvas

function M.canvas(w, h)
  local spr = Sprite(w, h, ColorMode.RGB)
  local c = setmetatable({ spr = spr, img = spr.cels[1].image, w = w, h = h }, Canvas)
  return c
end

function Canvas:px(x, y, col, a)
  x = math.floor(x); y = math.floor(y)
  if x < 0 or y < 0 or x >= self.w or y >= self.h then return end
  if type(col) == "string" then col = M.hex(col, a) end
  self.img:drawPixel(x, y, col)
end

function Canvas:get(x, y)
  if x < 0 or y < 0 or x >= self.w or y >= self.h then return 0 end
  return self.img:getPixel(x, y)
end

function Canvas:alpha_at(x, y)
  return app.pixelColor.rgbaA(self:get(x, y))
end

function Canvas:rect(x, y, w, h, col, a)
  local c = type(col) == "string" and M.hex(col, a) or col
  for yy = y, y + h - 1 do
    for xx = x, x + w - 1 do self:px(xx, yy, c) end
  end
end

function Canvas:hline(x0, x1, y, col) self:rect(math.min(x0, x1), y, math.abs(x1 - x0) + 1, 1, col) end
function Canvas:vline(x, y0, y1, col) self:rect(x, math.min(y0, y1), 1, math.abs(y1 - y0) + 1, col) end

function Canvas:line(x0, y0, x1, y1, col)
  x0, y0, x1, y1 = math.floor(x0), math.floor(y0), math.floor(x1), math.floor(y1)
  local dx, dy = math.abs(x1 - x0), -math.abs(y1 - y0)
  local sx, sy = x0 < x1 and 1 or -1, y0 < y1 and 1 or -1
  local err = dx + dy
  while true do
    self:px(x0, y0, col)
    if x0 == x1 and y0 == y1 then break end
    local e2 = 2 * err
    if e2 >= dy then err = err + dy; x0 = x0 + sx end
    if e2 <= dx then err = err + dx; y0 = y0 + sy end
  end
end

-- Filled disc centred on (cx, cy); half-pixel centres give round small discs.
function Canvas:disc(cx, cy, r, col, a)
  local c = type(col) == "string" and M.hex(col, a) or col
  for y = math.floor(cy - r - 1), math.ceil(cy + r + 1) do
    for x = math.floor(cx - r - 1), math.ceil(cx + r + 1) do
      local dx, dy = x + 0.5 - cx, y + 0.5 - cy
      if dx * dx + dy * dy <= r * r then self:px(x, y, c) end
    end
  end
end

function Canvas:ring(cx, cy, r, col)
  for y = math.floor(cy - r - 1), math.ceil(cy + r + 1) do
    for x = math.floor(cx - r - 1), math.ceil(cx + r + 1) do
      local dx, dy = x + 0.5 - cx, y + 0.5 - cy
      local d = math.sqrt(dx * dx + dy * dy)
      if d <= r and d > r - 1 then self:px(x, y, col) end
    end
  end
end

function Canvas:ellipse(cx, cy, rx, ry, col)
  for y = math.floor(cy - ry - 1), math.ceil(cy + ry + 1) do
    for x = math.floor(cx - rx - 1), math.ceil(cx + rx + 1) do
      local dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
      if dx * dx + dy * dy <= 1 then self:px(x, y, col) end
    end
  end
end

-- Draws a 1px dark outline around every opaque pixel (outside only).
function Canvas:outline(col, x0, y0, w, h)
  x0, y0, w, h = x0 or 0, y0 or 0, w or self.w, h or self.h
  local marks = {}
  for y = y0, y0 + h - 1 do
    for x = x0, x0 + w - 1 do
      if self:alpha_at(x, y) == 0 then
        local near = false
        for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
          local nx, ny = x + d[1], y + d[2]
          if nx >= x0 and ny >= y0 and nx < x0 + w and ny < y0 + h and self:alpha_at(nx, ny) > 0 then near = true end
        end
        if near then marks[#marks + 1] = { x, y } end
      end
    end
  end
  for _, m in ipairs(marks) do self:px(m[1], m[2], col) end
end

-- Draws a grid of characters with a palette table ("." is transparent).
function Canvas:grid(ox, oy, rows, pal)
  for y, row in ipairs(rows) do
    for x = 1, #row do
      local ch = row:sub(x, x)
      if ch ~= "." and ch ~= " " then
        local col = pal[ch]
        if not col then error("unknown palette key '" .. ch .. "'") end
        self:px(ox + x - 1, oy + y - 1, col)
      end
    end
  end
end

function Canvas:save(name, subdir)
  subdir = subdir or "textures"
  self.spr:saveAs(M.root .. "/assets/source/" .. name .. ".aseprite")
  self.spr:saveCopyAs(M.root .. "/assets/" .. subdir .. "/" .. name .. ".png")
  self.spr:close()
end

-- Deterministic integer hash noise in [0, 1).
function M.hash(x, y, seed)
  local n = (x * 374761393 + y * 668265263 + (seed or 0) * 2246822519) % 4294967296
  n = ((n ~ (n >> 13)) * 1274126177) % 4294967296
  n = n ~ (n >> 16)
  return (n % 100000) / 100000
end

-- Ordered 4x4 Bayer threshold in [0, 1) for dithered gradients.
local BAYER = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 }
function M.bayer(x, y)
  return (BAYER[(y % 4) * 4 + (x % 4) + 1] + 0.5) / 16
end

-- Picks from a colour ramp at t in [0,1] with ordered dithering between steps.
function M.ramp(ramp, t, x, y)
  t = math.max(0, math.min(0.9999, t))
  local f = t * (#ramp - 1)
  local i = math.floor(f)
  local frac = f - i
  if frac > M.bayer(x, y) then i = i + 1 end
  return ramp[math.min(#ramp, i + 1)]
end

return M
