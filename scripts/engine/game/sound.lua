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
  -- Store volume/pitch in a hidden table so __newindex always fires for them
  rawset(self, '_snd_props', { volume = 0.5, pitch = 1.0 })
  -- Original SNKRX prepends 'assets/sounds/' to filename.
  -- In UrhoX, assets/ is a resource root, so we prepend 'sounds/'.
  -- DWP: Sound is a media resource type — cache:GetResource returns a placeholder
  -- (silent) immediately and hot-swaps real audio data once downloaded.
  -- Do NOT wrap in pcall — it can interfere with DWP placeholder mechanism.
  local path = "sounds/" .. filename
  self.resource = cache:GetResource("Sound", path)
  if not self.resource then
    print(string.format("[Sound] WARN: cache:GetResource returned nil for '%s'", path))
  end
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

  -- Store current volume/pitch in hidden props table
  self._snd_props.volume = volume
  self._snd_props.pitch = pitch

  -- Lazy-load: if resource was nil at construction, retry now
  if not self.resource and self.filename then
    local path = "sounds/" .. self.filename
    self.resource = cache:GetResource("Sound", path)
  end

  if self.resource and scene_ then
    -- Stop previous playback if we have an active source
    if self._source_node then
      local src = self._source_node:GetComponent("SoundSource")
      if src then src:Stop() end
      self._source_node:Remove()
    end

    -- Create a node with SoundSource to play.
    -- Do NOT use SetAutoRemoveMode(REMOVE_NODE) because it would delete the
    -- underlying C++ node while self._source_node still references it, causing
    -- stale-pointer errors on the next play() call.  We manage the node
    -- lifecycle ourselves (remove old node at the top of play() / stop()).
    self._source_node = scene_:CreateChild("SFX")
    local src = self._source_node:CreateComponent("SoundSource")
    local tag_volume = 1
    if self.tag then
      if self.tag.volume then tag_volume = self.tag.volume end
    elseif self.tags then
      for _, t in ipairs(self.tags) do
        if type(t) == 'table' and t.volume ~= nil then
          tag_volume = t.volume
        end
      end
    end
    local gain = volume * (sfx_volume or 1) * tag_volume
    local freq = self.resource.frequency * pitch
    src:Play(self.resource, freq, gain)
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
      local props = rawget(self, '_snd_props') or {}
      src:SetGain((props.volume or 0.5) * (sfx_volume or 1) * tag_volume)
      -- Pitch: scale the base frequency
      local base_freq = self.resource and self.resource.frequency or 44100
      src:SetFrequency(base_freq * (props.pitch or 1))
    end
  end
end


-- Auto-sync when tween system sets volume/pitch via direct assignment.
-- volume/pitch are stored in _snd_props (never rawset on instance) so __newindex
-- fires every time the tween system writes to them.
local _Sound_base_index = Sound.__index
function Sound:__index(k)
  -- Check _snd_props first for volume/pitch
  if k == 'volume' or k == 'pitch' then
    local props = rawget(self, '_snd_props')
    if props then return props[k] end
  end
  -- Fall through to normal class lookup
  local raw = rawget(self, k)
  if raw ~= nil then return raw end
  if type(_Sound_base_index) == 'table' then
    return _Sound_base_index[k]
  elseif type(_Sound_base_index) == 'function' then
    return _Sound_base_index(self, k)
  end
end

function Sound:__newindex(k, v)
  if (k == 'volume' or k == 'pitch') then
    local props = rawget(self, '_snd_props')
    if props then
      props[k] = v
      if rawget(self, '_source_node') then
        self:_sync_properties()
      end
      return
    end
  end
  rawset(self, k, v)
end
