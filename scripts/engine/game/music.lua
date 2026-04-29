-- SNKRX Engine Music - UrhoX Adapter
-- Replaces LÖVE2D's love.audio streaming source with UrhoX SoundSource.
--
-- Key changes:
--   love.audio.newSource(path, 'stream') → cache:GetResource("Sound", path) + SetLooped(true)
--   source:play/stop/setVolume → SoundSource component methods

Music = Object:extend()

function Music:init(filename)
  self.filename = filename
  self.volume = 0.5
  self.pitch = 1.0
  self.resource = cache:GetResource("Sound", filename)
  if self.resource then
    self.resource:SetLooped(true)
  end
  return self
end


function Music:play(volume_or_args)
  -- Support both calling conventions:
  --   Original SNKRX: music:play{volume = 0.5}  (single table arg)
  --   Adapter style:  music:play(0.5)            (number)
  local vol
  if type(volume_or_args) == 'table' then
    vol = volume_or_args.volume or 0.5
    if volume_or_args.pitch then self.pitch = volume_or_args.pitch end
  else
    vol = volume_or_args or 0.5
  end
  self.volume = vol

  if self.resource then
    -- Stop previous if playing
    self:stop()

    -- Create a persistent node for music playback
    self._source_node = scene_:CreateChild("Music")
    local src = self._source_node:CreateComponent("SoundSource")
    src:SetSoundType("Music")
    src:SetGain(self.volume * (music_volume or 1))
    src:Play(self.resource)
  end
  return self
end


function Music:stop()
  if self._source_node then
    local src = self._source_node:GetComponent("SoundSource")
    if src then src:Stop() end
    self._source_node:Remove()
    self._source_node = nil
  end
  return self
end


function Music:set_volume(volume)
  self.volume = volume
  if self._source_node then
    local src = self._source_node:GetComponent("SoundSource")
    if src then src:SetGain(volume * (music_volume or 1)) end
  end
  return self
end


function Music:is_playing()
  if self._source_node then
    local src = self._source_node:GetComponent("SoundSource")
    if src then return src.playing end
  end
  return false
end


function Music:isStopped()
  return not self:is_playing()
end


-- Sync volume/pitch properties to UrhoX SoundSource.
-- Called automatically via __newindex when volume or pitch are assigned,
-- and also by arena.lua every frame via `main_song_instance.pitch = ...`
function Music:_sync_properties()
  if self._source_node then
    local src = self._source_node:GetComponent("SoundSource")
    if src then
      src:SetGain((self.volume or 0.5) * (music_volume or 1))
      src:SetFrequency(src:GetFrequency() > 0 and (self.pitch or 1) * 44100 or 44100)
    end
  end
end


-- Override __newindex to auto-sync volume/pitch changes from tween system.
-- The tween system sets `target[k] = lerped_value` each frame, so intercepting
-- __newindex lets us automatically apply changes to the UrhoX SoundSource.
local _music_mt = getmetatable(Music) or {}
local _orig_newindex = _music_mt.__newindex

-- We need to hook into the instance metatable, not the class.
-- Do this by overriding the __newindex on Music's prototype.
local _Music_set = Music.__newindex
function Music:__newindex(k, v)
  rawset(self, k, v)
  if (k == 'volume' or k == 'pitch') and self._source_node then
    self:_sync_properties()
  end
end
