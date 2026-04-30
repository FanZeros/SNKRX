-- SNKRX Engine Graphics Module - NanoVG Adapter
-- Replaces LÖVE2D's love.graphics with NanoVG rendering.
--
-- Architecture:
--   Graphics: top-level manager with layer system
--   Layer: queues draw commands during update, replays via NanoVG during render
--   Module-level functions: set_color, push, pop, print (used by Text, etc.)
--
-- Key differences from LÖVE2D version:
--   - No Canvas (render-to-texture) — all layers draw directly via NanoVG
--   - No shaders — NanoVG doesn't support custom shaders
--   - All drawing happens inside NanoVGRender event (nvgBeginFrame/EndFrame managed externally)

Graphics = Object:extend()

------------------------------------------------------------------------
-- Helper: set NanoVG color from a Color object (forward-declared before init_module)
------------------------------------------------------------------------
local function set_nvg_color(color)
  if color then
    nvgFillColor(vg, nvgRGBAf(color.r, color.g, color.b, color.a))
    nvgStrokeColor(vg, nvgRGBAf(color.r, color.g, color.b, color.a))
  end
end

local function reset_nvg_color()
  nvgFillColor(vg, nvgRGBAf(1, 1, 1, 1))
  nvgStrokeColor(vg, nvgRGBAf(1, 1, 1, 1))
end

------------------------------------------------------------------------
-- Helper: draw a NanoVG line segment
------------------------------------------------------------------------
local function nvg_line(x1, y1, x2, y2)
  nvgBeginPath(vg)
  nvgMoveTo(vg, x1, y1)
  nvgLineTo(vg, x2, y2)
  nvgStroke(vg)
end

