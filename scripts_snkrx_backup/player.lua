-- player.lua (UrhoX port)
-- Snake player movement, attack logic, and unit rendering

require("snkrx.engine")
require("snkrx.units")

-- Snake state
snake = {}
snake_speed = 80
snake_turn_speed = 3.5
snake_angle = 0
snake_positions = {}
snake_segment_spacing = 12

-- Attack state per unit
unit_states = {}

-- Projectiles
projectiles = {}

function init_player()
    snake = {
        x = W / 2,
        y = H / 2,
    }
    snake_angle = 0
    snake_positions = {}
    unit_states = {}
    projectiles = {}

    -- Pre-fill position trail
    for i = 1, #snake_units * snake_segment_spacing + 10 do
        table.insert(snake_positions, {x = snake.x, y = snake.y})
    end

    -- Init unit states
    for i, unit_key in ipairs(snake_units) do
        local data = UNIT_DATA[unit_key]
        unit_states[i] = {
            attack_timer = 0,
            ability_timer = data.ability_cooldown * 0.5,
            flash = FlashEffect.new(0.15),
        }
    end
end

function update_player(dt)
    -- Steering (UrhoX input polling)
    if input:GetKeyDown(KEY_LEFT) or input:GetKeyDown(KEY_A) then
        snake_angle = snake_angle - snake_turn_speed * dt
    end
    if input:GetKeyDown(KEY_RIGHT) or input:GetKeyDown(KEY_D) then
        snake_angle = snake_angle + snake_turn_speed * dt
    end

    -- Move head
    snake.x = snake.x + math.cos(snake_angle) * snake_speed * dt
    snake.y = snake.y + math.sin(snake_angle) * snake_speed * dt

    -- Wrap around arena
    if snake.x < ARENA_X then snake.x = ARENA_X + ARENA_W end
    if snake.x > ARENA_X + ARENA_W then snake.x = ARENA_X end
    if snake.y < ARENA_Y then snake.y = ARENA_Y + ARENA_H end
    if snake.y > ARENA_Y + ARENA_H then snake.y = ARENA_Y end

    -- Record position trail
    table.insert(snake_positions, 1, {x = snake.x, y = snake.y})
    local max_trail = #snake_units * snake_segment_spacing + 20
    while #snake_positions > max_trail do
        table.remove(snake_positions, #snake_positions)
    end

    update_unit_attacks(dt)
    update_projectiles(dt)
    ScreenShake.update(dt)
    particles:update(dt)
end

function get_unit_position(index)
    local trail_index = (index - 1) * snake_segment_spacing + 1
    if trail_index > #snake_positions then
        trail_index = #snake_positions
    end
    return snake_positions[trail_index]
end

function update_unit_attacks(dt)
    if not enemies then return end

    local synergies = get_active_synergies(snake_units)
    local attack_speed_mult = 1.0
    local damage_mult = 1.0

    for _, syn in ipairs(synergies) do
        if syn.bonus.bonus == "attack_speed" then
            attack_speed_mult = syn.bonus.value
        elseif syn.bonus.bonus == "spell_power" then
            damage_mult = damage_mult + syn.bonus.value / 100
        elseif syn.bonus.bonus == "buff" then
            damage_mult = damage_mult + syn.bonus.value / 100
            attack_speed_mult = attack_speed_mult * (1 - syn.bonus.value / 200)
        end
    end

    for i, unit_key in ipairs(snake_units) do
        local data = UNIT_DATA[unit_key]
        local state = unit_states[i]
        if not data or not state then goto continue end

        local pos = get_unit_position(i)
        state.flash:update(dt)
        state.attack_timer = state.attack_timer + dt
        local actual_attack_speed = data.attack_speed * attack_speed_mult

        if state.attack_timer >= actual_attack_speed then
            local nearest, nearest_dist = find_nearest_enemy(pos.x, pos.y)
            if nearest and nearest_dist <= data.range then
                state.attack_timer = 0
                state.flash:trigger()

                if data.range <= 35 then
                    local dmg = data.damage * damage_mult
                    deal_damage_to_enemy(nearest, dmg)
                    particles:emit(nearest.x, nearest.y, 3, data.color, 40, 0.3)
                else
                    local a = angle_to(pos.x, pos.y, nearest.x, nearest.y)
                    spawn_projectile(pos.x, pos.y, a, data.damage * damage_mult, data.color)
                end
            end
        end

        state.ability_timer = state.ability_timer + dt
        if state.ability_timer >= data.ability_cooldown then
            state.ability_timer = 0
            use_ability(i, unit_key, data, pos)
        end

        ::continue::
    end
end

function use_ability(index, unit_key, data, pos)
    if data.ability == "fireball" then
        local nearest = find_nearest_enemy(pos.x, pos.y)
        if nearest then
            local a = angle_to(pos.x, pos.y, nearest.x, nearest.y)
            spawn_projectile(pos.x, pos.y, a, data.damage * 2, {1.0, 0.5, 0.1}, 3, true)
            particles:emit(pos.x, pos.y, 8, {1.0, 0.5, 0.1}, 60, 0.4)
        end

    elseif data.ability == "multishot" then
        local nearest = find_nearest_enemy(pos.x, pos.y)
        if nearest then
            local base_angle = angle_to(pos.x, pos.y, nearest.x, nearest.y)
            for a = -0.3, 0.3, 0.15 do
                spawn_projectile(pos.x, pos.y, base_angle + a, data.damage * 0.8, data.color, 2)
            end
        end

    elseif data.ability == "heal" then
        hp = math.min(max_hp, hp + 10)
        particles:emit(pos.x, pos.y, 10, COLORS.healer, 30, 0.5)

    elseif data.ability == "slash" or data.ability == "shield_bash" then
        for _, enemy in ipairs(enemies) do
            if distance(pos.x, pos.y, enemy.x, enemy.y) < 40 then
                deal_damage_to_enemy(enemy, data.damage * 1.5)
            end
        end
        particles:emit(pos.x, pos.y, 12, data.color, 50, 0.3)
        ScreenShake.trigger(2, 0.15)

    elseif data.ability == "backstab" or data.ability == "execute" then
        local nearest, dist = find_nearest_enemy(pos.x, pos.y)
        if nearest and dist < 50 then
            deal_damage_to_enemy(nearest, data.damage * 3.0)
            particles:emit(nearest.x, nearest.y, 15, data.color, 70, 0.4)
            ScreenShake.trigger(3, 0.2)
        end

    elseif data.ability == "empower" then
        for _, s in ipairs(unit_states) do
            s.ability_timer = s.ability_timer + 1.0
        end
        particles:emit(pos.x, pos.y, 8, COLORS.enchanter, 40, 0.5)

    elseif data.ability == "meteor" then
        local nearest = find_nearest_enemy(pos.x, pos.y)
        if nearest then
            for _, enemy in ipairs(enemies) do
                if distance(nearest.x, nearest.y, enemy.x, enemy.y) < 35 then
                    deal_damage_to_enemy(enemy, data.damage * 2.5)
                end
            end
            particles:emit(nearest.x, nearest.y, 20, {1.0, 0.4, 0.1}, 80, 0.5)
            ScreenShake.trigger(4, 0.25)
        end

    elseif data.ability == "piercing_shot" then
        local nearest = find_nearest_enemy(pos.x, pos.y)
        if nearest then
            local a = angle_to(pos.x, pos.y, nearest.x, nearest.y)
            spawn_projectile(pos.x, pos.y, a, data.damage * 3, {0.4, 1.0, 0.4}, 4, false, true)
        end
    end
end

function spawn_projectile(x, y, angle, damage, color, size, explosive, piercing)
    table.insert(projectiles, {
        x = x,
        y = y,
        vx = math.cos(angle) * 150,
        vy = math.sin(angle) * 150,
        damage = damage,
        color = color or COLORS.projectile,
        size = size or 2,
        life = 2.0,
        explosive = explosive or false,
        piercing = piercing or false,
        hit_enemies = {},
    })
end

function update_projectiles(dt)
    for i = #projectiles, 1, -1 do
        local p = projectiles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt

        local hit = false
        for _, enemy in ipairs(enemies) do
            if not p.hit_enemies[enemy] and circles_collide(p.x, p.y, p.size, enemy.x, enemy.y, enemy.radius) then
                deal_damage_to_enemy(enemy, p.damage)
                particles:emit(enemy.x, enemy.y, 4, p.color, 40, 0.2)

                if p.explosive then
                    for _, e2 in ipairs(enemies) do
                        if e2 ~= enemy and distance(enemy.x, enemy.y, e2.x, e2.y) < 30 then
                            deal_damage_to_enemy(e2, p.damage * 0.5)
                        end
                    end
                    particles:emit(enemy.x, enemy.y, 15, {1.0, 0.5, 0.1}, 60, 0.4)
                    ScreenShake.trigger(2, 0.1)
                end

                if p.piercing then
                    p.hit_enemies[enemy] = true
                else
                    hit = true
                end
            end
        end

        if hit or p.life <= 0 or p.x < 0 or p.x > W or p.y < 0 or p.y > H then
            table.remove(projectiles, i)
        end
    end
end

function draw_player(vg)
    nvgSave(vg)
    nvgTranslate(vg, ScreenShake.x, ScreenShake.y)

    -- Connecting lines
    nvgStrokeColor(vg, nvgRGBAf(0.3, 0.3, 0.4, 0.6))
    nvgStrokeWidth(vg, 3)
    for i = 1, #snake_units - 1 do
        local p1 = get_unit_position(i)
        local p2 = get_unit_position(i + 1)
        nvgBeginPath(vg)
        nvgMoveTo(vg, p1.x, p1.y)
        nvgLineTo(vg, p2.x, p2.y)
        nvgStroke(vg)
    end

    -- Draw units (back to front)
    for i = #snake_units, 1, -1 do
        local pos = get_unit_position(i)
        local unit_key = snake_units[i]
        local data = UNIT_DATA[unit_key]
        local state = unit_states[i]

        if data and pos then
            draw_circle_outline(vg, pos.x, pos.y, data.radius, data.color)

            if state and state.flash.active then
                nvgBeginPath(vg)
                nvgCircle(vg, pos.x, pos.y, data.radius + 2)
                nvgFillColor(vg, nvgRGBAf(1, 1, 1, state.flash:get_alpha()))
                nvgFill(vg)
            end

            -- Class letter
            nvgFontFace(vg, "game")
            nvgFontSize(vg, 8)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBAf(1, 1, 1, 0.9))
            nvgText(vg, pos.x, pos.y, data.name:sub(1, 1))
        end
    end

    -- Head direction indicator
    local hx = snake.x + math.cos(snake_angle) * 10
    local hy = snake.y + math.sin(snake_angle) * 10
    nvgBeginPath(vg)
    nvgCircle(vg, hx, hy, 2)
    nvgFillColor(vg, nvgRGBAf(1, 1, 1, 0.7))
    nvgFill(vg)

    -- Projectiles
    for _, p in ipairs(projectiles) do
        nvgBeginPath(vg)
        nvgCircle(vg, p.x, p.y, p.size)
        nvgFillColor(vg, nvgRGBAf(p.color[1], p.color[2], p.color[3], 1))
        nvgFill(vg)
    end

    -- Particles
    particles:draw(vg)

    nvgRestore(vg)
end
