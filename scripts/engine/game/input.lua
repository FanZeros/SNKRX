-- SNKRX Engine Input - UrhoX Adapter
-- Replaces LÖVE2D's love.keypressed/released callbacks with UrhoX input polling.
--
-- Original SNKRX Input Architecture:
--   - Input is an action-mapping system: bind('move_left', {'a', 'left', 'm1'})
--   - LÖVE2D callbacks set keyboard_state/mouse_state tables each frame
--   - Input:update(dt) compares current vs previous state to derive pressed/down/released
--   - Game code reads: input.move_left.pressed, input.enter.down, etc.
--
-- UrhoX Adaptation:
--   - Each frame, poll urho_input:GetKeyDown(KEY_*) to fill keyboard_state
--   - Poll urho_input:GetMouseButtonDown(MOUSEB_*) to fill mouse_state
--   - The rest of the state machine (bind, update, actions) works unchanged

-- Map LÖVE2D key names → UrhoX KEY_* constants
local love_to_urho_key = {
  a = KEY_A, b = KEY_B, c = KEY_C, d = KEY_D, e = KEY_E, f = KEY_F,
  g = KEY_G, h = KEY_H, i = KEY_I, j = KEY_J, k = KEY_K, l = KEY_L,
  m = KEY_M, n = KEY_N, o = KEY_O, p = KEY_P, q = KEY_Q, r = KEY_R,
  s = KEY_S, t = KEY_T, u = KEY_U, v = KEY_V, w = KEY_W, x = KEY_X,
  y = KEY_Y, z = KEY_Z,
  ['0'] = KEY_0, ['1'] = KEY_1, ['2'] = KEY_2, ['3'] = KEY_3, ['4'] = KEY_4,
  ['5'] = KEY_5, ['6'] = KEY_6, ['7'] = KEY_7, ['8'] = KEY_8, ['9'] = KEY_9,
  space = KEY_SPACE,
  ['return'] = KEY_RETURN,
  escape = KEY_ESCAPE,
  backspace = KEY_BACKSPACE,
  tab = KEY_TAB,
  up = KEY_UP, down = KEY_DOWN, left = KEY_LEFT, right = KEY_RIGHT,
  home = KEY_HOME,
  pageup = KEY_PAGEUP, pagedown = KEY_PAGEDOWN,
  insert = KEY_INSERT,
  delete = KEY_DELETE,
  lshift = KEY_LSHIFT, rshift = KEY_RSHIFT,
  lctrl = KEY_LCTRL, rctrl = KEY_RCTRL,
  lalt = KEY_LALT, ralt = KEY_RALT,
  lgui = KEY_LGUI, rgui = KEY_RGUI,
  capslock = KEY_CAPSLOCK,
  numlock = KEY_NUMLOCKCLEAR,
  scrolllock = KEY_SCROLLLOCK,
  clear = KEY_CLEAR,
  mode = KEY_MODE,
  f1 = KEY_F1, f2 = KEY_F2, f3 = KEY_F3, f4 = KEY_F4,
  f5 = KEY_F5, f6 = KEY_F6, f7 = KEY_F7, f8 = KEY_F8,
  f9 = KEY_F9, f10 = KEY_F10, f11 = KEY_F11, f12 = KEY_F12,
  f13 = KEY_F13, f14 = KEY_F14, f15 = KEY_F15,
  f16 = KEY_F16, f17 = KEY_F17, f18 = KEY_F18,
  -- Keypad
  kp0 = KEY_KP_0, kp1 = KEY_KP_1, kp2 = KEY_KP_2, kp3 = KEY_KP_3,
  kp4 = KEY_KP_4, kp5 = KEY_KP_5, kp6 = KEY_KP_6, kp7 = KEY_KP_7,
  kp8 = KEY_KP_8, kp9 = KEY_KP_9,
  ['kp.'] = KEY_KP_PERIOD,
  ['kp/'] = KEY_KP_DIVIDE,
  ['kp*'] = KEY_KP_MULTIPLY,
  ['kp-'] = KEY_KP_MINUS,
  ['kp+'] = KEY_KP_PLUS,
  kpenter = KEY_KP_ENTER,
  ['kp='] = KEY_KP_EQUALS,
  -- Symbols (mapped to UrhoX equivalents where available)
  [','] = KEY_COMMA,
  ['-'] = KEY_MINUS,
  ['.'] = KEY_PERIOD,
  ['/'] = KEY_SLASH,
  [';'] = KEY_SEMICOLON,
  [':'] = KEY_COLON,
  ['!'] = KEY_EXCLAIM,
  ['"'] = KEY_QUOTEDBL,
  ['#'] = KEY_HASH,
  ['$'] = KEY_DOLLAR,
  ['&'] = KEY_AMPERSAND,
  ["'"] = KEY_QUOTE,
  ['('] = KEY_LEFTPAREN,
  [')'] = KEY_RIGHTPAREN,
  ['*'] = KEY_ASTERISK,
  ['+'] = KEY_PLUS,
}

