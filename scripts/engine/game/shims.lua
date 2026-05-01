-- SNKRX Engine Shims - Missing API stubs for UrhoX
-- Provides: love.timer, love.event, love.window, love.mouse,
--           system (save/load/url), steam stubs, SoundTag, GradientImage,
--           Contact wrapper, and misc globals.

------------------------------------------------------------------------
-- love.* shims
------------------------------------------------------------------------
love = love or {}

-- love.timer
love.timer = love.timer or {}
local _start_time = os.clock()
function love.timer.getTime()
  return time or (os.clock() - _start_time)
end

-- love.event
love.event = love.event or {}
function love.event.quit()
  -- UrhoX: request engine exit
  if engine then
    engine:Exit()
  end
end

-- love.window
love.window = love.window or {}
function love.window.setMode(w, h, flags)
  -- UrhoX: SetMode is disabled; do nothing but store for reference
end
function love.window.getMode()
  local w = urho_graphics and urho_graphics:GetWidth() or 480
  local h = urho_graphics and urho_graphics:GetHeight() or 270
  return w, h, {}
end

-- love.mouse
love.mouse = love.mouse or {}
function love.mouse.setCursor(cursor)
  -- UrhoX: cursor management not needed (NanoVG game)
end
function love.mouse.getSystemCursor(name)
  return name -- return a string token (unused)
end

------------------------------------------------------------------------
-- system.* shims (save/load state, run persistence, open URL)
------------------------------------------------------------------------
-- Uses UrhoX File API for persistence (sandboxed file access)
local cjson_ok, cjson = pcall(require, "cjson")
if not cjson_ok then
  -- Minimal JSON fallback (already have cjson in most UrhoX builds)
  cjson = nil
end

local function json_encode(t)
  if cjson then return cjson.encode(t) end
  -- Fallback: simple serialization for tables
  return tostring(t)
end

local function json_decode(s)
  if cjson then return cjson.decode(s) end
  return nil
end

local function file_write(path, content)
  if not rawget(_G, 'fileSystem') then return false end
  local ok, f = pcall(File, path, FILE_WRITE)
  if not ok or not f or not f:IsOpen() then return false end
  f:WriteString(content)
  f:Close()
  return true
end

local function file_read(path)
  if not rawget(_G, 'fileSystem') then return nil end
  local ok, exists = pcall(function() return fileSystem:FileExists(path) end)
  if not ok or not exists then return nil end
  local ok2, f = pcall(File, path, FILE_READ)
  if not ok2 or not f or not f:IsOpen() then return nil end
  local content = f:ReadString()
  f:Close()
  if content and #content > 0 then
    return content
  end
  return nil
end

-- system global
system = system or {}

function system.save_state()
  -- Save global persistent state
  local data = rawget(_G, 'state') or {}
  local ok, encoded = pcall(json_encode, data)
  if ok and encoded then
    file_write("snkrx_state.json", encoded)
  end
end

function system.load_state()
  local content = file_read("snkrx_state.json")
  if content then
    local ok, data = pcall(json_decode, content)
    if ok and data then
      return data
    end
  end
  return nil
end

function system.save_run(level, loop, gold_val, units, passives, shop_level, shop_xp, passive_pool, locked)
  local data = {
    level = level,
    loop = loop,
    gold = gold_val,
    units = units,
    passives = passives,
    shop_level = shop_level,
    shop_xp = shop_xp,
    run_passive_pool = passive_pool,
    locked_state = locked,
  }
  local ok, encoded = pcall(json_encode, data)
  if ok and encoded then
    file_write("snkrx_run.json", encoded)
  end
end

function system.load_run()
  local content = file_read("snkrx_run.json")
  if content then
    local ok, data = pcall(json_decode, content)
    if ok and data then
      return data
    end
  end
  return {}
end

function system.open_url(url)
  -- UrhoX: no browser available, log it
  print("[system.open_url] " .. tostring(url))
end

function system.type_count(t, type_name)
  -- Count items of a specific type in a table
  local count = 0
  if t then
    for _, v in pairs(t) do
      if type(v) == 'table' and v.type == type_name then
        count = count + 1
      end
    end
  end
  return count
end

------------------------------------------------------------------------
-- steam.* stubs (no-op, game runs without Steam)
------------------------------------------------------------------------
steam = steam or {}
steam.userStats = steam.userStats or {}
function steam.userStats.setAchievement(name) end
function steam.userStats.storeStats() end
function steam.userStats.getAchievement(name) return false end
function steam.userStats.requestCurrentStats() end
function steam.userStats.resetAllStats(includeAchievements) end

steam.friends = steam.friends or {}
function steam.friends.setRichPresence(key, value) end

function steam.shutdown() end

------------------------------------------------------------------------
-- SoundTag class (grouped volume control for sfx/music)
------------------------------------------------------------------------
SoundTag = Object:extend()

function SoundTag:init()
  self.volume = 1
  return self
end

function SoundTag:set_volume(v)
  self.volume = v
  return self
end

------------------------------------------------------------------------
-- GradientImage class — defined in engine/graphics/image.lua
-- (removed duplicate definition; image.lua's multi-stop version is used)
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Contact wrapper (LÖVE2D physics contact → position/normal from UrhoX)
------------------------------------------------------------------------
Contact = Object:extend()

function Contact:init(x, y, nx, ny)
  self._x = x or 0
  self._y = y or 0
  self._nx = nx or 0
  self._ny = ny or -1
  return self
end

function Contact:getPositions()
  return self._x, self._y
end

function Contact:getNormal()
  return self._nx, self._ny
end

------------------------------------------------------------------------
-- Misc globals expected by SNKRX game code
------------------------------------------------------------------------
mods = nil  -- no mod support
current_new_game_plus = 0

-- Ensure 'state' global exists (persistent game state)
if not rawget(_G, 'state') then
  local ok, loaded = pcall(system.load_state)
  if ok and loaded then
    state = loaded
  else
    state = {}
  end
end
