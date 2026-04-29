-- SNKRX Engine Sound - UrhoX Adapter
-- Replaces LÖVE2D's love.audio with UrhoX's SoundSource component.
--
-- Architecture:
--   SNKRX Sound wraps love.audio.newSource (static).
--   UrhoX loads Sound resources via cache and plays via SoundSource component on a node.
--
-- Key changes:
--   love.audio.newSource(path, 'static') → cache:GetResource("Sound", path)
--   source:play/stop/setVolume/setPitch → SoundSource component methods

Sound = Object:extend()

function Sound:init(filename, args)
  self.tag = args and args.tag
  self.tags = args and args.tags  -- support {tags = {music}} style
  self.filename = filename
  self.volume = 0.5
  self.pitch = 1.0
  -- Original SNKRX prepends 'assets/sounds/' to filename.
  -- In UrhoX, assets/ is a resource root, so we prepend 'sounds/'.
  local path = "sounds/" .. filename
  self.resource = cache:GetResource("Sound", path)
  return self
end


function Sound:play(volume_or_args, args)
  -- Support both calling conventions:
  --   Original SNKRX: sound:play{pitch = 1.0, volume = 0.5}  (single table arg)
  --   Adapter style:  sound:play(0.5, {pitch = 1.0})          (volume + args)
  local volume, pitch
  if type(volume_or_args) == 'table' then
    -- Original SNKRX style: first arg is a table with pitch/volume
    pitch = volume_or_args.pitch or 1
    volume = volume_or_args.volume or 0.5
  else
    pitch = args and args.pitch or 1
    volume = volume_or_args or 0.5
  end

  -- Store current volume/pitch for later tween access
  rawset(self, 'volume', volume)
  rawset(self, 'pitch', pitch)

  if self.resource and scene_ then
    -- Stop previous playback if we have an active source
    if self._source_node then
      local src = self._source_node:GetComponent("SoundSource")
      if src then src:Stop() end
      self._source_node:Remove()
    end

    -- Create a temporary node with SoundSource to play
    self._source_node = scene_:CreateChild("SFX")
    local src = self._source_node:CreateComponent("SoundSource")
    src:SetAutoRemoveMode(REMOVE_NODE)
    local tag_volume = 1
    if self.tag then
      if self.tag.volume then tag_volume = self.tag.volume end
    end
    local gain = volume * (sfx_volume or 1) * tag_volume
    src:Play(self.resource, self.resource.frequency * pitch, gain)
  end
  return self
end


function Sound:stop()
  if self._source_node then
    local src = self._source_node:GetComponent("SoundSource")
    if src then src:Stop() end
    self._source_node:Remove()
    self._source_node = nil
  end
  return self
end


function Sound:is_playing()
  if self._source_node then
    local src = self._source_node:GetComponent("SoundSource")
    if src then return src.playing end
  end
  return false
end


function Sound:isStopped()
  return not self:is_playing()
end


-- Sync volume/pitch to the active SoundSource (called when tween modifies them)
function Sound:_sync_properties()
  if self._source_node then
    local src = self._source_node:GetComponent("SoundSource")
    if src then
      local tag_volume = 1
      if self.tag then
        if self.tag.volume then tag_volume = self.tag.volume end
      end
      -- Also check tags table (used by songs: {tags = {music}})
      if self.tags then
        for _, t in ipairs(self.tags) do
          if type(t) == 'table' and t.volume then
            tag_volume = t.volume
          end
        end
      end
      src:SetGain((self.volume or 0.5) * (sfx_volume or 1) * tag_volume)
      -- Pitch: scale the base frequency
      local base_freq = self.resource and self.resource.frequency or 44100
      src:SetFrequency(base_freq * (self.pitch or 1))
    end
  end
end


-- Auto-sync when tween system sets volume/pitch via direct assignment
local _Sound_mt_newindex = Sound.__newindex
function Sound:__newindex(k, v)
  rawset(self, k, v)
  if (k == 'volume' or k == 'pitch') and self._source_node then
    self:_sync_properties()
  end
end
