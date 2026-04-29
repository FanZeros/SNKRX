-- Shader utilities - Stub for UrhoX
-- NanoVG doesn't support custom GLSL shaders like LÖVE2D.
-- This is a no-op stub that returns a dummy table.

function load_shader(vertex_path, fragment_path)
  -- NanoVG has no shader support; return a dummy object
  return { type = "shader_stub" }
end
