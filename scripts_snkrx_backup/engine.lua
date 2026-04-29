-- engine.lua (UrhoX port)
-- Lightweight utility functions, particles, screen shake, colors

-- ============================================================================
-- Math Utilities
-- ============================================================================
function circles_collide(x1, y1, r1, x2, y2, r2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dist_sq = dx * dx + dy * dy
    local radii = r1 + r2
    return dist_sq <= radii * radii
end

function point_in_rect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

function distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

function angle_to(x1, y1, x2, y2)
    return math.atan(y2 - y1, x2 - x1)
end

function clamp(val, min_val, max_val)
    return math.max(min_val, math.min(max_val, val))
end

function lerp(a, b, t)
    return a + (b - a) * t
end

function random_float(min_val, max_val)
    return min_val + math.random() * (max_val - min_val)
end

function normalize_angle(a)
    while a > math.pi do a = a - 2 * math.pi end
    while a < -math.pi do a = a + 2 * math.pi end
    return a
end

-- ============================================================================
-- Timer
-- ============================================================================
Timer = {}
Timer.__index = Timer

function Timer.new(duration, callback, repeating)
    local self = setmetatable({}, Timer)
    self.duration = duration
    self.time = 0
    self.callback = callback
    self.repeating = repeating or false
    self.finished = false
    return self
end

function Timer:update(dt)
    if self.finished then return end
    self.time = self.time + dt
    if self.time >= self.duration then
        if self.callback then self.callback() end
        if self.repeating then
            self.time = self.time - self.duration
        else
            self.finished = true
        end
    end
end

-- ============================================================================
-- Tween
-- ============================================================================
function tween_value(start_val, end_val, current_time, duration)
    local t = clamp(current_time / duration, 0, 1)
    t = 1 - (1 - t) * (1 - t) -- ease out quad
    return lerp(start_val, end_val, t)
end

-- ============================================================================
-- Flash Effect
-- ============================================================================
FlashEffect = {}
FlashEffect.__index = FlashEffect

function FlashEffect.new(duration)
    local self = setmetatable({}, FlashEffect)
    self.duration = duration or 0.1
    self.time = 0
    self.active = false
    return self
end

function FlashEffect:trigger()
    self.active = true
    self.time = 0
end

function FlashEffect:update(dt)
    if not self.active then return end
    self.time = self.time + dt
    if self.time >= self.duration then
        self.active = false
    end
end

function FlashEffect:get_alpha()
    if not self.active then return 0 end
    return 1 - (self.time / self.duration)
end

-- ============================================================================
-- Screen Shake
-- ============================================================================
ScreenShake = {
    x = 0,
    y = 0,
    intensity = 0,
    duration = 0,
    time = 0,
}

function ScreenShake.trigger(intensity, duration)
    ScreenShake.intensity = intensity
    ScreenShake.duration = duration
    ScreenShake.time = 0
end

function ScreenShake.update(dt)
    if ScreenShake.time < ScreenShake.duration then
        ScreenShake.time = ScreenShake.time + dt
        local t = 1 - (ScreenShake.time / ScreenShake.duration)
        local current_intensity = ScreenShake.intensity * t
        ScreenShake.x = random_float(-current_intensity, current_intensity)
        ScreenShake.y = random_float(-current_intensity, current_intensity)
    else
        ScreenShake.x = 0
        ScreenShake.y = 0
    end
end

-- ============================================================================
-- Particle System (NanoVG)
-- ============================================================================
Particles = {}
Particles.__index = Particles

function Particles.new()
    local self = setmetatable({}, Particles)
    self.particles = {}
    return self
end

function Particles:emit(x, y, count, color, speed, lifetime)
    for i = 1, count do
        local angle = random_float(0, math.pi * 2)
        local spd = random_float(speed * 0.5, speed)
        table.insert(self.particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * spd,
            vy = math.sin(angle) * spd,
            life = lifetime or 0.5,
            max_life = lifetime or 0.5,
            r = color[1],
            g = color[2],
            b = color[3],
            size = random_float(1, 3),
        })
    end
