-- SNKRX Engine Animation Module - NanoVG Adapter
-- AnimationFrames uses NanoVG image pattern + scissor for quad-based sub-regions.
-- AnimationLogic and Animation are pure Lua logic, nearly verbatim.

AnimationFrames = Object:extend()
function AnimationFrames:init(image, frame_w, frame_h, frames_list)
  self.source = image
  self.frame_w, self.frame_h = frame_w, frame_h
  self.frames_list = frames_list

  if type(self.frames_list) == 'number' then
    local fl = {}
    for i = 1, self.frames_list do table.insert(fl, {i, 1}) end
    self.frames_list = fl
  elseif not self.frames_list then
    local fl = {}
    for i = 1, math.floor(self.source.w / self.frame_w) do table.insert(fl, {i, 1}) end
    self.frames_list = fl
  end

  self.frames = {}
  for i, frame in ipairs(self.frames_list) do
    self.frames[i] = {
      src_x = (frame[1] - 1) * self.frame_w,
      src_y = (frame[2] - 1) * self.frame_h,
      w = self.frame_w,
      h = self.frame_h
    }
  end
  self.size = #self.frames
end


function AnimationFrames:draw(frame_idx, x, y, r, sx, sy, ox, oy, color)
  local f = self.frames[frame_idx]
  if not f then return end
  local src = self.source
  if not src or not src.nvg_image or src.nvg_image <= 0 then return end

  if color then
    graphics.set_color(color)
  end

  nvgSave(vg)
  nvgTranslate(vg, x, y)
  if r and r ~= 0 then nvgRotate(vg, r) end
  local isx = sx or 1
  local isy = sy or isx
  if isx ~= 1 or isy ~= 1 then nvgScale(vg, isx, isy) end

  local draw_ox = f.w / 2 + (ox or 0)
  local draw_oy = f.h / 2 + (oy or 0)

  -- Draw sub-region using image pattern offset + clipping
  local alpha = (color and color.a) or 1
  local paint = nvgImagePattern(vg,
    -draw_ox - f.src_x, -draw_oy - f.src_y,
    src.w, src.h, 0, src.nvg_image, alpha)
  nvgBeginPath(vg)
  nvgRect(vg, -draw_ox, -draw_oy, f.w, f.h)
  nvgFillPaint(vg, paint)
  nvgFill(vg)
  nvgRestore(vg)

  if color then
    nvgFillColor(vg, nvgRGBAf(1, 1, 1, 1))
    nvgStrokeColor(vg, nvgRGBAf(1, 1, 1, 1))
  end
end


------------------------------------------------------------------------
-- AnimationLogic: pure Lua frame timing, no rendering dependency
------------------------------------------------------------------------
AnimationLogic = Object:extend()
function AnimationLogic:init(delay, frames, loop_mode, actions)
  self.delay = delay
  self.frames = frames
  self.loop_mode = loop_mode or "once"
  self.actions = actions
  self.timer = 0
  self.frame = 1
  self.direction = 1
end


function AnimationLogic:update(dt)
  if self.dead then return end

  self.timer = self.timer + dt
  local delay = self.delay
  if type(self.delay) == "table" then delay = self.delay[self.frame] end

  if self.timer > delay then
    self.timer = 0
    self.frame = self.frame + self.direction
    if self.frame > self.frames or self.frame < 1 then
      if self.loop_mode == "once" then
        self.frame = self.frames
        self.dead = true
      elseif self.loop_mode == "loop" then
        self.frame = 1
      elseif self.loop_mode == "bounce" then
        self.direction = -self.direction
        self.frame = self.frame + 2 * self.direction
      end
      if self.actions and self.actions[0] then self.actions[0]() end
    end
    if self.actions and self.actions[self.frame] then self.actions[self.frame]() end
  end
end


------------------------------------------------------------------------
-- Animation: combines AnimationFrames + AnimationLogic
------------------------------------------------------------------------
Animation = Object:extend()
function Animation:init(delay, animation_frames, loop_mode, actions)
  self.delay = delay
  self.animation_frames = animation_frames
  self.size = self.animation_frames.size
  self.loop_mode = loop_mode
  self.actions = actions
  self.animation_logic = AnimationLogic(self.delay, self.animation_frames.size, self.loop_mode, self.actions)
end


function Animation:update(dt)
  self.animation_logic:update(dt)
end


function Animation:draw(x, y, r, sx, sy, ox, oy, color)
  self.animation_frames:draw(self.animation_logic.frame, x, y, r, sx, sy, ox, oy, color)
end
