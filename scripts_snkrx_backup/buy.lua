-- buy.lua (UrhoX port)
-- Shop system between rounds: buy/sell/reroll units

require("snkrx.engine")
require("snkrx.units")
require("snkrx.ui")

-- ============================================================================
-- Shop State
-- ============================================================================
shop_slots = {}        -- array of {unit_key, cost, sold}
shop_selected = 1      -- currently selected index
shop_row = 0           -- 0=shop cards, 1=party, 2=buttons
shop_party_sel = 1     -- selected party member (when row=1)
shop_btn_sel = 1       -- selected button (when row=2): 1=Reroll, 2=GO!

local REROLL_COST = 2
local MAX_PARTY_SIZE = 7
local SHOP_CARD_COUNT = 4

-- ============================================================================
-- Shop Init / Reroll
-- ============================================================================
function init_shop()
    shop_slots = {}
    local available = get_available_units(round)
    if #available == 0 then
        available = {"warrior", "mage", "ranger"}
    end
    for i = 1, SHOP_CARD_COUNT do
        local key = available[math.random(#available)]
        local data = UNIT_DATA[key]
        table.insert(shop_slots, {
            unit_key = key,
            cost = data.cost,
            sold = false,
        })
    end
    shop_selected = 1
    shop_row = 0
    shop_party_sel = 1
    shop_btn_sel = 1
end

function reroll_shop()
    if gold >= REROLL_COST then
        gold = gold - REROLL_COST
        local available = get_available_units(round)
        if #available == 0 then
            available = {"warrior", "mage", "ranger"}
        end
        shop_slots = {}
        for i = 1, SHOP_CARD_COUNT do
            local key = available[math.random(#available)]
            local data = UNIT_DATA[key]
            table.insert(shop_slots, {
                unit_key = key,
                cost = data.cost,
                sold = false,
            })
        end
        shop_selected = 1
        spawn_floating_text(W / 2, H / 2 - 20, "-" .. REROLL_COST .. " Gold", COLORS.gold)
    end
end

function buy_unit(slot_index)
    local slot = shop_slots[slot_index]
    if not slot or slot.sold then return false end
    if gold < slot.cost then
        spawn_floating_text(W / 2, H / 2, "Not enough gold!", {1, 0.3, 0.3})
        return false
    end
    if #snake_units >= MAX_PARTY_SIZE then
        spawn_floating_text(W / 2, H / 2, "Party full!", {1, 0.3, 0.3})
        return false
    end
    gold = gold - slot.cost
    table.insert(snake_units, slot.unit_key)
    slot.sold = true
    spawn_floating_text(W / 2, H / 2 - 20, "-" .. slot.cost .. " Gold", COLORS.gold)
    return true
end

function sell_unit(party_index)
    if party_index < 1 or party_index > #snake_units then return false end
    if #snake_units <= 1 then
        spawn_floating_text(W / 2, H / 2, "Need at least 1 unit!", {1, 0.3, 0.3})
        return false
    end
    local key = snake_units[party_index]
    local data = UNIT_DATA[key]
    local refund = math.max(1, math.floor(data.cost / 2))
    gold = gold + refund
    table.remove(snake_units, party_index)
    spawn_floating_text(W / 2, H / 2 - 20, "+" .. refund .. " Gold", COLORS.gold)
    if shop_party_sel > #snake_units then
        shop_party_sel = math.max(1, #snake_units)
    end
    return true
end

-- ============================================================================
-- Shop Update (Keyboard Navigation)
-- ============================================================================
function update_shop(dt)
    update_floating_texts(dt)

    -- Row navigation (up/down)
    if input:GetKeyPress(KEY_UP) or input:GetKeyPress(KEY_W) then
        shop_row = math.max(0, shop_row - 1)
    end
    if input:GetKeyPress(KEY_DOWN) or input:GetKeyPress(KEY_S) then
        shop_row = math.min(2, shop_row + 1)
    end

    -- Left/Right navigation
    if input:GetKeyPress(KEY_LEFT) or input:GetKeyPress(KEY_A) then
        if shop_row == 0 then
            shop_selected = math.max(1, shop_selected - 1)
        elseif shop_row == 1 then
            shop_party_sel = math.max(1, shop_party_sel - 1)
        elseif shop_row == 2 then
            shop_btn_sel = math.max(1, shop_btn_sel - 1)
        end
    end
    if input:GetKeyPress(KEY_RIGHT) or input:GetKeyPress(KEY_D) then
        if shop_row == 0 then
            shop_selected = math.min(#shop_slots, shop_selected)
            if shop_selected < #shop_slots then
                shop_selected = shop_selected + 1
            end
        elseif shop_row == 1 then
            shop_party_sel = math.min(#snake_units, shop_party_sel + 1)
        elseif shop_row == 2 then
            shop_btn_sel = math.min(2, shop_btn_sel + 1)
        end
    end

    -- Confirm action (Space/Enter)
    if input:GetKeyPress(KEY_SPACE) or input:GetKeyPress(KEY_RETURN) then
        if shop_row == 0 then
            buy_unit(shop_selected)
        elseif shop_row == 1 then
            sell_unit(shop_party_sel)
        elseif shop_row == 2 then
            if shop_btn_sel == 1 then
                reroll_shop()
            elseif shop_btn_sel == 2 then
                start_next_round()
            end
        end
    end

    -- Quick keys
    if input:GetKeyPress(KEY_R) then
        reroll_shop()
    end
    if input:GetKeyPress(KEY_G) then
        start_next_round()
    end
end

-- ============================================================================
-- Shop Drawing
-- ============================================================================
function draw_shop(vg)
    -- Dark background
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, W, H)
    nvgFillColor(vg, nvgRGBAf(0.06, 0.06, 0.1, 1))
    nvgFill(vg)

    -- Title
    nvgFontFace(vg, "game")
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBAf(1, 1, 1, 1))
    nvgText(vg, W / 2, 16, "SHOP - Round " .. round)

    -- Gold display
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBAf(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1))
    nvgText(vg, W - 10, 16, "Gold: " .. gold)

    -- HP display
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBAf(COLORS.hp_bar[1], COLORS.hp_bar[2], COLORS.hp_bar[3], 1))
    nvgText(vg, 10, 16, "HP: " .. math.floor(hp) .. "/" .. max_hp)

    -- ====== Shop Cards Row ======
    local card_w = 90
    local card_h = 100
    local card_gap = 10
    local total_cards_w = SHOP_CARD_COUNT * card_w + (SHOP_CARD_COUNT - 1) * card_gap
    local cards_x = (W - total_cards_w) / 2
    local cards_y = 32

    nvgFontSize(vg, 8)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBAf(0.6, 0.6, 0.7, 0.8))
    nvgText(vg, W / 2, cards_y - 4, "[Up/Down] Row  [Left/Right] Select  [Space] Buy/Sell  [R] Reroll  [G] Go!")

    for i, slot in ipairs(shop_slots) do
        local x = cards_x + (i - 1) * (card_w + card_gap)
        local y = cards_y
        local data = UNIT_DATA[slot.unit_key]
        local selected = (shop_row == 0 and shop_selected == i)

        if slot.sold then
            -- Sold card
            nvgBeginPath(vg)
            nvgRoundedRect(vg, x, y, card_w, card_h, 4)
            nvgFillColor(vg, nvgRGBAf(0.1, 0.1, 0.15, 0.5))
            nvgFill(vg)
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBAf(0.4, 0.4, 0.4, 0.6))
            nvgText(vg, x + card_w / 2, y + card_h / 2, "SOLD")
        else
            -- Card background
            nvgBeginPath(vg)
            nvgRoundedRect(vg, x, y, card_w, card_h, 4)
            if selected then
                nvgFillColor(vg, nvgRGBAf(0.15, 0.18, 0.28, 1))
            else
                nvgFillColor(vg, nvgRGBAf(0.1, 0.12, 0.2, 0.9))
            end
            nvgFill(vg)

            -- Selection border
            nvgBeginPath(vg)
            nvgRoundedRect(vg, x, y, card_w, card_h, 4)
            if selected then
                nvgStrokeColor(vg, nvgRGBAf(1, 1, 0.5, 0.9))
                nvgStrokeWidth(vg, 2)
            else
                nvgStrokeColor(vg, nvgRGBAf(0.3, 0.35, 0.5, 0.5))
                nvgStrokeWidth(vg, 1)
            end
            nvgStroke(vg)

            -- Unit circle
            local cx = x + card_w / 2
            local cy = y + 25
            draw_circle_outline(vg, cx, cy, data.radius + 4, data.color, 2)

            -- Class letter
            nvgFontFace(vg, "game")
            nvgFontSize(vg, 10)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBAf(1, 1, 1, 0.9))
            nvgText(vg, cx, cy, data.name:sub(1, 1))

            -- Unit name
            nvgFontSize(vg, 9)
            nvgFillColor(vg, nvgRGBAf(data.color[1], data.color[2], data.color[3], 1))
            nvgText(vg, cx, y + 45, data.name)

            -- Class
            nvgFontSize(vg, 7)
            nvgFillColor(vg, nvgRGBAf(0.6, 0.6, 0.7, 0.8))
            nvgText(vg, cx, y + 56, data.class)

            -- Stats
            nvgFontSize(vg, 7)
            nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
            nvgFillColor(vg, nvgRGBAf(0.7, 0.7, 0.8, 0.8))
            nvgText(vg, x + 5, y + 64, "DMG: " .. data.damage)
            nvgText(vg, x + 5, y + 73, "HP: " .. data.hp)
            nvgText(vg, x + card_w / 2, y + 64, "SPD: " .. string.format("%.1f", data.attack_speed))
            nvgText(vg, x + card_w / 2, y + 73, "RNG: " .. data.range)

            -- Cost
            nvgFontSize(vg, 9)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            local can_afford = gold >= slot.cost
            if can_afford then
                nvgFillColor(vg, nvgRGBAf(COLORS.gold[1], COLORS.gold[2], COLORS.gold[3], 1))
            else
                nvgFillColor(vg, nvgRGBAf(0.5, 0.3, 0.3, 0.8))
            end
            nvgText(vg, cx, y + card_h - 8, slot.cost .. " Gold")
        end
    end

    -- ====== Party Row ======
    local party_y = cards_y + card_h + 14
    nvgFontFace(vg, "game")
    nvgFontSize(vg, 9)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBAf(0.7, 0.7, 0.8, 0.9))
    nvgText(vg, 15, party_y, "Party (" .. #snake_units .. "/" .. MAX_PARTY_SIZE .. "):")

    local party_start_x = 85
    local party_gap = 28
    for i, unit_key in ipairs(snake_units) do
        local data = UNIT_DATA[unit_key]
        if data then
            local px = party_start_x + (i - 1) * party_gap
            local py = party_y
            local is_selected = (shop_row == 1 and shop_party_sel == i)

            -- Selection highlight
            if is_selected then
                nvgBeginPath(vg)
                nvgCircle(vg, px, py, data.radius + 5)
                nvgStrokeColor(vg, nvgRGBAf(1, 0.4, 0.4, 0.9))
                nvgStrokeWidth(vg, 1.5)
                nvgStroke(vg)
            end

            draw_circle_outline(vg, px, py, data.radius + 2, data.color, 1.5)

            nvgFontFace(vg, "game")
            nvgFontSize(vg, 7)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBAf(1, 1, 1, 0.9))
            nvgText(vg, px, py, data.name:sub(1, 1))

            -- Name below
            nvgFontSize(vg, 6)
            nvgFillColor(vg, nvgRGBAf(0.6, 0.6, 0.7, 0.7))
            nvgText(vg, px, py + data.radius + 7, data.name:sub(1, 3))
        end
    end

    -- Sell hint when party row selected
    if shop_row == 1 then
        nvgFontSize(vg, 7)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBAf(1, 0.4, 0.4, 0.8))
        nvgText(vg, W - 15, party_y, "[Space] Sell")
    end

    -- ====== Synergies ======
    local syn_y = party_y + 22
    local synergies = get_active_synergies(snake_units)
    if #synergies > 0 then
        nvgFontSize(vg, 7)
        nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        local sx = 15
        for _, syn in ipairs(synergies) do
            local cls_color = COLORS[syn.class] or COLORS.text
            nvgFillColor(vg, nvgRGBAf(cls_color[1], cls_color[2], cls_color[3], 0.9))
            local syn_text = syn.class:sub(1, 1):upper() .. syn.class:sub(2)
                .. " x" .. syn.count .. " - " .. syn.bonus.description
            nvgText(vg, sx, syn_y, syn_text)
            sx = sx + 160
        end
    end

    -- ====== Bottom Buttons ======
    local btn_y = H - 28
    local btn_w = 80
    local btn_h = 18
    local btn_gap = 20
    local btns_total_w = btn_w * 2 + btn_gap
    local btns_x = (W - btns_total_w) / 2

    -- Reroll button
    local reroll_selected = (shop_row == 2 and shop_btn_sel == 1)
    local reroll_color = gold >= REROLL_COST and {0.2, 0.3, 0.5} or {0.3, 0.2, 0.2}
    draw_button(vg, btns_x, btn_y, btn_w, btn_h,
        "Reroll (" .. REROLL_COST .. "g)", reroll_selected, reroll_color)

    -- GO! button
    local go_selected = (shop_row == 2 and shop_btn_sel == 2)
    draw_button(vg, btns_x + btn_w + btn_gap, btn_y, btn_w, btn_h,
        "GO!", go_selected, {0.2, 0.5, 0.3})
end