-- Map LÖVE2D mouse button names → UrhoX MOUSEB_* constants
local love_to_urho_mouse = {
  m1 = MOUSEB_LEFT,
  m2 = MOUSEB_RIGHT,
  m3 = MOUSEB_MIDDLE,
  -- m4, m5: UrhoX doesn't support extra mouse buttons; map to nil
}


Input = Object:extend()

function Input:init(joystick_index)
  self.mouse_buttons = {"m1", "m2", "m3", "m4", "m5", "wheel_up", "wheel_down"}
  self.gamepad_buttons = {"fdown", "fup", "fleft", "fright", "dpdown", "dpup", "dpleft", "dpright",
    "start", "back", "guide", "leftstick", "rightstick", "rb", "lb"}
  self.index_to_gamepad_button = {}
  self.index_to_gamepad_axis = {}
  self.gamepad_axis = {}
  self.joystick_index = joystick_index or 1
  self.joystick = nil  -- No joystick support in UrhoX web
  self.keyboard_state = {}
  self.previous_keyboard_state = {}
  self.mouse_state = {}
  self.previous_mouse_state = {}
  self.gamepad_state = {}
  self.previous_gamepad_state = {}
  self.actions = {}
  self.textinput_buffer = ''
  self.last_key_pressed = nil
  self.touch_zone_steering = false  -- set true during active gameplay to enable left/right screen zone steering
  self._is_touch = false       -- detected touch device
  return self
end


--- Poll UrhoX input subsystem and fill keyboard_state/mouse_state tables.
--- Must be called once per frame BEFORE Input:update(dt).
function Input:poll_urho()
  -- Reset all keyboard states to current UrhoX state
  for love_key, urho_key in pairs(love_to_urho_key) do
    local was_down = self.keyboard_state[love_key]
    local is_down = urho_input:GetKeyDown(urho_key)
    self.keyboard_state[love_key] = is_down
    -- Track last key pressed (for options menu etc.)
    if is_down and not was_down then
      self.last_key_pressed = love_key
    end
  end

  -- Poll mouse buttons
  for love_btn, urho_btn in pairs(love_to_urho_mouse) do
    local was_down = self.mouse_state[love_btn]
    local is_down = urho_input:GetMouseButtonDown(urho_btn)
    self.mouse_state[love_btn] = is_down
    if is_down and not was_down then
      self.last_key_pressed = love_btn
    end
  end

  -- Touch/click zone steering: left-click on left half → m1 (move_left),
  -- left-click on right half → m2 (move_right).
  -- Only active during gameplay (touch_zone_steering flag set by game code).
  if self.touch_zone_steering and self.mouse_state.m1 and not urho_input:GetMouseButtonDown(MOUSEB_RIGHT) then
    -- Only remap when it's a pure left-click (not actual right-click)
    -- Convert physical mouse position to logical pixels, then check against
    -- the game area center (accounting for letterbox offset)
    local dpr = urho_graphics:GetDPR()
    local mx = urho_input.mousePosition.x / dpr
    local ox = screen_ox or 0
    local game_center_x = ox + (gw * sx) / 2
    if mx >= game_center_x then
      -- Right half of screen: remap m1 → m2
      self.mouse_state.m1 = false
      self.mouse_state.m2 = true
      if self.last_key_pressed == 'm1' then
        self.last_key_pressed = 'm2'
      end
    end
    -- Left half: m1 stays as-is (already true)
  end

  -- Mouse wheel: UrhoX provides GetMouseMoveWheel() which returns delta
  local wheel = urho_input:GetMouseMoveWheel()
  self.mouse_state.wheel_up = wheel > 0
  self.mouse_state.wheel_down = wheel < 0

  -- Detect touch device: if engine reports any touch, mark as touch device
  if not self._is_touch and urho_input:GetNumTouches() > 0 then
    self._is_touch = true
  end

  -- Clear per-frame touch coordination signals (set by Group sticky hover logic)
  self._touch_sticky_active = nil
  self._touch_confirm_group = nil
