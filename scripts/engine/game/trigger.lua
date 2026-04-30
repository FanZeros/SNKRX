-- The base Trigger class.
-- Adapted for UrhoX: replaced love.timer.getTime() with accumulated time.
-- A global instance of this called "trigger" is available by default.
Trigger = Object:extend()

-- Fallback UID when global 'random' is not yet initialised
local _trigger_uid_counter = 0
local function _fallback_uid()
  _trigger_uid_counter = _trigger_uid_counter + 1
  return "__trigger_" .. _trigger_uid_counter
end
local function _safe_uid()
  if random then return random:uid() end
  return _fallback_uid()
end

function Trigger:init()
  self.triggers = {}
  self.time = 0
end


-- Calls the action every frame until it's cancelled via trigger:cancel.
function Trigger:run(action, after, tag)
  tag = tag or _safe_uid()
  after = after or function() end
  self.triggers[tag] = {type = "run", timer = 0, after = after, action = action}
end


-- Calls the action after delay seconds.
-- Or calls the action after the condition is true.
function Trigger:after(delay, action, tag)
  tag = tag or _safe_uid()
  if type(delay) == "number" or type(delay) == "table" then
    self.triggers[tag] = {type = "after", timer = 0, unresolved_delay = delay, delay = self:resolve_delay(delay), action = action}
  else
    self.triggers[tag] = {type = "conditional_after", condition = delay, action = action}
  end
end


-- Calls the action every delay seconds if the condition is true.
function Trigger:cooldown(delay, condition, action, times, after, tag)
  times = times or 0
  after = after or function() end
  tag = tag or _safe_uid()
  self.triggers[tag] = {type = "cooldown", timer = 0, unresolved_delay = delay, delay = self:resolve_delay(delay), condition = condition, action = action, times = times, max_times = times, after = after, multiplier = 1}
end


-- Calls the action every delay seconds.
-- Or calls the action once every time the condition becomes true.
function Trigger:every(delay, action, times, after, tag)
  times = times or 0
  after = after or function() end
  tag = tag or _safe_uid()
  if type(delay) == "number" or type(delay) == "table" then
    self.triggers[tag] = {type = "every", timer = 0, unresolved_delay = delay, delay = self:resolve_delay(delay), action = action, times = times, max_times = times, after = after, multiplier = 1}
  else
    self.triggers[tag] = {type = "conditional_every", condition = delay, last_condition = false, action = action, times = times, max_times = times, after = after}
  end
end


-- Same as every except the action is called immediately when this function is called.
function Trigger:every_immediate(delay, action, times, after, tag)
  times = times or 0
  after = after or function() end
  tag = tag or _safe_uid()
  self.triggers[tag] = {type = "every", timer = 0, unresolved_delay = delay, delay = self:resolve_delay(delay), action = action, times = times, max_times = times, after = after, multiplier = 1}
  action()
end


-- Calls the action every frame for delay seconds.
function Trigger:during(delay, action, after, tag)
  after = after or function() end
  tag = tag or _safe_uid()
  if type(delay) == "number" or type(delay) == "table" then
    self.triggers[tag] = {type = "during", timer = 0, unresolved_delay = delay, delay = self:resolve_delay(delay), action = action, after = after}
  elseif type(delay) == "function" then
    self.triggers[tag] = {type = "conditional_during", condition = delay, last_condition = false, action = action, after = after}
  end
end


-- Tweens the target's values specified by the source table for delay seconds.
function Trigger:tween(delay, target, source, method, after, tag)
  method = method or math.linear
  after = after or function() end
  tag = tag or _safe_uid()
  local initial_values = {}
  for k, _ in pairs(source) do initial_values[k] = target[k] or 0 end
  self.triggers[tag] = {type = "tween", timer = 0, unresolved_delay = delay, delay = self:resolve_delay(delay), target = target, initial_values = initial_values, source = source, method = method, after = after}
end


-- Cancels a trigger action based on its tag.
function Trigger:cancel(tag)
  if self.triggers[tag] and self.triggers[tag].type == "run" then
    self.triggers[tag].after()
  end
  self.triggers[tag] = nil
end


