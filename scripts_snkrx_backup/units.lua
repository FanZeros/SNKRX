-- units.lua (UrhoX port)
-- Unit definitions and class synergy data

require("snkrx.engine")

UNIT_DATA = {
    warrior = {
        name = "Warrior",
        class = "warrior",
        tier = 1,
        cost = 3,
        hp = 100,
        damage = 15,
        attack_speed = 1.0,
        range = 25,
        radius = 6,
        description = "Basic melee fighter",
        color = COLORS.warrior,
        ability = "slash",
        ability_cooldown = 3.0,
    },
    knight = {
        name = "Knight",
        class = "warrior",
        tier = 2,
        cost = 5,
        hp = 180,
        damage = 20,
        attack_speed = 0.8,
        range = 30,
        radius = 7,
        description = "Armored warrior with shield bash",
        color = {0.95, 0.7, 0.3},
        ability = "shield_bash",
        ability_cooldown = 4.0,
    },
    mage = {
        name = "Mage",
        class = "mage",
        tier = 1,
        cost = 3,
        hp = 60,
        damage = 25,
        attack_speed = 1.5,
        range = 80,
        radius = 5,
        description = "Shoots magic projectiles",
        color = COLORS.mage,
        ability = "fireball",
        ability_cooldown = 4.0,
    },
    wizard = {
        name = "Wizard",
        class = "mage",
        tier = 2,
        cost = 6,
        hp = 70,
        damage = 40,
        attack_speed = 1.8,
        range = 100,
        radius = 5,
        description = "Powerful AoE spells",
        color = {0.5, 0.6, 1.0},
        ability = "meteor",
        ability_cooldown = 6.0,
    },
    ranger = {
        name = "Ranger",
        class = "ranger",
        tier = 1,
        cost = 3,
        hp = 70,
        damage = 12,
        attack_speed = 0.5,
        range = 90,
        radius = 5,
        description = "Fast ranged attacker",
        color = COLORS.ranger,
        ability = "multishot",
        ability_cooldown = 3.0,
    },
    sniper = {
        name = "Sniper",
        class = "ranger",
        tier = 2,
        cost = 5,
        hp = 60,
        damage = 35,
        attack_speed = 2.0,
        range = 150,
        radius = 5,
        description = "Long range, high damage",
        color = {0.4, 0.9, 0.4},
        ability = "piercing_shot",
        ability_cooldown = 5.0,
    },
    rogue = {
        name = "Rogue",
        class = "rogue",
        tier = 1,
        cost = 4,
        hp = 55,
        damage = 20,
        attack_speed = 0.6,
        range = 25,
        radius = 5,
        description = "Fast melee with crits",
        color = COLORS.rogue,
        ability = "backstab",
        ability_cooldown = 3.0,
    },
    assassin = {
        name = "Assassin",
        class = "rogue",
        tier = 2,
        cost = 7,
        hp = 50,
        damage = 45,
        attack_speed = 0.5,
        range = 30,
        radius = 5,
        description = "Deadly burst damage",
        color = {0.9, 0.3, 0.6},
        ability = "execute",
        ability_cooldown = 5.0,
    },
    healer = {
        name = "Healer",
        class = "healer",
        tier = 1,
        cost = 4,
        hp = 65,
        damage = 8,
        attack_speed = 1.2,
        range = 60,
        radius = 5,
        description = "Heals nearby allies",
        color = COLORS.healer,
        ability = "heal",
        ability_cooldown = 3.0,
    },
    enchanter = {
        name = "Enchanter",
        class = "enchanter",
        tier = 1,
        cost = 4,
        hp = 60,
        damage = 10,
        attack_speed = 1.0,
        range = 70,
        radius = 5,
        description = "Buffs allies, debuffs enemies",
        color = COLORS.enchanter,
        ability = "empower",
        ability_cooldown = 5.0,
    },
}

CLASS_SYNERGIES = {
    warrior = {
        [2] = {bonus = "armor", value = 20, description = "+20% damage reduction"},
        [3] = {bonus = "armor", value = 40, description = "+40% damage reduction"},
    },
    mage = {
        [2] = {bonus = "spell_power", value = 25, description = "+25% spell damage"},
        [3] = {bonus = "spell_power", value = 50, description = "+50% spell damage"},
    },
    ranger = {
        [2] = {bonus = "attack_speed", value = 0.8, description = "+20% attack speed"},
        [3] = {bonus = "attack_speed", value = 0.6, description = "+40% attack speed"},
    },
    rogue = {
        [2] = {bonus = "crit", value = 30, description = "+30% crit chance"},
        [3] = {bonus = "crit", value = 60, description = "+60% crit chance"},
    },
    healer = {
        [2] = {bonus = "regen", value = 3, description = "Regen 3 HP/s"},
    },
    enchanter = {
        [2] = {bonus = "buff", value = 15, description = "+15% all stats"},
    },
}

function get_available_units(current_round)
    local available = {}
    for key, data in pairs(UNIT_DATA) do
        if data.tier <= 1 + math.floor(current_round / 3) then
            table.insert(available, key)
        end
    end
    return available
end

function get_active_synergies(units_list)
    local class_counts = {}
    for _, unit_key in ipairs(units_list) do
        local data = UNIT_DATA[unit_key]
        if data then
            local cls = data.class
            class_counts[cls] = (class_counts[cls] or 0) + 1
        end
    end

    local active = {}
    for cls, count in pairs(class_counts) do
        local synergy = CLASS_SYNERGIES[cls]
        if synergy then
            local best = nil
            for threshold, bonus_data in pairs(synergy) do
                if count >= threshold then
                    if not best or threshold > best.threshold then
                        best = {threshold = threshold, bonus = bonus_data}
                    end
                end
            end
            if best then
                table.insert(active, {
                    class = cls,
                    count = count,
                    threshold = best.threshold,
                    bonus = best.bonus,
                })
            end
        end
    end

    return active
end
