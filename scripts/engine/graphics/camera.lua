-- SNKRX Engine Camera Module - NanoVG Adapter
-- Replaces LÖVE2D's love.graphics push/translate/scale/rotate/pop with NanoVG transforms.
-- Also includes Shake class for camera shake effects.

Shake = Object:extend()
function Shake:init(amplitude, duration, frequency)
  self.amplitude = amplitude or 0
  self.duration = duration or 0
  self.frequency = frequency or 60
  self.samples = {}
  for i = 1, (duration / 1000) * frequency do self.samples[i] = 2 * math.random() - 1 end
  self.ti = 0
  self.t = 0
  self.shaking = true
  -- Track creation time using the global 'time' variable if available
  self._start_time = (time or 0) * 1000
end


function Shake:update(dt)
  self.t = self.t + dt * 1000
  if self.t > self.duration then
    self.shaking = false
  end
end


function Shake:get_noise(s)
  return self.samples[s] or 0
end


function Shake:get_decay(t)
  if t > self.duration then return 0 end
  return (self.duration - t) / self.duration
end


function Shake:get_amplitude(t)
  if not t then
    if not self.shaking then return 0 end
    t = self.t
  end
  local s = (t / 1000) * self.frequency
  local s0 = math.floor(s) + 1  -- Lua arrays are 1-based
  local s1 = s0 + 1
  local frac = s - math.floor(s)
  local k = self:get_decay(t)
  return self.amplitude * (self:get_noise(s0) + frac * (self:get_noise(s1) - self:get_noise(s0))) * k
end


Camera = Object:extend()
function Camera:init(x, y, w, h)
  self.x, self.y = x, y
  self.w, self.h = w or gw, h or gh
  self.r, self.sx, self.sy = 0, 1, 1
  self.mouse = Vector(0, 0)
  self.last_mouse = Vector(0, 0)
  self.mouse_dt = Vector(0, 0)
  self.shakes = {x = {}, y = {}}
  self.spring = {x = Spring(), y = Spring()}
  self.lerp = Vector(1, 1)
  self.lead = Vector(1, 1)
  self.impulse = Vector(0, 0)
  self.follow_style = "no_deadzone"
  self.shake_amount = Vector(0, 0)
  self.last_shake_amount = Vector(0, 0)
  self.last_target = Vector(0, 0)
  self.scroll = Vector(0, 0)
end


-- Attaches the camera transform via NanoVG.
-- All further draw operations will be affected by camera translation, scale and rotation.
-- scroll_factor_x/y: parallax factor (1 = no parallax, 0 = fully static)
function Camera:attach(scroll_factor_x, scroll_factor_y)
  self.bx, self.by = self.x, self.y
  self.x = self.bx * (scroll_factor_x or 1)
  self.y = self.by * (scroll_factor_y or scroll_factor_x or 1)
  nvgSave(vg)
  nvgTranslate(vg, self.w / 2, self.h / 2)
  if not self.ignore_scale then nvgScale(vg, self.sx, self.sy) end
  if self.r ~= 0 then nvgRotate(vg, self.r) end
  nvgTranslate(vg, -self.x * (scroll_factor_x or 1), -self.y * (scroll_factor_y or 1))
end


-- Detaches the camera, restoring the NanoVG transform state.
function Camera:detach()
  nvgRestore(vg)
  self.x, self.y = self.bx, self.by
end


-- Callback-style: attach, execute fn, then detach.
function Camera:draw(fn)
  self:attach()
  fn()
  self:detach()
end


-- Returns values in world coordinates (screen → world).
function Camera:get_world_coords(x, y)
  local c, s = math.cos(-self.r), math.sin(-self.r)
  x, y = (x - sx * self.w / 2) / (sx * self.sx), (y - sy * self.h / 2) / (sy * self.sy)
  x, y = c * x - s * y, s * x + c * y
  return x + self.x, y + self.y
end


-- Returns values in local/screen coordinates (world → screen).
function Camera:get_local_coords(x, y)
  local c, s = math.cos(self.r), math.sin(self.r)
  x, y = x - self.x, y - self.y
  x, y = c * x - s * y, s * x + c * y
  return x * self.sx + self.w / 2, y * self.sy + self.h / 2
end