function Graphics:init_module()
  self.layers = {}
  self.fixed_layers = {}
  self._current_color = nil  -- track current color for set/restore

  -- Module-level convenience functions (called as graphics.func, NOT graphics:func)
  -- Text and other systems use these: graphics.set_color(c), graphics.push(...), etc.
  local g = self
  self.set_color = function(color)
    if color then
      nvgFillColor(vg, nvgRGBAf(color.r, color.g, color.b, color.a))
      nvgStrokeColor(vg, nvgRGBAf(color.r, color.g, color.b, color.a))
    else
      nvgFillColor(vg, nvgRGBAf(1, 1, 1, 1))
      nvgStrokeColor(vg, nvgRGBAf(1, 1, 1, 1))
    end
    g._current_color = color
  end

  self.push = function(x, y, r, sx, sy)
    nvgSave(vg)
    if x and y then nvgTranslate(vg, x, y) end
    if r and r ~= 0 then nvgRotate(vg, r) end
    if sx then nvgScale(vg, sx, sy or sx) end
    if x and y then nvgTranslate(vg, -x, -y) end
  end

  self.pop = function()
    nvgRestore(vg)
  end

  self.print = function(text_str, font, x, y, r, sx, sy, ox, oy)
    nvgSave(vg)
    nvgTranslate(vg, x or 0, y or 0)
    if r and r ~= 0 then nvgRotate(vg, r) end
    if sx and sx ~= 1 then nvgScale(vg, sx, sy or sx) end
    if font then
      nvgFontFaceId(vg, font.font_id)
      nvgFontSize(vg, font.size)
    end
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgText(vg, -(ox or 0), -(oy or 0), tostring(text_str), nil)
    nvgRestore(vg)
  end

  self.set_line_style = function(style)
    -- NanoVG always uses anti-aliased lines, no equivalent to LÖVE2D's 'rough'/'smooth'
  end

  self.set_default_filter = function(min_filter, mag_filter, anisotropy)
    -- NanoVG handles filtering internally
  end

  -- graphics.set_line_width(width)
  -- Sets persistent line width for subsequent stroke calls
  self.set_line_width = function(w)
    if vg then nvgStrokeWidth(vg, w or 1) end
  end

  ---------------------------------------------------------------------------
  -- Module-level convenience functions used by original SNKRX game code
  -- These are called as graphics.func(...), NOT graphics:func(...)
  ---------------------------------------------------------------------------

  -- graphics.arc('open', x, y, r, a1, a2, color, lw)
  -- Used by DotArea, ForceArea, Tree, Volcano, buy_screen hold buttons
  self.arc = function(mode, x, y, r, a1, a2, color, line_width)
    set_nvg_color(color)
    nvgBeginPath(vg)
    if mode == 'open' or mode == 'line' then
      nvgStrokeWidth(vg, line_width or 1)
      nvgArc(vg, x, y, r, a1, a2, NVG_CW)
      nvgStroke(vg)
    else
      -- 'pie' or 'closed' mode
      nvgMoveTo(vg, x, y)
      nvgArc(vg, x, y, r, a1, a2, NVG_CW)
      nvgClosePath(vg)
      if line_width and line_width > 0 then
        nvgStrokeWidth(vg, line_width)
        nvgStroke(vg)
      else
        nvgFill(vg)
      end
    end
    reset_nvg_color()
    nvgStrokeWidth(vg, 1)
  end

  -- graphics.polyline(color, lw, x1, y1, x2, y2, ...)
  -- Used by Area:draw() corner brackets, LightningLine
  self.polyline = function(color, line_width, ...)
    local pts = {...}
    if #pts < 4 then return end
    set_nvg_color(color)
    nvgStrokeWidth(vg, line_width or 1)
    nvgBeginPath(vg)
    nvgMoveTo(vg, pts[1], pts[2])
    for i = 3, #pts, 2 do
      nvgLineTo(vg, pts[i], pts[i + 1])
    end
    nvgStroke(vg)
    reset_nvg_color()
    nvgStrokeWidth(vg, 1)
  end

  -- graphics.line(x1, y1, x2, y2, color, lw)
  -- Used by ClassIcon draw
  self.line = function(x1, y1, x2, y2, color, line_width)
    set_nvg_color(color)
    nvgStrokeWidth(vg, line_width or 1)
    nvgBeginPath(vg)
    nvgMoveTo(vg, x1, y1)
    nvgLineTo(vg, x2, y2)
    nvgStroke(vg)
    reset_nvg_color()
    nvgStrokeWidth(vg, 1)
  end

  -- graphics.rectangle(x, y, w, h, rx, ry, color, line_width)
  -- Direct draw (not queued to layer) — used in some immediate-mode contexts
  self.rectangle = function(x, y, w, h, rx, ry, color, line_width)
    set_nvg_color(color)
    nvgBeginPath(vg)
    local corner = math.max(rx or 0, ry or 0)
    if corner > 0 then
      nvgRoundedRect(vg, x - w / 2, y - h / 2, w, h, corner)
    else
      nvgRect(vg, x - w / 2, y - h / 2, w, h)
    end
    if line_width and line_width > 0 then
      nvgStrokeWidth(vg, line_width)
      nvgStroke(vg)
    else
      nvgFill(vg)
    end
    reset_nvg_color()
    nvgStrokeWidth(vg, 1)
  end

  -- graphics.circle(x, y, r, color, lw)
  -- Direct draw circle
  self.circle = function(x, y, r, color, line_width)
    set_nvg_color(color)
    nvgBeginPath(vg)
    nvgCircle(vg, x, y, r)
    if line_width and line_width > 0 then
      nvgStrokeWidth(vg, line_width)
      nvgStroke(vg)
    else
      nvgFill(vg)
    end
    reset_nvg_color()
    nvgStrokeWidth(vg, 1)
  end

  -- graphics.triangle_equilateral(x, y, size, color, lw)
  -- Used by Volcano:draw()
  self.triangle_equilateral = function(x, y, size, color, line_width)
    set_nvg_color(color)
    -- Equilateral triangle centered at (x,y) with circumradius = size
    local r = size
    local a1 = -math.pi / 2 -- top
    local x1 = x + r * math.cos(a1)
    local y1 = y + r * math.sin(a1)
    local x2 = x + r * math.cos(a1 + 2 * math.pi / 3)
    local y2 = y + r * math.sin(a1 + 2 * math.pi / 3)
    local x3 = x + r * math.cos(a1 + 4 * math.pi / 3)
    local y3 = y + r * math.sin(a1 + 4 * math.pi / 3)
    nvgBeginPath(vg)
    nvgMoveTo(vg, x1, y1)
    nvgLineTo(vg, x2, y2)
    nvgLineTo(vg, x3, y3)
    nvgClosePath(vg)
    if line_width and line_width > 0 then
      nvgStrokeWidth(vg, line_width)
      nvgStroke(vg)
    else
      nvgFill(vg)
    end
    reset_nvg_color()
    nvgStrokeWidth(vg, 1)
  end

  -- graphics.print_centered(text, font, x, y, r, sx, sy, ox, oy, color)
  -- Used by CharacterIcon, Arena HUD, etc.
  self.print_centered = function(text_str, font, x, y, r, lsx, lsy, ox, oy, color)
    set_nvg_color(color)
    nvgSave(vg)
    nvgTranslate(vg, x or 0, y or 0)
    if r and r ~= 0 then nvgRotate(vg, r) end
    if lsx and lsx ~= 1 then nvgScale(vg, lsx, lsy or lsx) end
    if font then
      nvgFontFaceId(vg, font.font_id)
      nvgFontSize(vg, font.size)
    end
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(vg, -(ox or 0), -(oy or 0), tostring(text_str), nil)
    nvgRestore(vg)
    reset_nvg_color()
  end

  -- graphics.draw_with_mask(mask_fn, draw_fn, inverted)
  -- Original: uses stencil buffer to mask content. NanoVG doesn't support stencil masking.
  -- Simplified: just draw mask_fn content directly (the stars). The mask shape is skipped
  -- since stars are already bounded by their canvas size.
  self.draw_with_mask = function(mask_fn, draw_fn, inverted)
    if mask_fn then mask_fn() end
  end

  -- graphics.rectangle2(x, y, w, h, rx, ry, color, line_width)
  -- Non-centered rectangle: x,y is top-left corner (unlike rectangle which is centered)
  -- Used by shared_draw checker pattern, HealthBar, etc.
  self.rectangle2 = function(x, y, w, h, rx, ry, color, line_width)
    set_nvg_color(color)
    nvgBeginPath(vg)
    local corner = math.max(rx or 0, ry or 0)
    if corner > 0 then
      nvgRoundedRect(vg, x, y, w, h, corner)
    else
      nvgRect(vg, x, y, w, h)
    end
    if line_width and line_width > 0 then
      nvgStrokeWidth(vg, line_width)
      nvgStroke(vg)
    else
      nvgFill(vg)
    end
    reset_nvg_color()
    nvgStrokeWidth(vg, 1)
  end

  -- graphics.set_background_color(color)
  -- In original LÖVE2D this sets the clear color. We store it for use in NanoVGRender.
  self._background_color = nil
  self.set_background_color = function(color)
    g._background_color = color
  end

  -- graphics.get_background_color()
  self.get_background_color = function()
    return g._background_color or Color(0.08, 0.08, 0.12, 1)
  end

  -- graphics.shape(shape_type, color, line_width, ...)
  -- Generic shape drawing helper used by rectangle2 and others in original engine
  self.shape = function(shape_type, color, line_width, ...)
    if shape_type == 'rectangle' then
      local args = {...}
      local x, y, w, h, rx, ry = args[1], args[2], args[3], args[4], args[5], args[6]
      g.rectangle2(x, y, w, h, rx, ry, color, line_width)
    elseif shape_type == 'circle' then
      local args = {...}
      g.circle(args[1], args[2], args[3], color, line_width)
    end
  end

  -- graphics.dashed_line(x1, y1, x2, y2, dash, gap, color, lw)
  self.dashed_line = function(x1, y1, x2, y2, dash_size, gap_size, color, line_width)
    set_nvg_color(color)
    nvgStrokeWidth(vg, line_width or 1)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then return end
    local nx, ny = dx / len, dy / len
    local segment = (dash_size or 4) + (gap_size or 3)
    local pos = 0
    while pos < len do
      local dash_end = math.min(pos + (dash_size or 4), len)
      nvgBeginPath(vg)
      nvgMoveTo(vg, x1 + nx * pos, y1 + ny * pos)
      nvgLineTo(vg, x1 + nx * dash_end, y1 + ny * dash_end)
      nvgStroke(vg)
      pos = pos + segment
    end
    reset_nvg_color()
    nvgStrokeWidth(vg, 1)
  end

  -- graphics.dashed_rectangle(x, y, w, h, dash, gap, color, lw)
  self.dashed_rectangle = function(x, y, w, h, dash_size, gap_size, color, line_width)
    g.dashed_line(x - w / 2, y - h / 2, x + w / 2, y - h / 2, dash_size, gap_size, color, line_width)
    g.dashed_line(x - w / 2, y - h / 2, x - w / 2, y + h / 2, dash_size, gap_size, color, line_width)
    g.dashed_line(x - w / 2, y + h / 2, x + w / 2, y + h / 2, dash_size, gap_size, color, line_width)
    g.dashed_line(x + w / 2, y - h / 2, x + w / 2, y + h / 2, dash_size, gap_size, color, line_width)
  end
