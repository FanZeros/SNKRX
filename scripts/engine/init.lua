-- Lua 5.1 → 5.4 compatibility shims
unpack = unpack or table.unpack

-- ============================================================================
-- SNKRX Engine Bootstrap for UrhoX
-- ============================================================================
-- Initializes the LÖVE2D-compatible engine adapter layer.
-- All engine modules set globals directly (Object, Trigger, Camera, etc.).
--
-- Usage:
--   local Engine = require("engine.init")
--   -- In Start():
--   Engine.init(nvg_context)
--   -- In Update:
--   Engine.update(dt)
--   -- In NanoVGRender:
--   Engine.draw()
-- ============================================================================

local M = {}

-- ============================================================================
-- Design resolution (same as original SNKRX)
-- ============================================================================
dgw = 480  -- design width  (fixed, for arena/UI positioning)
dgh = 270  -- design height (fixed, for arena/UI positioning)
gw = 480   -- viewport width  (dynamic, recalculated to fill screen)
gh = 270   -- viewport height (dynamic, recalculated to fill screen)
sx = 1
sy = 1
screen_ox = 0
screen_oy = 0
time = 0
refresh_rate = 60
sfx_volume = 0.5
music_volume = 0.5

-- Game state globals used by shared.lua, arena.lua, buy_screen.lua
slow_amount = 1
music_slow_amount = 1
flash_color = nil
flashing = false

-- Save UrhoX's built-in subsystems before engine modules overwrite them
urho_graphics = graphics
urho_input = input

-- ============================================================================
-- Module loading order (respecting dependencies)
-- ============================================================================

-- 1. OOP base (no dependencies)
require("engine.game.object")

-- 2. Data structure extensions (depends on nothing / Object)
require("engine.datastructures.table")
require("engine.datastructures.string")

-- 3. Math utilities (depends on Object)
require("engine.math.math")
require("engine.math.vector")
require("engine.math.random")
require("engine.math.spring")

-- 4. Geometry modules (depends on math, Vector)
require("engine.math.circle")
require("engine.math.polygon")
require("engine.math.line")
require("engine.math.rectangle")
require("engine.math.triangle")
require("engine.math.chain")

-- 5. Core game systems (depends on Object, Random)
require("engine.game.trigger")
require("engine.game.collision")
require("engine.game.observer")
require("engine.game.state")
require("engine.game.container")
require("engine.game.springs")
require("engine.game.flashes")
require("engine.game.hitfx")
require("engine.game.input")
require("engine.game.anchor")
require("engine.game.draft")
require("engine.game.parent")
require("engine.game.stats")
require("engine.game.stepper")
require("engine.game.timer")
require("engine.game.system")
require("engine.game.shaders")

-- 6. Graphics modules (depends on Object, math, NanoVG globals)
require("engine.graphics.color")
require("engine.graphics.font")
require("engine.graphics.image")

-- 7. Camera (depends on Object, Vector, Spring, NanoVG globals)
require("engine.graphics.camera")

-- 8. Graphics + Layer (depends on Object, Color, Camera, NanoVG globals)
--    NOTE: This also defines global Layer class - do NOT load engine.game.layer
require("engine.graphics.graphics")

-- 9. Text system (depends on Graphics module-level functions)
require("engine.graphics.text")

-- 10. Animation and tileset (optional, depends on Image)
require("engine.graphics.animation")
require("engine.graphics.tileset")

-- 11. Canvas and Shader stubs (limited NanoVG support)
require("engine.graphics.canvas")
require("engine.graphics.shader")

-- 12. GameObject (depends on Object, Trigger)
require("engine.game.gameobject")

-- 13. Physics mixin (depends on Object, UrhoX Physics2D)
require("engine.game.physics")

-- 14. Steering behaviors (depends on Object, math)
require("engine.game.steering")

-- 15. Sound and Music (depends on UrhoX audio subsystem)
require("engine.game.sound")
require("engine.game.music")

-- 16. Shims (love.*, system.*, steam.*, SoundTag, GradientImage, Contact)
require("engine.game.shims")

