---@diagnostic disable: undefined-global
-- SNKRX Engine Font Module - NanoVG Adapter
-- Replaces LÖVE2D's love.graphics.newFont with NanoVG font creation.

Font = Object:extend()
function Font:init(asset_name, font_size)
  self.size = font_size or 16
  self.name = asset_name
  self.h = math.ceil((font_size or 16) * 1.2)
  if not vg then
    print(string.format("[Font] WARNING: vg is nil, cannot create font: %s", tostring(asset_name)))
    self.font_id = -1
    return
  end

  -- Try multiple paths to find the font file
  local paths = {
    "fonts/" .. asset_name .. ".ttf",
    "Fonts/" .. asset_name .. ".ttf",
    "fonts/" .. asset_name .. ".otf",
    "Fonts/" .. asset_name .. ".otf",
  }
  for i, font_path in ipairs(paths) do
    local tag = asset_name .. (i > 1 and ("_p" .. i) or "")
    self.font_id = nvgCreateFont(vg, tag, font_path)
    if self.font_id >= 0 then
      print(string.format("[Font] Loaded '%s' from '%s', id=%d, size=%d", asset_name, font_path, self.font_id, font_size))
      return
    end
  end

  -- Fallback: use engine built-in MiSans font (always available)
  self._is_fallback = true  -- mark as fallback so retry can be attempted later
  self._asset_name = asset_name
  self.font_id = nvgCreateFont(vg, asset_name .. "_misans", "Fonts/MiSans-Regular.ttf")
  if self.font_id >= 0 then
    print(string.format("[Font] FALLBACK for '%s' -> MiSans-Regular, id=%d", asset_name, self.font_id))
    return
  end

  -- Last resort: try any previously loaded font (id=0)
  print(string.format("[Font] ERROR: no font available for '%s', using id=0", asset_name))
  self.font_id = 0
end


--- Retry loading the original font (called after DWP may have finished downloading).
--- Returns true if successfully reloaded from original asset.
function Font:try_reload()
  if not self._is_fallback or not self._asset_name or not vg then return false end
  local asset_name = self._asset_name
  local paths = {
    "fonts/" .. asset_name .. ".ttf",
    "Fonts/" .. asset_name .. ".ttf",
    "fonts/" .. asset_name .. ".otf",
    "Fonts/" .. asset_name .. ".otf",
  }
  for i, font_path in ipairs(paths) do
    local tag = asset_name .. "_retry" .. i
    local fid = nvgCreateFont(vg, tag, font_path)
    if fid >= 0 then
      self.font_id = fid
      self._is_fallback = false
      print(string.format("[Font] RELOAD OK for '%s' from '%s', id=%d", asset_name, font_path, fid))
      return true
    end
  end
  print(string.format("[Font] RELOAD FAILED for '%s', still using fallback", asset_name))
  return false
end


function Font:get_text_width(text)
  if not text or text == "" then return 0 end
  if not vg or self.font_id < 0 then return #tostring(text) * self.size * 0.5 end
  nvgFontFaceId(vg, self.font_id)
  nvgFontSize(vg, self.size)
  -- nvgTextBounds returns advance width (only works inside nvgBeginFrame/nvgEndFrame)
  local advance = nvgTextBounds(vg, 0, 0, tostring(text))
  return advance or 0
end


function Font:get_height()
  return self.h
end