end


function Graphics:layer(name)
  return self.layers[name]
end


function Graphics:add_layer(name, args)
  self.layers[name] = Layer(name, args or {})
  return self.layers[name]
end


function Graphics:add_fixed_layer(name, args)
  self.fixed_layers[name] = Layer(name, args or {})
  return self.fixed_layers[name]
end


-- Draw all layers sorted by z-order.
-- Must be called inside NanoVGRender event (between nvgBeginFrame/EndFrame).
function Graphics:draw()
  local sorted_layers = {}
  for _, layer in pairs(self.layers) do
    table.insert(sorted_layers, layer)
  end
  table.sort(sorted_layers, function(a, b) return a.z < b.z end)
  for _, layer in ipairs(sorted_layers) do
    layer:draw()
  end

  local sorted_fixed_layers = {}
  for _, layer in pairs(self.fixed_layers) do
    table.insert(sorted_fixed_layers, layer)
  end
  table.sort(sorted_fixed_layers, function(a, b) return a.z < b.z end)
  for _, layer in ipairs(sorted_fixed_layers) do
    layer:draw()
  end
end


------------------------------------------------------------------------
-- Layer: deferred draw command queue, replayed via NanoVG
------------------------------------------------------------------------
Layer = Object:extend()

function Layer:init(name, args)
  args = args or {}
  self.name = name
  self.z = args.z or 0
  self.camera = args.camera
  self.fixed_camera = args.fixed_camera
  self.draw_commands = {}
