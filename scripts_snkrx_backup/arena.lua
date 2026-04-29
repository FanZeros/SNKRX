-- arena.lua (UrhoX port)
-- Arena rendering and boundary effects

require("snkrx.engine")

arena_border_pulse = 0

function init_arena()
    arena_border_pulse = 0
end

function update_arena(dt)
    arena_border_pulse = arena_border_pulse + dt * 2
end

function draw_arena(vg)
    -- Background
    nvgBeginPath(vg)
    nvgRect(vg, ARENA_X, ARENA_Y, ARENA_W, ARENA_H)
    nvgFillColor(vg, nvgRGBAf(0.08, 0.08, 0.12, 1))
    nvgFill(vg)

    -- Grid lines
    nvgStrokeColor(vg, nvgRGBAf(0.12, 0.12, 0.18, 0.5))
    nvgStrokeWidth(vg, 1)
    local grid_size = 20
    for x = ARENA_X, ARENA_X + ARENA_W, grid_size do
        nvgBeginPath(vg)
        nvgMoveTo(vg, x, ARENA_Y)
        nvgLineTo(vg, x, ARENA_Y + ARENA_H)
        nvgStroke(vg)
    end
    for y = ARENA_Y, ARENA_Y + ARENA_H, grid_size do
        nvgBeginPath(vg)
        nvgMoveTo(vg, ARENA_X, y)
        nvgLineTo(vg, ARENA_X + ARENA_W, y)
        nvgStroke(vg)
    end

    -- Border
    local pulse = 0.3 + math.sin(arena_border_pulse) * 0.1
    nvgBeginPath(vg)
    nvgRect(vg, ARENA_X, ARENA_Y, ARENA_W, ARENA_H)
    nvgStrokeColor(vg, nvgRGBAf(0.3, 0.4, 0.6, pulse))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- Corner decorations
    local cs = 6
    nvgStrokeColor(vg, nvgRGBAf(0.4, 0.5, 0.7, 0.6))
    nvgStrokeWidth(vg, 1.5)

    -- Top-left
    nvgBeginPath(vg)
    nvgMoveTo(vg, ARENA_X, ARENA_Y + cs)
    nvgLineTo(vg, ARENA_X, ARENA_Y)
    nvgLineTo(vg, ARENA_X + cs, ARENA_Y)
    nvgStroke(vg)

    -- Top-right
    nvgBeginPath(vg)
    nvgMoveTo(vg, ARENA_X + ARENA_W - cs, ARENA_Y)
    nvgLineTo(vg, ARENA_X + ARENA_W, ARENA_Y)
    nvgLineTo(vg, ARENA_X + ARENA_W, ARENA_Y + cs)
    nvgStroke(vg)

    -- Bottom-left
    nvgBeginPath(vg)
    nvgMoveTo(vg, ARENA_X, ARENA_Y + ARENA_H - cs)
    nvgLineTo(vg, ARENA_X, ARENA_Y + ARENA_H)
    nvgLineTo(vg, ARENA_X + cs, ARENA_Y + ARENA_H)
    nvgStroke(vg)

    -- Bottom-right
    nvgBeginPath(vg)
    nvgMoveTo(vg, ARENA_X + ARENA_W - cs, ARENA_Y + ARENA_H)
    nvgLineTo(vg, ARENA_X + ARENA_W, ARENA_Y + ARENA_H)
    nvgLineTo(vg, ARENA_X + ARENA_W, ARENA_Y + ARENA_H - cs)
    nvgStroke(vg)
end
