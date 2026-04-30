-- SNKRX Engine Text Module
-- Tagged text system with character-level effects.
-- Uses graphics.push/pop/print/set_color (module-level functions from graphics.lua).
-- Nearly verbatim from SNKRX — only drawing calls go through our NanoVG adapter.

Text = Object:extend()
function Text:init(text_data, text_tags)
  self.t = Trigger()
  self.text_data = text_data
  self.text_tags = text_tags or {}
  self.white = Color(1, 1, 1, 1)
  self:set_text(text_data)
  return self
end


function Text:update(dt)
  self.t:update(dt)
  self:format_text()
  for _, line in ipairs(self.lines) do
    for i, c in ipairs(line.characters) do
      for k, v in pairs(self.text_tags) do
        for _, tag in ipairs(c.tags) do
          if tag == k then
            if v.actions.update then
              v.actions.update(c, dt, i, self)
            end
          end
        end
      end
    end
  end
end


-- Draws the text object centered at the specified location.
function Text:draw(x, y, r, sx, sy)
  -- Recalculate layout inside NanoVG frame (nvgTextBounds returns 0 outside frame)
  self:format_text()
  for _, line in ipairs(self.lines) do
    for i, c in ipairs(line.characters) do
      for k, v in pairs(self.text_tags) do
        for _, tag in ipairs(c.tags) do
          if tag == k then
            if v.actions.draw then
              v.actions.draw(c, i, self)
            end
          end
        end
      end
      graphics.push(x, y, r, sx, sy)
      graphics.print(c.character, line.font, x + c.x - self.w / 2, y + c.y - self.h / 2, c.r or 0, c.sx or 1, c.sy or c.sx or 1, c.ox or 0, c.oy or 0)
      graphics.pop()
      graphics.set_color(self.white)
    end
  end
end


function Text:format_text()
  self.w = 0
  for i, line in ipairs(self.lines) do
    local line_width = math.max(line.font:get_text_width(line.raw_text), line.alignment_width or 0)
    if line_width > self.w then
      self.w = line_width
    end
  end

  local x, y = 0, 0
  for j, line in ipairs(self.lines) do
    local h = (line.font.h * (line.height_multiplier or 1) + (line.height_offset or 0)) * (line.sy or 1)
    for i, c in ipairs(line.characters) do
      c.x = x
      c.y = y
      c.sx = line.sx or c.sx or 1
      c.sy = line.sy or c.sy or 1
      c.w = line.font:get_text_width(c.character)
      c.h = line.font.h
      x = x + line.font:get_text_width(c.character)
    end
    y = y + h
    x = 0
  end
  self.h = y

  for i, line in ipairs(self.lines) do
    if line.alignment == "right" then
      local text_width = 0
      for _, c in ipairs(line.characters) do text_width = text_width + line.font:get_text_width(c.character) end
      local left_over_width = self.w - (line.alignment_width or text_width)
      for _, c in ipairs(line.characters) do c.x = c.x + left_over_width end

    elseif line.alignment == "center" then
      local text_width = 0
      for _, c in ipairs(line.characters) do text_width = text_width + line.font:get_text_width(c.character) end
      local left_over_width = self.w - (line.alignment_width or text_width)
      for _, c in ipairs(line.characters) do c.x = c.x + left_over_width / 2 end

    elseif line.alignment == "justified" then
      local text_width = 0
      for _, c in ipairs(line.characters) do text_width = text_width + line.font:get_text_width(c.character) end
      local left_over_width = self.w - (line.alignment_width or text_width)
      local spaces_count = 0
      for _, c in ipairs(line.characters) do
        if c.character == " " then
          spaces_count = spaces_count + 1
        end
      end
      if spaces_count > 0 then
        local added_width_to_each_space = math.floor(left_over_width / spaces_count)
        local total_added_width = 0
        for _, c in ipairs(line.characters) do
          if c.character == " " then
            c.x = c.x + added_width_to_each_space
            total_added_width = total_added_width + added_width_to_each_space
          else
            c.x = c.x + total_added_width
          end
        end
      end
    end
  end
end


function Text:parse(text_data)
  for _, line in ipairs(text_data) do
    local tags = {}
    for i, tags_text, j in line.text:gmatch("()%[(.-)%]()") do
      if tags_text == "" then
        table.insert(tags, {i = tonumber(i), j = tonumber(j) - 1})
        line.tags = tags
      else
        local local_tags = {}
        for tag in tags_text:gmatch("[%w_]+") do table.insert(local_tags, tag) end
        table.insert(tags, {i = tonumber(i), j = tonumber(j) - 1, tags = local_tags})
        line.tags = tags
      end
    end
    if not line.tags then line.tags = {} end
  end

  for _, line in ipairs(text_data) do
    line.characters = {}
    local current_tags = nil
    -- UTF-8 aware character iteration
    local i = 1
    local text = line.text
    local len = #text
    while i <= len do
      -- Determine UTF-8 character byte length from leading byte
      local byte = text:byte(i)
      local char_len = 1
      if byte >= 0xF0 then char_len = 4
      elseif byte >= 0xE0 then char_len = 3
      elseif byte >= 0xC0 then char_len = 2
      end
      local c = text:sub(i, i + char_len - 1)
      local inside_tags = false
      for _, tag in ipairs(line.tags) do
        if i >= tag.i and i <= tag.j then
          inside_tags = true
          current_tags = tag.tags
          break
        end
      end
      if not inside_tags then
        table.insert(line.characters, {character = c, visible = true, tags = current_tags or {}})
      end
      i = i + char_len
    end
  end

  for _, line in ipairs(text_data) do
    local raw_text = ""
    for _, character in ipairs(line.characters) do
      raw_text = raw_text .. character.character
    end
    line.raw_text = raw_text
  end

  return text_data
end


function Text:set_text(text_data)
  self.lines = self:parse(text_data)
  self:format_text()
  for _, line in ipairs(self.lines) do
    for i, c in ipairs(line.characters) do
      for k, v in pairs(self.text_tags) do
        for _, tag in ipairs(c.tags) do
          if tag == k then
            if v.actions.init then
              v.actions.init(c, i, self)
            end
          end
        end
      end
    end
  end
end


function Text:set_alignment_width(line, alignment_width)
  self.alignment_width = alignment_width
  self:format_text()
  return self
end


function Text:set_line_height_data(line, offset, multiplier)
  self.lines[line].height_offset = offset or 0
  self.lines[line].height_multiplier = multiplier or 1
  self:format_text()
  return self
end


function Text:set_font(line, font)
  self.lines[line].font = font
  self:format_text()
  return self
end


function Text:set_alignment(line, alignment)
  self.lines[line].alignment = alignment
  self:format_text()
  return self
end


TextTag = Object:extend()
function TextTag:init(actions)
  self.actions = actions
end
