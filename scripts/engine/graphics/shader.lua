-- SNKRX Engine Shader Module - NanoVG Adapter
-- NanoVG does not support custom GLSL shaders.
-- This adapter provides a best-effort approximation:
--   - Shadow shader: toggles Graphics shadow mode to replace all colors
--     with dark gray (0.1, 0.1, 0.1) at 50% of original alpha,
--     matching the original GLSL: vec4(0.1, 0.1, 0.1, Texel(tc).a * 0.5)
--   - Other shaders: no-op stubs

Shader = Object:extend()
function Shader:init(vertex_name, fragment_name)
  self.name = fragment_name or vertex_name or "stub"
  self._is_shadow = (self.name == "shadow.frag")
end


function Shader:set()
  if self._is_shadow then
    -- Activate shadow mode in Graphics module.
    -- This causes set_nvg_color / set_color / reset_nvg_color to output
    -- dark gray (0.1, 0.1, 0.1) at half the original alpha, matching the
    -- original shadow.frag shader behavior.
    graphics.set_shadow_mode(true)
  end
end


function Shader:unset()
  if self._is_shadow then
    graphics.set_shadow_mode(false)
  end
end


function Shader:send(value, data)
  -- No-op: NanoVG doesn't support shader uniforms
end