end


function Input:update(dt)
  -- Clear all action states
  for _, action in ipairs(self.actions) do
    if self[action] then
      self[action].pressed = false
      self[action].down = false
      self[action].released = false
    end
  end

  -- Compute pressed/down/released from current vs previous state
  for _, action in ipairs(self.actions) do
    if self[action] and self[action].keys then
      for _, key in ipairs(self[action].keys) do
        if table.contains(self.mouse_buttons, key) then
          self[action].pressed = self[action].pressed or (self.mouse_state[key] and not self.previous_mouse_state[key])
          self[action].down = self[action].down or (self.mouse_state[key] or false)
          self[action].released = self[action].released or (not self.mouse_state[key] and self.previous_mouse_state[key])
        elseif table.contains(self.gamepad_buttons, key) then
          self[action].pressed = self[action].pressed or (self.gamepad_state[key] and not self.previous_gamepad_state[key])
          self[action].down = self[action].down or (self.gamepad_state[key] or false)
          self[action].released = self[action].released or (not self.gamepad_state[key] and self.previous_gamepad_state[key])
        else
          self[action].pressed = self[action].pressed or (self.keyboard_state[key] and not self.previous_keyboard_state[key])
          self[action].down = self[action].down or (self.keyboard_state[key] or false)
          self[action].released = self[action].released or (not self.keyboard_state[key] and self.previous_keyboard_state[key])
        end
      end
    end
  end

  -- Save current state as previous for next frame
  self.previous_mouse_state = table.copy(self.mouse_state)
  self.previous_gamepad_state = table.copy(self.gamepad_state)
  self.previous_keyboard_state = table.copy(self.keyboard_state)
  self.mouse_state.wheel_up = false
  self.mouse_state.wheel_down = false
end


function Input:set_mouse_grabbed(v)
  -- No-op on UrhoX web; cursor is managed by engine
end


function Input:set_mouse_visible(v)
  -- No-op on UrhoX web
end


function Input:bind(action, keys)
  if not self[action] then self[action] = {} end
  if type(keys) == "string" then self[action].keys = {keys}
  elseif type(keys) == "table" then self[action].keys = keys end
  table.insert(self.actions, action)
end


function Input:unbind(action)
  self[action] = nil
end


function Input:axis(key)
  return self.gamepad_axis[key]
end


function Input:textinput(text)
  self.textinput_buffer = self.textinput_buffer .. text
  return self.textinput_buffer
end


function Input:get_and_clear_textinput_buffer()
  local buffer = self.textinput_buffer
  self.textinput_buffer = ""
  return buffer
end


