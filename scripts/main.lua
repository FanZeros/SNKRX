---@diagnostic disable: undefined-global
-- ============================================================================
-- SNKRX — UrhoX Entry Point
-- ============================================================================
-- Bridges the UrhoX lifecycle (Start/Update/NanoVGRender) to the original
-- SNKRX game loop (init/update/draw via the LÖVE2D-compatible engine adapter).
-- ============================================================================

require "LuaScripts/Utilities/Sample"

-- Load the engine adapter layer (sets all globals: Object, Trigger, Camera, etc.)
local Engine = require("engine.init")

-- Save UrhoX engine globals that game modules will overwrite
local _UrhoNode = Node  -- game/shared.lua defines Node = Object:extend()

-- Load game modules (order matters — later modules reference earlier ones)
require("game.shared")
require("game.objects")
require("game.mainmenu")
require("game.arena")
require("game.buy_screen")
require("game.player")
require("game.enemies")
require("game.media")

-- Load game data tables + init/update/draw/open_options/close_options
require("game.data")


-- ============================================================================
-- Globals expected by the original SNKRX code
-- ============================================================================
---@type number
slow_amount = 1
---@type number
music_slow_amount = 1
---@type number
frame = 0
---@type number
fixed_dt = 1 / 60
---@type number
run_time = 0
---@type number
gold = 3
---@type table
passives = {}
---@type table|nil
locked_state = nil
---@type number
max_units = 7
---@type boolean
debugging_memory = false
---@type boolean
flashing = false
---@type any
flash_color = nil
---@type table
run_passive_pool = {}
---@type number
new_game_plus = 0
---@type number
revive_count = 0
---@type number
max_revives = 1
---@type boolean
web = false
---@type number
msaa = 0
---@type number
ww = 0
---@type number
wh = 0

-- ============================================================================
-- UrhoX Entry Point
-- ============================================================================
function Start()
  -- Temporarily restore UrhoX Node for SampleStart (game code overwrote it)
  local _GameNode = Node
  Node = _UrhoNode
  SampleStart()
  Node = _GameNode

  -- Create a scene for audio playback (SoundSource components require a scene)
  -- SNKRX is a pure NanoVG 2D game, but UrhoX audio needs scene nodes.
  scene_ = Scene()
  scene_:CreateComponent("Octree")

  -- Create NanoVG context
  local nvg_ctx = nvgCreate(1)
  if nvg_ctx == nil then
    print("[SNKRX] ERROR: Failed to create NanoVG context")
    return
  end

  -- Initialize the engine adapter layer (creates graphics, camera, random, etc.)
  Engine.init(nvg_ctx)

  -- Store window dimensions
  ww = urho_graphics:GetWidth()
  wh = urho_graphics:GetHeight()

  -- Set up mouse and last_mouse globals (Vector)
  mouse = Vector(0, 0)
  last_mouse = Vector(0, 0)
  mouse_dt = Vector(0, 0)

  -- The global 'trigger' is used throughout the game for tweens/timers
  trigger = Trigger()

  -- Call the game's init() function (from data.lua)
  -- This sets up:
  --   - shared_init() (colors, fonts, canvases, star system)
  --   - Input bindings
  --   - Sound/Image/Music loading (~90 sounds, ~60 images)
  --   - All game data tables (characters, classes, passives, levels)
  --   - Main state machine: main = Main() → MainMenu
  local ok, err = pcall(init)
  if not ok then
    print("[SNKRX] FATAL: init() failed: " .. tostring(err))
    return
  end

  print("[SNKRX] Game initialized successfully")

  -- Subscribe to events
  SubscribeToEvent("Update", "HandleUpdate")
  SubscribeToEvent(vg, "NanoVGRender", "HandleNanoVGRender")
end


function Stop()
  system.save_state()
  if vg ~= nil then
    nvgDelete(vg)
    vg = nil
  end
end


-- ============================================================================
-- Update
-- ============================================================================
---@param eventType string
---@param eventData table
function HandleUpdate(eventType, eventData)
  local dt = eventData["TimeStep"]:GetFloat()

  -- Update engine systems (time, input, camera)
  Engine.update(dt)

  -- Reset touch zone steering each frame; Arena:update will re-enable if in active combat
  if input then input.touch_zone_steering = false end

  -- Update global trigger (used for tweens/timers throughout the game)
  trigger:update(dt)

  -- Update mouse position (in design resolution coordinates)
  -- mousePosition is in physical pixels → divide by DPR → logical pixels
  -- Then subtract letterbox offset and divide by scale to get design coords
  local dpr = urho_graphics:GetDPR()
  local mx = urho_input.mousePosition.x / dpr
  local my = urho_input.mousePosition.y / dpr
  local ox = screen_ox or 0
  local oy = screen_oy or 0
  mouse:set((mx - ox) / sx, (my - oy) / sy)
  mouse_dt:set(mouse.x - last_mouse.x, mouse.y - last_mouse.y)

  -- Call the game's update function (from data.lua)
  -- This calls main:update(dt) which updates the active state (MainMenu/Arena/BuyScreen)
  if main then
    update(dt * slow_amount)
  end

  -- Track frame count
  frame = frame + 1

  -- Clear per-frame input flags at end of frame
  if input then
    input.last_key_pressed = nil
  end
  last_mouse:set(mouse.x, mouse.y)

  -- Handle music looping
  if main_song_instance and main_song_instance:isStopped() then
    main_song_instance = _G[random:table{'song1', 'song2', 'song3', 'song4', 'song5'}]:play{volume = main_song_volume or 0.5}
  end
end


-- ============================================================================
-- NanoVG Render
-- ============================================================================
function HandleNanoVGRender(eventType, eventData)
  if vg == nil then return end

  local physW = urho_graphics:GetWidth()
  local physH = urho_graphics:GetHeight()
  local dpr = urho_graphics:GetDPR()
  local logW = physW / dpr
  local logH = physH / dpr

  nvgBeginFrame(vg, logW, logH, dpr)

  -- Draw background color (fill entire logical screen)
  local bg_color = graphics.get_background_color()
  nvgBeginPath(vg)
  nvgRect(vg, 0, 0, logW, logH)
  nvgFillColor(vg, nvgRGBAf(bg_color.r, bg_color.g, bg_color.b, bg_color.a or 1))
  nvgFill(vg)

  -- Call the game's draw function (from data.lua)
  -- This calls shared_draw(function() main:draw() end)
  -- shared_draw handles the multi-pass rendering pipeline (Canvas → NanoVG layers)
  if main then
    draw()
  end

  -- Replay all queued draw commands through the engine's layer system
  Engine.draw()

  nvgEndFrame(vg)
end
