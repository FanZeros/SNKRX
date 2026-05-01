---@diagnostic disable: undefined-global, redefined-local
Media = Object:extend()
Media:implement(State)
function Media:init(name)
  self:init_state(name)
end


function Media:on_enter(from)
  camera.x, camera.y = dgw/2, dgh/2
  self.main = Group()
  self.effects = Group()
  self.ui = Group()

  graphics.set_background_color(blue[0])
  Text2{group = self.ui, x = dgw/2, y = dgh/2, lines = {
    {text = '[fg]蛇蛇小队', font = fat_font, alignment = 'center', height_offset = -15},
    {text = '[fg]循环更新', font = pixul_font, alignment = 'center'},
  }}
end


function Media:update(dt)
  -- Two-phase touch: pre-scan ALL groups for sticky hover before any update
  if input and input._is_touch and not input.touch_zone_steering then
    input._touch_sticky_active = nil
    input._touch_confirm_group = nil
    self.main:pre_touch_scan()
    self.effects:pre_touch_scan()
    self.ui:pre_touch_scan()
  end

  self.main:update(dt*slow_amount)
  self.effects:update(dt*slow_amount)
  self.ui:update(dt*slow_amount)
end


function Media:draw()
  self.main:draw()
  self.effects:draw()
  self.ui:draw()

  mercenary:draw(30, 30, 0, 1, 1, 0, 0, yellow2[-5])
end
-- trigger LSP reload
