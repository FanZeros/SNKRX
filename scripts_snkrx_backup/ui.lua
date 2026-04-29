-- ui.lua (UrhoX port)
-- UI utility functions: floating text, buttons, tooltips

require("snkrx.engine")

-- ============================================================================
-- Floating Text System
-- ============================================================================
floating_texts = {}

function spawn_floating_text(x, y, text, color, size)
    table.insert(floating_texts, {
        x = x,
        y = y,
        text = text,
        color = color or COLORS.text,
        size = size or 10,
        life = 1.0,
        max_life = 1.0,
        vy = -25,
    })
end

function update_floating_texts(dt)
    for i = #floating_texts, 1, -1 do
        local ft = floating_texts[i]
        ft.y = ft.y + ft.vy * dt
        ft.vy = ft.vy * 0.97
        ft.life = ft.life - dt
        if ft.life <= 0 then
            table.remove(floating_texts, i)
        end
    end
end

function draw_floating_texts(vg)
    for _, ft in ipairs(floating_texts) do
        local alpha = clamp(ft.life / ft.max_life, 0, 1)
        nvgFontFace(vg, "game")
        nvgFontSize(vg, ft.size)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBAf(ft.color[1], ft.color[2], ft.color[3], alpha))
        nvgText(vg, ft.x, ft.y, ft.text)
    end
end

-- ============================================================================
-- Button Drawing
-- ============================================================================
function draw_button(vg, x, y, w, h, text, selected, color, text_color)
    color = color or {0.2, 0.3, 0.5}
    text_color = text_color or COLORS.text

    -- Background
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 3)
    if selected then
        nvgFillColor(vg, nvgRGBAf(
            math.min(1, color[1] * 1.4),
            math.min(1, color[2] * 1.4),
            math.min(1, color[3] * 1.4), 1))
    else
        nvgFillColor(vg, nvgRGBAf(color[1], color[2], color[3], 0.8))
    end
    nvgFill(vg)

    -- Border
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 3)
    if selected then
        nvgStrokeColor(vg, nvgRGBAf(1, 1, 0.6, 0.9))
        nvgStrokeWidth(vg, 1.5)
    else
        nvgStrokeColor(vg, nvgRGBAf(0.4, 0.5, 0.7, 0.5))
        nvgStrokeWidth(vg, 1)
    end
    nvgStroke(vg)

    -- Text
    nvgFontFace(vg, "game")
    nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBAf(text_color[1], text_color[2], text_color[3], 1))
    nvgText(vg, x + w / 2, y + h / 2, text)
end

-- ============================================================================
-- Tooltip
-- ============================================================================
function draw_tooltip(vg, x, y, lines, max_width)
    max_width = max_width or 120
    local line_height = 10
    local padding = 5
    local h = #lines * line_height + padding * 2

    -- Clamp tooltip to screen
    if x + max_width > W - 5 then x = W - 5 - max_width end
    if y + h > H - 5 then y = H - 5 - h end

    -- Background
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, max_width, h, 3)
    nvgFillColor(vg, nvgRGBAf(0.05, 0.05, 0.1, 0.95))
    nvgFill(vg)

    -- Border
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, max_width, h, 3)
    nvgStrokeColor(vg, nvgRGBAf(0.3, 0.4, 0.6, 0.8))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- Text lines
    nvgFontFace(vg, "game")
    nvgFontSize(vg, 8)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    for i, line in ipairs(lines) do
        local color = line.color or COLORS.text
        nvgFillColor(vg, nvgRGBAf(color[1], color[2], color[3], 1))
        nvgText(vg, x + padding, y + padding + (i - 1) * line_height, line.text)
    end
end

-- ============================================================================
-- Info Bar (top HUD)
-- ============================================================================
function draw_hud(vg)
    -- Top bar background
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, W, 20)
    nvgFillColor(vg, nvgRGBAf(0.05, 0.05, 0.1, 0.9))
    nvgFill(vg)

    nvgFontFace(vg, "game")
    nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

    -- HP
    local hp_text = "HP: " .. math.floor(hp) .. "/" .. max_hp
    nvgFillColor(vg, nvgRGBAf(COLORS.hp_bar[1], COLORS.hp_bar[2], COLORS.hp_bar[3], 1))
    nvgText(vg, 5, 10, hp_text)

    -- HP bar
    draw_hp_bar(vg, 60, 6, 50, 6, hp, max_hp)

    -- Gold
    nvgFillColor(vg, nvgRGBAf(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1))
    nvgText(vg, 120, 10, "Gold: " .. gold)

    -- Round
    nvgFillColor(vg, nvgRGBAf(COLORS.text[1], COLORS.text[2], COLORS.text[3], 1))
    nvgText(vg, 190, 10, "Round: " .. round)

    -- Score
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBAf(COLORS.text[1], COLORS.text[2], COLORS.text[3], 1))
    nvgText(vg, W - 5, 10, "Score: " .. score)

    -- Enemies remaining
    local remaining = enemies_to_spawn - enemies_spawned + #enemies
    if remaining > 0 then
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBAf(COLORS.enemy[1], COLORS.enemy[2], COLORS.enemy[3], 0.8))
        nvgText(vg, W / 2, 10, "Enemies: " .. remaining)
    end

    -- Bottom: synergies
    local synergies = get_active_synergies(snake_units)
    if #synergies > 0 then
        nvgFontSize(vg, 7)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        local sx = 5
        for _, syn in ipairs(synergies) do
            local cls_color = COLORS[syn.class] or COLORS.text
            nvgFillColor(vg, nvgRGBAf(cls_color[1], cls_color[2], cls_color[3], 0.9))
            local syn_text = syn.class:sub(1, 1):upper() .. syn.class:sub(2) .. "(" .. syn.count .. ")"
            nvgText(vg, sx, H - 5, syn_text)
            sx = sx + 60
        end
    end
end