-- 17. Group (depends on Object, Trigger, Camera, Physics, UrhoX Physics2D, Contact)
require("engine.game.group")

-- Skip engine.game.layer — Layer is already defined in graphics.lua

print("[Engine] All modules loaded successfully")

-- ============================================================================
-- Engine lifecycle
-- ============================================================================

--- Initialize the engine. Call this in Start() after creating the NanoVG context.
---@param nvg_ctx userdata  The NanoVG context from nvgCreate()
function M.init(nvg_ctx)
    -- Store NanoVG context globally (all engine modules reference 'vg')
    vg = nvg_ctx

    -- Calculate dynamic viewport to fill screen without stretching
    local physW = urho_graphics:GetWidth()
    local physH = urho_graphics:GetHeight()
    local dpr = urho_graphics:GetDPR()
    local logW = physW / dpr
    local logH = physH / dpr

    -- Dynamic viewport: expand gw/gh to fill the entire screen (no letterbox)
    local screenAspect = logW / logH
    local designAspect = dgw / dgh  -- 480/270 = 16/9
    if screenAspect >= designAspect then
        -- Screen is wider than or equal to 16:9: fix height, expand width
        gh = dgh
        gw = math.ceil(dgh * screenAspect)
    else
        -- Screen is narrower than 16:9: fix width, expand height
        gw = dgw
        gh = math.ceil(dgw / screenAspect)
    end
    local scale = logW / gw
    sx = scale
    sy = scale
    screen_ox = 0
    screen_oy = 0

    print(string.format("[Engine] Screen: %dx%d (logical: %.0fx%.0f, DPR: %.1f)", physW, physH, logW, logH, dpr))
    print(string.format("[Engine] Design: %dx%d, Viewport: %dx%d, Scale: %.2f", dgw, dgh, gw, gh, scale))

    -- Create global singleton instances
    random = Random()
    -- Camera position must match viewport center (gw/2, gh/2) to avoid net offset.
    -- Original a327ex uses Camera(gw/2, gh/2) where gw==dgw. With viewport expansion
    -- (gw > dgw), using dgw/2 causes a (gw-dgw)/2 rightward shift on all camera content.
    camera = Camera(gw / 2, gh / 2, gw, gh)

    -- Create the SNKRX Graphics manager (overwrites UrhoX's graphics global)
    -- This is intentional — the engine adapter layer manages its own layer system
    graphics = Graphics()
    graphics:init_module()

    -- Create the SNKRX Input manager (overwrites UrhoX's input global)
    -- urho_input was saved at module load time above for polling
    input = Input()
    input:bind_all()

    -- Reset time
    time = 0

    print("[Engine] Initialized successfully")
end

--- Update engine systems. Call this in HandleUpdate().
---@param dt number  Delta time in seconds
function M.update(dt)
    time = time + dt

    -- Poll UrhoX input subsystem → fill keyboard_state/mouse_state
    if input and input.poll_urho then
        input:poll_urho()
    end

    -- Update SNKRX input action states (pressed/down/released)
    if input and input.update then
        input:update(dt)
    end

    -- Update camera
    if camera then
        camera:update(dt)
    end
end

--- Draw all layers. Call this inside HandleNanoVGRender() between nvgBeginFrame/EndFrame.
--- NOTE: Layer:draw() internally applies nvgScale(vg, sx, sy), so no extra scaling needed here.
function M.draw()
    if graphics and graphics.draw then
        graphics:draw()
    end
end

--- Recalculate scale factors (call on window resize if needed).
function M.recalculate_scale()
    local physW = urho_graphics:GetWidth()
    local physH = urho_graphics:GetHeight()
    local dpr = urho_graphics:GetDPR()
    local logW = physW / dpr
    local logH = physH / dpr
    local screenAspect = logW / logH
    local designAspect = dgw / dgh
    if screenAspect >= designAspect then
        gh = dgh
        gw = math.ceil(dgh * screenAspect)
    else
        gw = dgw
        gh = math.ceil(dgw / screenAspect)
    end
    local scale = logW / gw
    sx = scale
    sy = scale
    screen_ox = 0
    screen_oy = 0
end

return M