function Camera:update(dt)
  self.mouse.x, self.mouse.y = self:get_mouse_position()
  self.mouse_dt.x, self.mouse_dt.y = self.mouse.x - self.last_mouse.x, self.mouse.y - self.last_mouse.y
  self.shake_amount:set(0, 0)
  for _, z in ipairs({"x", "y"}) do
    for i = #self.shakes[z], 1, -1 do
      self.shakes[z][i]:update(dt)
      self.shake_amount[z] = self.shake_amount[z] + self.shakes[z][i]:get_amplitude()
      if not self.shakes[z][i].shaking then
        table.remove(self.shakes[z], i)
      end
    end
  end

  self.spring.x:update(dt)
  self.spring.y:update(dt)
  self.shake_amount:add(self.spring.x.x, self.spring.y.x)
  self.x, self.y = self.x - self.last_shake_amount.x, self.y - self.last_shake_amount.y
  self.x, self.y = self.x + self.shake_amount.x, self.y + self.shake_amount.y
  self.last_shake_amount:set(self.shake_amount)
  self.x = self.x + self.impulse.x * dt
  self.y = self.y + self.impulse.y * dt
  self.impulse:mul(0.9 * refresh_rate * dt)

  if self.bound then
    self.x = math.min(math.max(self.x, self.bounds_min.x + self.w / 2), self.bounds_max.x - self.w / 2)
    self.y = math.min(math.max(self.y, self.bounds_min.y + self.h / 2), self.bounds_max.y - self.h / 2)
  end

  self.last_mouse.x, self.last_mouse.y = self.mouse.x, self.mouse.y
  if not self.target then return end

  if self.follow_style == "lockon" then
    local w, h = self.w / 16, self.w / 16
    self:set_deadzone((self.w - w) / 2, (self.h - h) / 2, w, h)
  elseif self.follow_style == "lockon_tight" then
    local w, h = self.w / 64, self.w / 64
    self:set_deadzone((self.w - w) / 2, (self.h - h) / 2, w, h)
  elseif self.follow_style == "lockon_loose" then
    local w, h = self.w / 4, self.w / 4
    self:set_deadzone((self.w - w) / 2, (self.h - h) / 2, w, h)
  elseif self.follow_style == "platformer" then
    local w, h = self.w / 8, self.h / 3
    self:set_deadzone((self.w - w) / 2, (self.h - h) / 2 - h * 0.25, w, h)
  elseif self.follow_style == "topdown" then
    local s = math.max(self.w, self.h) / 4
    self:set_deadzone((self.w - s) / 2, (self.h - s) / 2, s, s)
  elseif self.follow_style == "topdown_tight" then
    local s = math.max(self.w, self.h) / 8
    self:set_deadzone((self.w - s) / 2, (self.h - s) / 2, s, s)
  elseif self.follow_style == "screen_by_screen" then
    self:set_deadzone(0, 0, 0, 0)
  elseif self.follow_style == "no_deadzone" then
    self.deadzone = nil
  end

  if not self.deadzone then
    self.x, self.y = self.target.x, self.target.y
    if self.bound then
      self.x = math.min(math.max(self.x, self.bounds_min.x + self.w / 2), self.bounds_max.x - self.w / 2)
      self.y = math.min(math.max(self.y, self.bounds_min.y + self.h / 2), self.bounds_max.y - self.h / 2)
    end
    return
  end

  local dx1, dy1, dx2, dy2 = self.deadzone.x, self.deadzone.y, self.deadzone.x + self.deadzone.w, self.deadzone.y + self.deadzone.h
  local scroll_x, scroll_y = 0, 0
  local target_x, target_y = self:get_local_coords(self.target.x, self.target.y)
  local x, y = self:get_local_coords(self.x, self.y)

  if self.follow_style == "screen_by_screen" then
    if self.bound then
      if self.x > self.bounds_min.x + self.w / 2 and target_x < 0 then self.scroll.x = math.snap_center(self.scroll.x - self.w / self.sx, self.w / self.sx) end
      if self.x < self.bounds_max.x - self.w / 2 and target_x >= self.w then self.scroll.x = math.snap_center(self.scroll.x + self.w / self.sx, self.w / self.sx) end
      if self.y > self.bounds_min.y + self.h / 2 and target_y < 0 then self.scroll.y = math.snap_center(self.scroll.y - self.h / self.sy, self.h / self.sy) end
      if self.y < self.bounds_max.y - self.h / 2 and target_y >= self.h then self.scroll.y = math.snap_center(self.scroll.y + self.h / self.sy, self.h / self.sy) end
    else
      if target_x < 0 then self.scroll.x = math.snap_center(self.scroll.x - self.w / self.sx, self.w / self.sx) end
      if target_x >= self.w then self.scroll.x = math.snap_center(self.scroll.x + self.w / self.sx, self.w / self.sx) end
      if target_y < 0 then self.scroll.y = math.snap_center(self.scroll.y - self.h / self.sy, self.h / self.sy) end
      if target_y >= self.h then self.scroll.y = math.snap_center(self.scroll.y + self.h / self.sy, self.h / self.sy) end
    end
    self.x = math.lerp(self.lerp.x, self.x, self.scroll.x)
    self.y = math.lerp(self.lerp.y, self.y, self.scroll.y)

    if self.bound then
      self.x = math.min(math.max(self.x, self.bounds_min.x + self.w / 2), self.bounds_max.x - self.w / 2)
      self.y = math.min(math.max(self.y, self.bounds_min.y + self.h / 2), self.bounds_max.y - self.h / 2)
    end

  else
    if target_x < x + (dx1 + dx2 - x) then
      local d = target_x - dx1
      if d < 0 then scroll_x = d end
    end
    if target_x > x - (dx1 + dx2 - x) then
      local d = target_x - dx2
      if d > 0 then scroll_x = d end
    end
    if target_y < y + (dy1 + dy2 - y) then
      local d = target_y - dy1
      if d < 0 then scroll_y = d end
    end
    if target_y > y - (dy1 + dy2 - y) then
      local d = target_y - dy2
      if d > 0 then scroll_y = d end
    end

    if not self.last_target.x and not self.last_target.y then self.last_target.x, self.last_target.y = self.target.x, self.target.y end
    scroll_x = scroll_x + (self.target.x - self.last_target.x) * self.lead.x
    scroll_y = scroll_y + (self.target.y - self.last_target.y) * self.lead.y
    self.last_target.x, self.last_target.y = self.target.x, self.target.y
    self.x = math.lerp(self.lerp.x, self.x, self.x + scroll_x)
    self.y = math.lerp(self.lerp.y, self.y, self.y + scroll_y)

    if self.bound then
      self.x = math.min(math.max(self.x, self.bounds_min.x + self.w / 2), self.bounds_max.x - self.w / 2)
      self.y = math.min(math.max(self.y, self.bounds_min.y + self.h / 2), self.bounds_max.y - self.h / 2)
    end
  end
