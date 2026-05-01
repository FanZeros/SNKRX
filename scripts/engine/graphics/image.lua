-- SNKRX Engine Image Module - NanoVG Adapter
-- Replaces LÖVE2D's love.graphics.newImage with NanoVG image loading.

Image = Object:extend()
function Image:init(asset_name)
  self.w = 0
  self.h = 0
  self.nvg_image = 0
  if not vg then
    print("[Image] WARNING: vg is nil, cannot load image: " .. tostring(asset_name))
    return
  end
  -- Load image via NanoVG, try multiple paths
  local paths = {
    "images/" .. asset_name .. ".png",
    "Images/" .. asset_name .. ".png",
  }
  for _, img_path in ipairs(paths) do
    local ok, result = pcall(nvgCreateImage, vg, img_path, 0)
    if ok and result and result > 0 then
      self.nvg_image = result
      break
    end
  end
  -- Query image dimensions
  if self.nvg_image > 0 then
    local ok, iw, ih = pcall(nvgImageSize, vg, self.nvg_image)
    if ok and iw then
      self.w = iw
      self.h = ih
    end
  else
    print("[Image] WARNING: Failed to load image: " .. asset_name)
  end
end


function Image:draw(x, y, r, sx, sy, ox, oy, color)
  if not self.nvg_image or self.nvg_image <= 0 then return end
  if color then
    graphics.set_color(color)
  end
  nvgSave(vg)
  nvgTranslate(vg, x, y)
  if r and r ~= 0 then nvgRotate(vg, r) end
  local isx = sx or 1
  local isy = sy or isx
  if isx ~= 1 or isy ~= 1 then nvgScale(vg, isx, isy) end
  local draw_ox = self.w / 2 + (ox or 0)
  local draw_oy = self.h / 2 + (oy or 0)

  local paint
  if color then
    local tint = nvgRGBAf(color.r, color.g, color.b, color.a or 1)
    paint = nvgImagePatternTinted(vg, -draw_ox, -draw_oy, self.w, self.h, 0, self.nvg_image, tint)
  else
    paint = nvgImagePattern(vg, -draw_ox, -draw_oy, self.w, self.h, 0, self.nvg_image, 1)
  end
  nvgBeginPath(vg)
  nvgRect(vg, -draw_ox, -draw_oy, self.w, self.h)
  nvgFillPaint(vg, paint)
  nvgFill(vg)
  nvgRestore(vg)
end


-- Quad class: a sub-region of an Image, used for spritesheets.
Quad = Object:extend()
function Quad:init(image, tile_w, tile_h, tile_coordinates)
  self.source_image = image
  self.w, self.h = tile_w, tile_h
  -- tile_coordinates is {col, row}, 1-based
  self.src_x = (tile_coordinates[1] - 1) * tile_w
  self.src_y = (tile_coordinates[2] - 1) * tile_h
  -- Create a sub-image for this quad region via NanoVG
  -- NanoVG doesn't natively support quads/sub-images, so we use clipping + offset
  self.nvg_image = image.nvg_image
end


function Quad:draw(x, y, r, sx, sy, ox, oy)
  if not self.nvg_image or self.nvg_image <= 0 then return end
  nvgSave(vg)
  nvgTranslate(vg, x, y)
  if r and r ~= 0 then nvgRotate(vg, r) end
  local isx = sx or 1
  local isy = sy or isx
  if isx ~= 1 or isy ~= 1 then nvgScale(vg, isx, isy) end
  local draw_ox = self.w / 2 + (ox or 0)
  local draw_oy = self.h / 2 + (oy or 0)
  -- Use NanoVG scissor to clip to the quad region and shift the image pattern
  local src_img = self.source_image
  local paint = nvgImagePattern(vg,
    -draw_ox - self.src_x, -draw_oy - self.src_y,
    src_img.w, src_img.h, 0, self.nvg_image, 1)
  nvgBeginPath(vg)
  nvgRect(vg, -draw_ox, -draw_oy, self.w, self.h)
  nvgFillPaint(vg, paint)
  nvgFill(vg)
  nvgRestore(vg)
end


-- GradientImage: renders a linear gradient as a rectangle.
-- Uses NanoVG's built-in linear gradient.
GradientImage = Object:extend()
function GradientImage:init(direction, ...)
  local colors = {...}
  self.direction = direction
  self.colors = colors
end


function GradientImage:draw(x, y, w, h, r, sx, sy, ox, oy)
  nvgSave(vg)
  nvgTranslate(vg, x, y)
  if r and r ~= 0 then nvgRotate(vg, r) end
  local isx = sx or 1
  local isy = sy or isx
  local gw = w * isx
  local gh = h * isy
  local gx = -gw / 2 - (ox or 0)
  local gy = -gh / 2 - (oy or 0)

  -- NanoVG only supports 2-stop linear gradients natively.
  -- For multi-stop, we draw segments.
  if #self.colors >= 2 then
    local n = #self.colors - 1
    for i = 1, n do
      local c1 = self.colors[i]
      local c2 = self.colors[i + 1]
      local col1 = nvgRGBAf(c1.r, c1.g, c1.b, c1.a or 1)
      local col2 = nvgRGBAf(c2.r, c2.g, c2.b, c2.a or 1)
      local paint
      if self.direction == "horizontal" then
        local seg_x = gx + (i - 1) / n * gw
        local seg_w = gw / n
        paint = nvgLinearGradient(vg, seg_x, gy, seg_x + seg_w, gy, col1, col2)
        nvgBeginPath(vg)
        nvgRect(vg, seg_x, gy, seg_w, gh)
      else -- vertical
        local seg_y = gy + (i - 1) / n * gh
        local seg_h = gh / n
        paint = nvgLinearGradient(vg, gx, seg_y, gx, seg_y + seg_h, col1, col2)
        nvgBeginPath(vg)
        nvgRect(vg, gx, seg_y, gw, seg_h)
      end
      nvgFillPaint(vg, paint)
      nvgFill(vg)
    end
  end

  nvgRestore(vg)
end