function Input:bind_all()
  -- Set direct input binds for every keyboard and mouse key
  local keyboard_binds = {
    ['a'] = {'a'}, ['b'] = {'b'}, ['c'] = {'c'}, ['d'] = {'d'}, ['e'] = {'e'},
    ['f'] = {'f'}, ['g'] = {'g'}, ['h'] = {'h'}, ['i'] = {'i'}, ['j'] = {'j'},
    ['k'] = {'k'}, ['l'] = {'l'}, ['m'] = {'m'}, ['n'] = {'n'}, ['o'] = {'o'},
    ['p'] = {'p'}, ['q'] = {'q'}, ['r'] = {'r'}, ['s'] = {'s'}, ['t'] = {'t'},
    ['u'] = {'u'}, ['v'] = {'v'}, ['w'] = {'w'}, ['x'] = {'x'}, ['y'] = {'y'},
    ['z'] = {'z'},
    ['0'] = {'0'}, ['1'] = {'1'}, ['2'] = {'2'}, ['3'] = {'3'}, ['4'] = {'4'},
    ['5'] = {'5'}, ['6'] = {'6'}, ['7'] = {'7'}, ['8'] = {'8'}, ['9'] = {'9'},
    ['space'] = {'space'},
    ['!'] = {'!'}, ['"'] = {'"'}, ['#'] = {'#'}, ['$'] = {'$'}, ['&'] = {'&'},
    ["'"] = {"'"}, ['('] = {'('}, [')'] = {')'}, ['*'] = {'*'}, ['+'] = {'+'},
    [','] = {','}, ['-'] = {'-'}, ['.'] = {'.'}, ['/'] = {'/'},
    [':'] = {':'}, [';'] = {';'},
    ['kp0'] = {'kp0'}, ['kp1'] = {'kp1'}, ['kp2'] = {'kp2'}, ['kp3'] = {'kp3'},
    ['kp4'] = {'kp4'}, ['kp5'] = {'kp5'}, ['kp6'] = {'kp6'}, ['kp7'] = {'kp7'},
    ['kp8'] = {'kp8'}, ['kp9'] = {'kp9'},
    ['kp.'] = {'kp.'}, ['kp,'] = {'kp,'}, ['kp/'] = {'kp/'}, ['kp*'] = {'kp*'},
    ['kp-'] = {'kp-'}, ['kp+'] = {'kp+'}, ['kpenter'] = {'kpenter'}, ['kp='] = {'kp='},
    ['up'] = {'up'}, ['down'] = {'down'}, ['right'] = {'right'}, ['left'] = {'left'},
    ['home'] = {'home'}, ['pageup'] = {'pageup'}, ['pagedown'] = {'pagedown'},
    ['insert'] = {'insert'}, ['backspace'] = {'backspace'}, ['tab'] = {'tab'},
    ['clear'] = {'clear'}, ['return'] = {'return'}, ['delete'] = {'delete'},
    ['f1'] = {'f1'}, ['f2'] = {'f2'}, ['f3'] = {'f3'}, ['f4'] = {'f4'},
    ['f5'] = {'f5'}, ['f6'] = {'f6'}, ['f7'] = {'f7'}, ['f8'] = {'f8'},
    ['f9'] = {'f9'}, ['f10'] = {'f10'}, ['f11'] = {'f11'}, ['f12'] = {'f12'},
    ['f13'] = {'f13'}, ['f14'] = {'f14'}, ['f15'] = {'f15'}, ['f16'] = {'f16'},
    ['f17'] = {'f17'}, ['f18'] = {'f18'},
    ['numlock'] = {'numlock'}, ['capslock'] = {'capslock'}, ['scrolllock'] = {'scrolllock'},
    ['rshift'] = {'rshift'}, ['lshift'] = {'lshift'},
    ['rctrl'] = {'rctrl'}, ['lctrl'] = {'lctrl'},
    ['ralt'] = {'ralt'}, ['lalt'] = {'lalt'},
    ['rgui'] = {'rgui'}, ['lgui'] = {'lgui'},
    ['mode'] = {'mode'}, ['escape'] = {'escape'},
  }
  for k, v in pairs(keyboard_binds) do self:bind(k, v) end
  self:bind('m1', {'m1'})
  self:bind('m2', {'m2'})
  self:bind('m3', {'m3'})
  self:bind('m4', {'m4'})
  self:bind('m5', {'m5'})
  self:bind('wheel_up', {'wheel_up'})
  self:bind('wheel_down', {'wheel_down'})
end
