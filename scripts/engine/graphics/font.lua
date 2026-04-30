-- SNKRX Engine Font Module - NanoVG Adapter
-- Replaces LÖVE2D's love.graphics.newFont with NanoVG font creation.

Font = Object:extend()
function Font:init(asset_name, font_size)
  self.size = font_size or 16
  self.name = asset_name
  -- NanoVG font creation: nvgCreateFont(ctx, name, path)
  -- Asset path follows SNKRX convention: "assets/fonts/<name>.ttf"
  -- In UrhoX, resources are loaded relative to resource path, so we use "Fonts/<name>.ttf" as fallback
  local font_path = "fonts/" .. asset_name .. ".ttf"
  self.font_id = nvgCreateFont(vg, asset_name, font_path)
  if self.font_id < 0 then
    -- Try alternate path with uppercase
    font_path = "Fonts/" .. asset_name .. ".ttf"
    self.font_id = nvgCreateFont(vg, asset_name .. "_alt", font_path)
  end
  if self.font_id < 0 then
    -- Try MiSans as fallback
    font_path = "Fonts/MiSans-Regular.ttf"
    self.font_id = nvgCreateFont(vg, asset_name .. "_fallback", font_path)
    print(string.format("[Font] FALLBACK for '%s' -> MiSans, id=%d", asset_name, self.font_id))
  else
    print(string.format("[Font] Loaded '%s' from '%s', id=%d, size=%d", asset_name, font_path, self.font_id, font_size))
  end
  -- Approximate line height (NanoVG doesn't have a direct getHeight equivalent)
  -- We use font_size * 1.2 as a reasonable approximation
  self.h = math.ceil(font_size * 1.2)
end


function Font:get_text_width(text)
  if not text or text == "" then return 0 end
  nvgFontFaceId(vg, self.font_id)
  nvgFontSize(vg, self.size)
  -- nvgTextBounds returns advance width (only works inside nvgBeginFrame/nvgEndFrame)
  local advance = nvgTextBounds(vg, 0, 0, tostring(text))
  return advance or 0
end


function Font:get_height()
  return self.h
end
