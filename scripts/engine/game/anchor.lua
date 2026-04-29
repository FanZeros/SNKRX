-- Anchor positions based on the virtual screen
-- gw, gh are global virtual screen dimensions (e.g. 480, 270)
function anchor(a, x_offset, y_offset)
  x_offset = x_offset or 0
  y_offset = y_offset or 0
  if a == 'center' then return gw / 2 + x_offset, gh / 2 + y_offset
  elseif a == 'left' then return x_offset, gh / 2 + y_offset
  elseif a == 'right' then return gw + x_offset, gh / 2 + y_offset
  elseif a == 'top' then return gw / 2 + x_offset, y_offset
  elseif a == 'bottom' then return gw / 2 + x_offset, gh + y_offset
  elseif a == 'top_left' then return x_offset, y_offset
  elseif a == 'top_right' then return gw + x_offset, y_offset
  elseif a == 'bottom_left' then return x_offset, gh + y_offset
  elseif a == 'bottom_right' then return gw + x_offset, gh + y_offset
  end
end