-- Resets the timer for a tag.
function Trigger:reset(tag)
  if not self.triggers[tag] then return end
  self.triggers[tag].timer = 0
end


-- Returns the delay of a given tag.
function Trigger:get_delay(tag)
  if not self.triggers[tag] then return end
  return self.triggers[tag].delay
end


-- Returns the current iteration of an every trigger action with the given tag.
function Trigger:get_every_iteration(tag)
  if not self.triggers[tag] then return 0 end
  return self.triggers[tag].max_times - self.triggers[tag].times 
end


-- Sets a multiplier for an every tag.
function Trigger:set_every_multiplier(tag, multiplier)
  if not self.triggers[tag] then return end
  self.triggers[tag].multiplier = multiplier or 1
end


function Trigger:get_every_multiplier(tag)
  if not self.triggers[tag] then return end
  return self.triggers[tag].multiplier
end


-- Returns the elapsed time of a given trigger as a number between 0 and 1.
function Trigger:get_during_elapsed_time(tag)
  if not self.triggers[tag] then return end
  return self.triggers[tag].timer/self.triggers[tag].delay
end


function Trigger:get_timer_and_delay(tag)
  if not self.triggers[tag] then return end
  return self.triggers[tag].timer, self.triggers[tag].delay
end


function Trigger:get_time()
  return self.time
end


function Trigger:resolve_delay(delay)
  if type(delay) == "table" then
    return random:float(delay[1], delay[2])
  else
    return delay
  end
end


function Trigger:destroy()
  self.triggers = nil
end


function Trigger:update(dt)
  self.time = self.time + dt

  for tag, trigger in pairs(self.triggers) do
    if trigger.timer then
      trigger.timer = trigger.timer + dt
    end

    if trigger.type == "run" then
      trigger.action()

    elseif trigger.type == "cooldown" then
      if trigger.timer > trigger.delay*trigger.multiplier and trigger.condition() then
        trigger.action()
        trigger.timer = 0
        trigger.delay = self:resolve_delay(trigger.unresolved_delay)
        if trigger.times > 0 then
          trigger.times = trigger.times - 1
          if trigger.times <= 0 then
            trigger.after()
            self.triggers[tag] = nil
          end
        end
      end

    elseif trigger.type == "after" then
      if trigger.timer > trigger.delay then
        trigger.action()
        self.triggers[tag] = nil
      end

    elseif trigger.type == "conditional_after" then
      if trigger.condition() then
        trigger.action()
        self.triggers[tag] = nil
      end

    elseif trigger.type == "every" then
      if trigger.timer > trigger.delay*trigger.multiplier then
        trigger.action()
        trigger.timer = trigger.timer - trigger.delay*trigger.multiplier
        trigger.delay = self:resolve_delay(trigger.unresolved_delay)
        if trigger.times > 0 then
          trigger.times = trigger.times - 1
          if trigger.times <= 0 then
            trigger.after()
            self.triggers[tag] = nil
          end
        end
      end

    elseif trigger.type == "conditional_every" then
      local condition = trigger.condition()
      if condition and not trigger.last_condition then
        trigger.action()
        if trigger.times > 0 then
          trigger.times = trigger.times - 1
          if trigger.times <= 0 then
            trigger.after()
            self.triggers[tag] = nil
          end
        end
      end
      trigger.last_condition = condition

    elseif trigger.type == "during" then
      trigger.action(dt)
      if trigger.timer > trigger.delay then
        trigger.after()
        self.triggers[tag] = nil
      end

    elseif trigger.type == "conditional_during" then
      local condition = trigger.condition()
      if condition then
        trigger.action()
      end
      if trigger.last_condition and not condition then
        trigger.after()
      end
      trigger.last_condition = condition

    elseif trigger.type == "tween" then
      if trigger.timer > trigger.delay then
        -- Snap to exact final values before firing callback to avoid overshoot
        for k, v in pairs(trigger.source) do
          trigger.target[k] = v
        end
        trigger.after()
        self.triggers[tag] = nil
      else
        local t = trigger.method(trigger.timer/trigger.delay)
        for k, v in pairs(trigger.source) do
          trigger.target[k] = math.lerp(t, trigger.initial_values[k], v)
        end
      end
    end
  end
end
