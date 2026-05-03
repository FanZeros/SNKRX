---@diagnostic disable: undefined-global
-- SNKRX Engine Tileset Module - NanoVG Adapter
-- Loads a tileset image and provides quad-based tile drawing.
-- Uses the same NanoVG image pattern + clipping approach as Quad.

Tileset = Object:extend()
function Tileset:init(image, tile_w, tile_h)
  self.image = image
  self.tile_w, self.tile_h = tile_w, tile_h
  self.w = math.floor(self.image.w / self.tile_w)
  self.h = math.floor(self.image.h / self.tile_h)
  -- Build a 2D table of source coordinates for each tile
  self.tiles = {}
  for j = 1, self.h do
    for i = 1, self.w do
      local idx = (j - 1) * self.w + i
      self.tiles[idx] = {
        src_x = (i - 1) * self.tile_w,
        src_y = (j - 1) * self.tile_h,
      }
    end
  end
end


-- Draws a tile by its 1D index (1-based).
function Tileset:draw_tile(index, x, y, r, sx, sy, ox, oy)
  local tile = self.tiles[index]
  if not tile then return end
  local src = self.image
  if not src or not src.nvg_image or src.nvg_image <= 0 then return end

  nvgSave(vg)
  nvgTranslate(vg, x or 0, y or 0)
  if r and r ~= 0 then nvgRotate(vg, r) end
  local isx = sx or 1
  local isy = sy or isx
  if isx ~= 1 or isy ~= 1 then nvgScale(vg, isx, isy) end

  local paint = nvgImagePattern(vg,
    -(ox or 0) - tile.src_x, -(oy or 0) - tile.src_y,
    src.w, src.h, 0, src.nvg_image, 1)
  nvgBeginPath(vg)
  nvgRect(vg, -(ox or 0), -(oy or 0), self.tile_w, self.tile_h)
  nvgFillPaint(vg, paint)
  nvgFill(vg)
  nvgRestore(vg)
end


-- Returns the tile data at the given index for manual drawing.
function Tileset:get_tile(index)
  return self.tiles[index]
end