end


function Layer:set(what, ...)
  table.insert(self.draw_commands, {type = 'set', what = what, args = {...}})
end


function Layer:circle(x, y, rs, color, line_width)
  table.insert(self.draw_commands, {type = 'circle', x = x, y = y, rs = rs, color = color, line_width = line_width or 0})
end


function Layer:dashed_circle(x, y, rs, color, line_width, dash_size, dash_gap)
  table.insert(self.draw_commands, {type = 'dashed_circle', x = x, y = y, rs = rs, color = color, line_width = line_width or 1, dash_size = dash_size or 6, dash_gap = dash_gap or 4})
end


function Layer:line(x1, y1, x2, y2, color, line_width)
  table.insert(self.draw_commands, {type = 'line', x1 = x1, y1 = y1, x2 = x2, y2 = y2, color = color, line_width = line_width or 1})
end


function Layer:dashed_line(x1, y1, x2, y2, color, line_width, dash_size, dash_gap)
  table.insert(self.draw_commands, {type = 'dashed_line', x1 = x1, y1 = y1, x2 = x2, y2 = y2, color = color, line_width = line_width or 1, dash_size = dash_size or 6, dash_gap = dash_gap or 4})
end


function Layer:arc(x, y, rs, args)
  table.insert(self.draw_commands, {type = 'arc', x = x, y = y, rs = rs, args = args})
end


function Layer:polygon(vertices, color, line_width)
  table.insert(self.draw_commands, {type = 'polygon', vertices = vertices, color = color, line_width = line_width or 0})
end


function Layer:polyline(vertices, color, line_width)
  table.insert(self.draw_commands, {type = 'polyline', vertices = vertices, color = color, line_width = line_width or 1})
end


function Layer:triangle(x, y, w, h, r, color, line_width)
  table.insert(self.draw_commands, {type = 'triangle', x = x, y = y, w = w, h = h, r = r, color = color, line_width = line_width or 0})
end


function Layer:dashed_triangle(x, y, w, h, r, color, line_width, dash_size, dash_gap)
  table.insert(self.draw_commands, {type = 'dashed_triangle', x = x, y = y, w = w, h = h, r = r, color = color, line_width = line_width or 1, dash_size = dash_size or 6, dash_gap = dash_gap or 4})
end