end


function Camera:shake(intensity, duration, frequency)
  local _state = rawget(_G, "state")
  if _state and _state.no_screen_shake then return end
  table.insert(self.shakes.x, Shake(intensity, 1000 * (duration or 0), frequency or 60))
  table.insert(self.shakes.y, Shake(intensity, 1000 * (duration or 0), frequency or 60))
end


function Camera:spring_shake(intensity, r, k, d)
  local _state = rawget(_G, "state")
  if _state and _state.no_screen_shake then return end
  self.spring.x:pull(-intensity * math.cos(r or 0), k, d)
  self.spring.y:pull(-intensity * math.sin(r or 0), k, d)
end


function Camera:set_deadzone(x, y, w, h)
  self.deadzone = {x = x, y = y, w = w, h = h}
end


function Camera:set_bounds(x, y, w, h)
  self.bound = true
  self.bounds_min = {x = x - w / 2, y = y - h / 2}
  self.bounds_max = {x = x + w / 2, y = y + h / 2}
end


function Camera:follow_object(obj)
  self.target = obj
end


-- Returns mouse position in world coordinates, using UrhoX input API.
function Camera:get_mouse_position()
  -- Use urho_input (saved before game code overwrites global 'input')
  local inp = urho_input or input
  local pos = inp.mousePosition
  if not pos then return 0, 0 end
  local mx, my = pos.x, pos.y
  return self:get_world_coords(mx, my)
end


function Camera:angle_to_mouse(x, y)
  local mx, my = self:get_mouse_position()
  return math.angle(x, y, mx, my)
end


function Camera:apply_impulse(f, r)
  self.impulse:set(f * math.cos(r), f * math.sin(r))
end
