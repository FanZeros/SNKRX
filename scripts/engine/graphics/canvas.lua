-- SNKRX Engine Canvas Module - NanoVG Adapter (Record + Replay)
-- NanoVG does not support render-to-texture, so Canvas uses a record+replay
-- pattern: draw_to() records the draw action (closure), and draw() replays it
-- with the requested transform (translation, rotation, scaling).
--
-- This preserves the original SNKRX compositing pipeline where multiple
-- canvases (background, main, shadow) are drawn to separately and then
-- composited in order with sx/sy scaling.

Canvas = Object:extend()
function Canvas:init(w, h, opts)
  self.w = w or gw
  self.h = h or gh
  self._draw_action = nil
end


-- Records the draw action for later replay via draw() or draw2().
-- Unlike LÖVE2D, this does NOT execute the action immediately.
function Canvas:draw_to(action)
  self._draw_action = action
end


-- Replays the recorded draw action with the given transform, then clears it.
-- This is the equivalent of blitting a canvas texture to screen in LÖVE2D.
function Canvas:draw(x, y, r, sx, sy, ox, oy)
  if not self._draw_action then return end
  nvgSave(vg)
  nvgTranslate(vg, x or 0, y or 0)
  if r and r ~= 0 then nvgRotate(vg, r) end
  if sx then nvgScale(vg, sx, sy or sx) end
  if ox or oy then nvgTranslate(vg, -(ox or 0), -(oy or 0)) end
  -- Clip content to canvas bounds (LÖVE2D canvases auto-clip; NanoVG needs explicit scissor)
  nvgScissor(vg, 0, 0, self.w, self.h)
  self._draw_action()
  nvgRestore(vg)
  self._draw_action = nil
end


-- Same as draw() but does NOT clear the recorded action, allowing reuse.
-- Used by shadow_canvas to replay main_canvas content through a shader.
function Canvas:draw2(x, y, r, sx, sy, ox, oy)
  if not self._draw_action then return end
  nvgSave(vg)
  nvgTranslate(vg, x or 0, y or 0)
  if r and r ~= 0 then nvgRotate(vg, r) end
  if sx then nvgScale(vg, sx, sy or sx) end
  if ox or oy then nvgTranslate(vg, -(ox or 0), -(oy or 0)) end
  -- Clip content to canvas bounds (LÖVE2D canvases auto-clip; NanoVG needs explicit scissor)
  nvgScissor(vg, 0, 0, self.w, self.h)
  self._draw_action()
  nvgRestore(vg)
  -- draw2 does NOT clear _draw_action (allows multiple replays)
end


-- Set/unset stubs (in LÖVE2D these set the canvas as render target)
function Canvas:set()
  -- No-op
end


function Canvas:unset()
  -- No-op
end


function Canvas:clear()
  self._draw_action = nil
end