function Layer:rectangle(x, y, w, h, rx, ry, color, line_width)
  table.insert(self.draw_commands, {type = 'rectangle', x = x, y = y, w = w, h = h, rx = rx or 0, ry = ry or 0, r = 0, color = color, line_width = line_width or 0})
end


function Layer:dashed_rectangle(x, y, w, h, rx, ry, color, line_width, dash_size, dash_gap)
  table.insert(self.draw_commands, {type = 'dashed_rectangle', x = x, y = y, w = w, h = h, rx = rx or 0, ry = ry or 0, r = 0, color = color, line_width = line_width or 1, dash_size = dash_size or 6, dash_gap = dash_gap or 4})
end


function Layer:image(image, x, y, r, sx, sy, color, shader, shader_send)
  table.insert(self.draw_commands, {type = 'image', image = image, x = x, y = y, r = r, sx = sx, sy = sy, color = color})
  -- shader/shader_send ignored (NanoVG has no shaders)
end


function Layer:push(x, y, r, sx, sy)
  table.insert(self.draw_commands, {type = 'push', x = x or 0, y = y or 0, r = r or 0, sx = sx or 1, sy = sy or 1})
end


function Layer:pop()
  table.insert(self.draw_commands, {type = 'pop'})
end


function Layer:text(text, font, x, y, r, sx, sy, ox, oy, color)
  table.insert(self.draw_commands, {type = 'text', text = text, font = font, x = x, y = y, r = r or 0, sx = sx or 1, sy = sy or 1, ox = ox or 0, oy = oy or 0, color = color})
end


function Layer:text_wrapped(text, font, x, y, w, ax, dy, r, sx, sy, ox, oy, color)
  table.insert(self.draw_commands, {type = 'text_wrapped', text = text, font = font, x = x, y = y, w = w, ax = ax or 'center', dy = dy or 0, r = r or 0, sx = sx or 1, sy = sy or 1, ox = ox or 0,
    oy = oy or 0, color = color})
end


------------------------------------------------------------------------
-- Layer:draw() — replay all queued commands via NanoVG
------------------------------------------------------------------------
function Layer:draw()
  nvgSave(vg)

  -- Apply offset for letterboxing/pillarboxing, then scale
  if screen_ox ~= 0 or screen_oy ~= 0 then
    nvgTranslate(vg, screen_ox, screen_oy)
  end
  nvgScale(vg, sx, sy)

  -- Apply camera transform
  local cam = self.camera or self.fixed_camera
  if cam then cam:attach() end

  self:draw_commands_f()

  if cam then cam:detach() end

  nvgRestore(vg)
  self.draw_commands = {}
end


