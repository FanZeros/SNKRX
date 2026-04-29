-- SNKRX Engine Shader Module - NanoVG Adapter
-- NanoVG does not support custom GLSL shaders.
-- This adapter provides a best-effort approximation:
--   - Shadow shader: reduces global alpha to simulate a dark shadow effect
--   - Other shaders: no-op stubs

Shader = Object:extend()
function Shader:init(vertex_name, fragment_name)
  self.name = fragment_name or vertex_name or "stub"
  self._is_shadow = (self.name == "shadow.frag")
end


function Shader:set()
  if self._is_shadow then
    -- Approximate shadow effect: draw at very low opacity to create
    -- a faint shadow behind game content. The original shader would
    -- convert all colors to dark/black, but NanoVG can't do global tinting.
    nvgGlobalAlpha(vg, 0.12)
  end
end


function Shader:unset()
  if self._is_shadow then
    nvgGlobalAlpha(vg, 1.0)
  end
end


function Shader:send(value, data)
  -- No-op: NanoVG doesn't support shader uniforms
end