end

function Particles:update(dt)
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vx = p.vx * 0.98
        p.vy = p.vy * 0.98
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(self.particles, i)
        end
    end
end

function Particles:draw(vg)
    for _, p in ipairs(self.particles) do
        local alpha = p.life / p.max_life
        nvgBeginPath(vg)
        nvgRect(vg, p.x - p.size / 2, p.y - p.size / 2, p.size, p.size)
        nvgFillColor(vg, nvgRGBAf(p.r, p.g, p.b, alpha))
        nvgFill(vg)
    end
end

-- Global particle system
particles = Particles.new()

-- ============================================================================
-- Color Palette (SNKRX-style)
-- ============================================================================
COLORS = {
    warrior    = {0.9, 0.6, 0.2},
    mage       = {0.4, 0.5, 0.9},
    ranger     = {0.3, 0.8, 0.3},
    rogue      = {0.8, 0.3, 0.5},
    healer     = {0.9, 0.9, 0.4},
    enchanter  = {0.7, 0.4, 0.9},

    common     = {0.7, 0.7, 0.7},
    uncommon   = {0.3, 0.8, 0.3},
    rare       = {0.3, 0.5, 0.9},
    epic       = {0.7, 0.3, 0.9},
    legendary  = {0.9, 0.7, 0.2},

    bg         = {0.1, 0.1, 0.15},
    text       = {1.0, 1.0, 1.0},
    text_dim   = {0.6, 0.6, 0.6},
    gold       = {1.0, 0.85, 0.2},
    hp_bar     = {0.2, 0.8, 0.2},
    hp_bg      = {0.3, 0.1, 0.1},
    enemy      = {0.8, 0.2, 0.2},
    projectile = {1.0, 1.0, 0.5},
}

-- ============================================================================
-- NanoVG Drawing Helpers
-- ============================================================================
function draw_circle_outline(vg, x, y, r, color, line_width)
    -- Filled circle
    nvgBeginPath(vg)
    nvgCircle(vg, x, y, r)
    nvgFillColor(vg, nvgRGBAf(color[1], color[2], color[3], 1))
    nvgFill(vg)
    -- Outline
    nvgBeginPath(vg)
    nvgCircle(vg, x, y, r)
    nvgStrokeColor(vg, nvgRGBAf(color[1] * 0.6, color[2] * 0.6, color[3] * 0.6, 1))
    nvgStrokeWidth(vg, line_width or 1)
    nvgStroke(vg)
end

function draw_hp_bar(vg, x, y, w, h, current, max_val, fg_color, bg_color)
    bg_color = bg_color or COLORS.hp_bg
    fg_color = fg_color or COLORS.hp_bar
    -- Background
    nvgBeginPath(vg)
    nvgRect(vg, x, y, w, h)
    nvgFillColor(vg, nvgRGBAf(bg_color[1], bg_color[2], bg_color[3], 0.8))
    nvgFill(vg)
    -- Fill
    local fill = clamp(current / max_val, 0, 1)
    nvgBeginPath(vg)
    nvgRect(vg, x, y, w * fill, h)
    nvgFillColor(vg, nvgRGBAf(fg_color[1], fg_color[2], fg_color[3], 0.9))
    nvgFill(vg)
end

-- Draw text centered at position
function draw_text_centered(vg, text, x, y, w, color, size)
    nvgFontFace(vg, "game")
    nvgFontSize(vg, size or 10)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBAf(color[1], color[2], color[3], color[4] or 1))
    nvgText(vg, x + (w or 0) / 2, y, text)
end

-- Draw text at position
function draw_text(vg, text, x, y, color, size)
    nvgFontFace(vg, "game")
    nvgFontSize(vg, size or 10)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(vg, nvgRGBAf(color[1], color[2], color[3], color[4] or 1))
    nvgText(vg, x, y, text)
end