------------------------------------------------------------------------
-- Layer:draw_commands_f() — execute all queued draw commands
------------------------------------------------------------------------
function Layer:draw_commands_f()
  for _, c in ipairs(self.draw_commands) do
    if c.type == 'set' then
      if c.what == 'color' then set_nvg_color(c.args[1]) end

    elseif c.type == 'circle' then
      set_nvg_color(c.color)
      nvgBeginPath(vg)
      nvgCircle(vg, c.x, c.y, c.rs)
      if c.line_width == 0 or not c.line_width then
        nvgFill(vg)
      else
        nvgStrokeWidth(vg, c.line_width)
        nvgStroke(vg)
      end
      reset_nvg_color()
      nvgStrokeWidth(vg, 1)

    elseif c.type == 'dashed_circle' then
      set_nvg_color(c.color)
      nvgStrokeWidth(vg, c.line_width)
      local p = 2 * math.pi * c.rs
      local n = math.floor(p / (c.dash_size + c.dash_gap))
      if n < 1 then n = 1 end
      local da = 2 * math.pi / n
      local dash_a = da * (c.dash_size / (c.dash_size + c.dash_gap))
      for i = 0, n - 1 do
        local a = i * da
        nvgBeginPath(vg)
        nvgArc(vg, c.x, c.y, c.rs, a, a + dash_a, NVG_CW)
        nvgStroke(vg)
      end
      reset_nvg_color()
      nvgStrokeWidth(vg, 1)

    elseif c.type == 'line' then
      set_nvg_color(c.color)
      nvgStrokeWidth(vg, c.line_width)
      nvg_line(c.x1, c.y1, c.x2, c.y2)
      reset_nvg_color()
      nvgStrokeWidth(vg, 1)

    elseif c.type == 'dashed_line' then
      set_nvg_color(c.color)
      nvgStrokeWidth(vg, c.line_width)
      local dx, dy = c.x2 - c.x1, c.y2 - c.y1
      local l = math.sqrt(dx * dx + dy * dy)
      if l > 0 then
        local n = math.floor(l / (c.dash_size + c.dash_gap))
        local ux, uy = dx / l, dy / l
        for i = 0, n - 1 do
          local lx1 = c.x1 + ux * i * (c.dash_size + c.dash_gap)
          local ly1 = c.y1 + uy * i * (c.dash_size + c.dash_gap)
          local lx2 = lx1 + ux * c.dash_size
          local ly2 = ly1 + uy * c.dash_size
          nvg_line(lx1, ly1, lx2, ly2)
        end
      end
      reset_nvg_color()
      nvgStrokeWidth(vg, 1)

    elseif c.type == 'arc' then
      local args = c.args
      set_nvg_color(args.color)
      local a1 = args.a1 or 0
      local a2 = args.a2 or (2 * math.pi)
      nvgBeginPath(vg)
      if args.line_width == 0 or not args.line_width then
        -- Filled pie: move to center, arc, close
        nvgMoveTo(vg, c.x, c.y)
        nvgArc(vg, c.x, c.y, c.rs, a1, a2, NVG_CW)
        nvgClosePath(vg)
        nvgFill(vg)
      else
        nvgStrokeWidth(vg, args.line_width)
        nvgArc(vg, c.x, c.y, c.rs, a1, a2, NVG_CW)
        nvgStroke(vg)
      end
      reset_nvg_color()
      nvgStrokeWidth(vg, 1)

    elseif c.type == 'polygon' then
      set_nvg_color(c.color)
      nvgBeginPath(vg)
      -- vertices is a flat array: {x1,y1, x2,y2, ...}
      for i = 1, #c.vertices, 2 do
        if i == 1 then
          nvgMoveTo(vg, c.vertices[i], c.vertices[i + 1])
        else
          nvgLineTo(vg, c.vertices[i], c.vertices[i + 1])
        end
      end
      nvgClosePath(vg)
      if c.line_width == 0 or not c.line_width then
        nvgFill(vg)
      else
        nvgStrokeWidth(vg, c.line_width)
        nvgStroke(vg)
      end
      reset_nvg_color()
      nvgStrokeWidth(vg, 1)

    elseif c.type == 'polyline' then
      set_nvg_color(c.color)
      nvgStrokeWidth(vg, c.line_width)
      nvgBeginPath(vg)
      for i = 1, #c.vertices, 2 do
        if i == 1 then
          nvgMoveTo(vg, c.vertices[i], c.vertices[i + 1])
        else
          nvgLineTo(vg, c.vertices[i], c.vertices[i + 1])
        end
      end
      nvgStroke(vg)
      reset_nvg_color()
      nvgStrokeWidth(vg, 1)

    elseif c.type == 'triangle' then
      set_nvg_color(c.color)
      nvgStrokeWidth(vg, c.line_width)
      local x1 = c.x + c.w * math.cos(c.r)
      local y1 = c.y + c.w * math.sin(c.r)
      local x2 = c.x + c.h * math.cos(c.r + math.pi - math.pi / 6)
      local y2 = c.y + c.h * math.sin(c.r + math.pi - math.pi / 6)
      local x3 = c.x + c.h * math.cos(c.r + math.pi + math.pi / 6)
      local y3 = c.y + c.h * math.sin(c.r + math.pi + math.pi / 6)
      nvgBeginPath(vg)
      nvgMoveTo(vg, x1, y1)
      nvgLineTo(vg, x2, y2)
      nvgLineTo(vg, x3, y3)
      nvgClosePath(vg)
      if c.line_width == 0 or not c.line_width then
        nvgFill(vg)
      else
        nvgStroke(vg)
      end
      reset_nvg_color()
      nvgStrokeWidth(vg, 1)

    elseif c.type == 'dashed_triangle' then
      set_nvg_color(c.color)
      nvgStrokeWidth(vg, c.line_width)
      local x1 = c.x + c.w * math.cos(c.r)
      local y1 = c.y + c.w * math.sin(c.r)
      local x2 = c.x + c.h * math.cos(c.r + math.pi - math.pi / 6)
      local y2 = c.y + c.h * math.sin(c.r + math.pi - math.pi / 6)
      local x3 = c.x + c.h * math.cos(c.r + math.pi + math.pi / 6)
      local y3 = c.y + c.h * math.sin(c.r + math.pi + math.pi / 6)
      local edges = {{x1, y1, x2, y2}, {x2, y2, x3, y3}, {x3, y3, x1, y1}}
      for _, e in ipairs(edges) do
        local dx, dy = e[3] - e[1], e[4] - e[2]
        local l = math.sqrt(dx * dx + dy * dy)
        if l > 0 then
          local n = math.floor(l / (c.dash_size + c.dash_gap))
          local ux, uy = dx / l, dy / l
          for i = 0, n - 1 do
            local ex1 = e[1] + ux * i * (c.dash_size + c.dash_gap)
            local ey1 = e[2] + uy * i * (c.dash_size + c.dash_gap)
            local ex2 = ex1 + ux * c.dash_size
            local ey2 = ey1 + uy * c.dash_size
            nvg_line(ex1, ey1, ex2, ey2)
          end
        end
      end
      reset_nvg_color()
      nvgStrokeWidth(vg, 1)

    elseif c.type == 'rectangle' then
      set_nvg_color(c.color)
      nvgStrokeWidth(vg, c.line_width)
      nvgSave(vg)
      nvgTranslate(vg, c.x, c.y)
      if c.r ~= 0 then nvgRotate(vg, c.r) end
      nvgBeginPath(vg)
      local corner = math.max(c.rx, c.ry)
      if corner > 0 then
        nvgRoundedRect(vg, -c.w / 2, -c.h / 2, c.w, c.h, corner)
      else
        nvgRect(vg, -c.w / 2, -c.h / 2, c.w, c.h)
      end
      if c.line_width == 0 or not c.line_width then
        nvgFill(vg)
      else
        nvgStroke(vg)
      end
      nvgRestore(vg)
      reset_nvg_color()
      nvgStrokeWidth(vg, 1)

    elseif c.type == 'dashed_rectangle' then
      set_nvg_color(c.color)
      nvgStrokeWidth(vg, c.line_width)
      nvgSave(vg)
      nvgTranslate(vg, c.x, c.y)
      if c.r ~= 0 then nvgRotate(vg, c.r) end
      local x, y, w, h = -c.w / 2, -c.h / 2, c.w, c.h
      local edges = {{x, y, x + w, y}, {x + w, y, x + w, y + h}, {x + w, y + h, x, y + h}, {x, y + h, x, y}}
      for _, e in ipairs(edges) do
        local dx, dy = e[3] - e[1], e[4] - e[2]
        local l = math.sqrt(dx * dx + dy * dy)
        if l > 0 then
          local n = math.floor(l / (c.dash_size + c.dash_gap))
          local ux, uy = dx / l, dy / l
          for i = 0, n - 1 do
            local ex1 = e[1] + ux * i * (c.dash_size + c.dash_gap)
            local ey1 = e[2] + uy * i * (c.dash_size + c.dash_gap)
            local ex2 = ex1 + ux * c.dash_size
            local ey2 = ey1 + uy * c.dash_size
            nvg_line(ex1, ey1, ex2, ey2)
          end
        end
      end
      nvgRestore(vg)
      reset_nvg_color()
      nvgStrokeWidth(vg, 1)

    elseif c.type == 'image' then
      if c.image and c.image.nvg_image then
        nvgSave(vg)
        nvgTranslate(vg, c.x, c.y)
        if c.r and c.r ~= 0 then nvgRotate(vg, c.r) end
        local isx = c.sx or 1
        local isy = c.sy or isx
        if isx ~= 1 or isy ~= 1 then nvgScale(vg, isx, isy) end
        local iw, ih = c.image.w, c.image.h
        local paint
        if c.color then
          local tint = nvgRGBAf(c.color.r, c.color.g, c.color.b, c.color.a or 1)
          paint = nvgImagePatternTinted(vg, -iw / 2, -ih / 2, iw, ih, 0, c.image.nvg_image, tint)
        else
          paint = nvgImagePattern(vg, -iw / 2, -ih / 2, iw, ih, 0, c.image.nvg_image, 1)
        end
        nvgBeginPath(vg)
        nvgRect(vg, -iw / 2, -ih / 2, iw, ih)
        nvgFillPaint(vg, paint)
        nvgFill(vg)
        nvgRestore(vg)
      end

    elseif c.type == 'gradient_rect' then
      -- GradientImage rendering via NanoVG linear gradient
      local paint
      local c1 = c.color1 or {r = 1, g = 1, b = 1, a = 1}
      local c2 = c.color2 or {r = 0, g = 0, b = 0, a = 1}
      if c.direction == 'vertical' then
        paint = nvgLinearGradient(vg, c.x, c.y, c.x, c.y + c.h,
          nvgRGBAf(c1.r, c1.g, c1.b, c1.a),
          nvgRGBAf(c2.r, c2.g, c2.b, c2.a))
      else
        paint = nvgLinearGradient(vg, c.x, c.y, c.x + c.w, c.y,
          nvgRGBAf(c1.r, c1.g, c1.b, c1.a),
          nvgRGBAf(c2.r, c2.g, c2.b, c2.a))
      end
      nvgBeginPath(vg)
      nvgRect(vg, c.x, c.y, c.w, c.h)
      nvgFillPaint(vg, paint)
      nvgFill(vg)

    elseif c.type == 'push' then
      nvgSave(vg)
      nvgTranslate(vg, c.x, c.y)
      if c.r ~= 0 then nvgRotate(vg, c.r) end
      if c.sx ~= 1 or c.sy ~= 1 then nvgScale(vg, c.sx, c.sy) end
      nvgTranslate(vg, -c.x, -c.y)

    elseif c.type == 'pop' then
      nvgRestore(vg)

    elseif c.type == 'text' then
      set_nvg_color(c.color)
      nvgSave(vg)
      nvgTranslate(vg, c.x, c.y)
      if c.r ~= 0 then nvgRotate(vg, c.r) end
      if c.sx ~= 1 or c.sy ~= 1 then nvgScale(vg, c.sx, c.sy) end
      if c.font then
        nvgFontFaceId(vg, c.font.font_id)
        nvgFontSize(vg, c.font.size)
      end
      nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
      nvgText(vg, -c.ox, -c.oy, tostring(c.text), nil)
      nvgRestore(vg)
      reset_nvg_color()

    elseif c.type == 'text_wrapped' then
      set_nvg_color(c.color)
      nvgSave(vg)
      nvgTranslate(vg, c.x, c.y)
      if c.r ~= 0 then nvgRotate(vg, c.r) end
      if c.sx ~= 1 or c.sy ~= 1 then nvgScale(vg, c.sx, c.sy) end
      if c.font then
        nvgFontFaceId(vg, c.font.font_id)
        nvgFontSize(vg, c.font.size)
      end
      nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
      -- Simple word-wrap: split text by spaces, measure and break lines
      local lines = _nvg_wrap_text(c.text, c.font, c.w)
      local line_h = c.font and c.font.h or 16
      for i, line_text in ipairs(lines) do
        local ox = 0
        if c.ax == 'center' then
          local tw = c.font and c.font:get_text_width(line_text) or 0
          ox = c.w / 2 - tw / 2
        elseif c.ax == 'right' then
          local tw = c.font and c.font:get_text_width(line_text) or 0
          ox = c.w - tw
        end
        nvgText(vg, ox - c.ox, (i - 1) * (line_h + c.dy) - c.oy, line_text, nil)
      end
      nvgRestore(vg)
      reset_nvg_color()
    end
  end
end


------------------------------------------------------------------------
-- Helper: word-wrap text to fit within width using NanoVG font metrics
------------------------------------------------------------------------
function _nvg_wrap_text(text, font, max_width)
  if not font or not max_width then return {text} end
  local lines = {}
  local current_line = ""
  for word in text:gmatch("%S+") do
    local test = current_line == "" and word or (current_line .. " " .. word)
    local tw = font:get_text_width(test)
    if tw > max_width and current_line ~= "" then
      table.insert(lines, current_line)
      current_line = word
    else
      current_line = test
    end
  end
  if current_line ~= "" then
    table.insert(lines, current_line)
  end
  if #lines == 0 then
    table.insert(lines, text)
  end
  return lines
end
