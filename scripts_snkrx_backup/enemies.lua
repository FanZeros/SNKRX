-- enemies.lua (UrhoX port)
-- Enemy types, spawning, AI, and damage

require("snkrx.engine")
require("snkrx.units")

enemies = {}
enemy_projectiles = {}

ENEMY_TYPES = {
    basic = {
        name = "Basic",
        hp = 30,
        speed = 30,
        damage = 5,
        radius = 5,
        color = COLORS.enemy,
        score = 10,
    },
    fast = {
        name = "Fast",
        hp = 20,
        speed = 55,
        damage = 3,
        radius = 4,
        color = {1.0, 0.4, 0.3},
        score = 15,
    },
    tank = {
        name = "Tank",
        hp = 80,
        speed = 18,
        damage = 10,
        radius = 8,
        color = {0.6, 0.2, 0.2},
        score = 20,
    },
    shooter = {
        name = "Shooter",
        hp = 25,
        speed = 22,
        damage = 8,
        radius = 5,
        color = {0.9, 0.5, 0.1},
        score = 25,
        shoots = true,
        shoot_cooldown = 2.5,
    },
    boss = {
        name = "Boss",
        hp = 300,
        speed = 15,
        damage = 20,
        radius = 12,
        color = {0.8, 0.1, 0.3},
        score = 100,
    },
}

function spawn_enemy()
    local types = {"basic"}
    if round >= 2 then table.insert(types, "fast") end
    if round >= 3 then table.insert(types, "tank") end
    if round >= 4 then table.insert(types, "shooter") end

    local type_key = types[math.random(#types)]
    local etype = ENEMY_TYPES[type_key]

    -- Boss every 5 rounds
    if round % 5 == 0 and enemies_spawned == enemies_to_spawn - 1 then
        type_key = "boss"
        etype = ENEMY_TYPES["boss"]
    end

    -- Spawn at random edge
    local x, y
    local side = math.random(4)
    if side == 1 then
        x = random_float(ARENA_X, ARENA_X + ARENA_W)
        y = ARENA_Y
    elseif side == 2 then
        x = random_float(ARENA_X, ARENA_X + ARENA_W)
        y = ARENA_Y + ARENA_H
    elseif side == 3 then
        x = ARENA_X
        y = random_float(ARENA_Y, ARENA_Y + ARENA_H)
    else
        x = ARENA_X + ARENA_W
        y = random_float(ARENA_Y, ARENA_Y + ARENA_H)
    end

    local hp_scale = 1 + (round - 1) * 0.15

    table.insert(enemies, {
        x = x,
        y = y,
        type = type_key,
        hp = etype.hp * hp_scale,
        max_hp = etype.hp * hp_scale,
        speed = etype.speed,
        damage = etype.damage,
        radius = etype.radius,
        color = etype.color,
        score = etype.score,
        shoots = etype.shoots,
        shoot_cooldown = etype.shoot_cooldown or 0,
        shoot_timer = 0,
        flash = FlashEffect.new(0.1),
    })
end

function update_enemies(dt)
    -- Update enemy projectiles
    for i = #enemy_projectiles, 1, -1 do
        local p = enemy_projectiles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt

        -- Check collision with snake units
        for j, unit_key in ipairs(snake_units) do
            local pos = get_unit_position(j)
            local data = UNIT_DATA[unit_key]
            if pos and data and circles_collide(p.x, p.y, 3, pos.x, pos.y, data.radius) then
                hp = hp - p.damage
                particles:emit(pos.x, pos.y, 5, {1, 0.3, 0.3}, 40, 0.3)
                p.life = 0
                break
            end
        end

        if p.life <= 0 or p.x < 0 or p.x > W or p.y < 0 or p.y > H then
            table.remove(enemy_projectiles, i)
        end
    end

    for i = #enemies, 1, -1 do
        local enemy = enemies[i]

        enemy.flash:update(dt)

        -- Move toward snake head
        local target_pos = get_unit_position(1)
        if target_pos then
            local a = angle_to(enemy.x, enemy.y, target_pos.x, target_pos.y)
            enemy.x = enemy.x + math.cos(a) * enemy.speed * dt
            enemy.y = enemy.y + math.sin(a) * enemy.speed * dt
        end

        -- Keep in arena
        enemy.x = clamp(enemy.x, ARENA_X, ARENA_X + ARENA_W)
        enemy.y = clamp(enemy.y, ARENA_Y, ARENA_Y + ARENA_H)

        -- Shooting enemies
        if enemy.shoots then
            enemy.shoot_timer = enemy.shoot_timer + dt
            if enemy.shoot_timer >= enemy.shoot_cooldown then
                enemy.shoot_timer = 0
                if target_pos then
                    local a = angle_to(enemy.x, enemy.y, target_pos.x, target_pos.y)
                    table.insert(enemy_projectiles, {
                        x = enemy.x,
                        y = enemy.y,
                        vx = math.cos(a) * 80,
                        vy = math.sin(a) * 80,
                        damage = enemy.damage,
                        life = 3.0,
                    })
                end
            end
        end

        -- Contact damage to snake
        for j, unit_key in ipairs(snake_units) do
            local pos = get_unit_position(j)
            local data = UNIT_DATA[unit_key]
            if pos and data and circles_collide(enemy.x, enemy.y, enemy.radius, pos.x, pos.y, data.radius) then
                hp = hp - enemy.damage * dt
                particles:emit(pos.x, pos.y, 1, {1, 0.3, 0.3}, 20, 0.2)
            end
        end

        -- Remove dead enemies
        if enemy.hp <= 0 then
            score = score + enemy.score
            gold = gold + math.floor(enemy.score / 10)
            particles:emit(enemy.x, enemy.y, 10, enemy.color, 60, 0.4)
            table.remove(enemies, i)
        end
    end
end

function draw_enemies(vg)
    nvgSave(vg)
    nvgTranslate(vg, ScreenShake.x, ScreenShake.y)

    for _, enemy in ipairs(enemies) do
        draw_circle_outline(vg, enemy.x, enemy.y, enemy.radius, enemy.color)

        if enemy.flash.active then
            nvgBeginPath(vg)
            nvgCircle(vg, enemy.x, enemy.y, enemy.radius + 1)
            nvgFillColor(vg, nvgRGBAf(1, 1, 1, enemy.flash:get_alpha()))
            nvgFill(vg)
        end

        if enemy.max_hp > 40 then
            draw_hp_bar(vg, enemy.x - 8, enemy.y - enemy.radius - 4, 16, 2, enemy.hp, enemy.max_hp)
        end
    end

    -- Enemy projectiles
    for _, p in ipairs(enemy_projectiles) do
        nvgBeginPath(vg)
        nvgCircle(vg, p.x, p.y, 2)
        nvgFillColor(vg, nvgRGBAf(1, 0.5, 0.2, 1))
        nvgFill(vg)
    end

    nvgRestore(vg)
end

function find_nearest_enemy(x, y)
    local nearest = nil
    local nearest_dist = math.huge
    for _, enemy in ipairs(enemies) do
        local d = distance(x, y, enemy.x, enemy.y)
        if d < nearest_dist then
            nearest = enemy
            nearest_dist = d
        end
    end
    return nearest, nearest_dist
end

function deal_damage_to_enemy(enemy, damage)
    enemy.hp = enemy.hp - damage
    enemy.flash:trigger()
end
