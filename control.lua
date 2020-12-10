require('__core__/lualib/util')
local Position = require('__stdlib__/stdlib/area/position')

local event_filter = {{filter = 'name', name = 'blackhole'}}

script.on_init(function()
    global.blackhole = nil -- Needs on_config_changed to clean up and migrate existing
    global.blackholes = {}
    if remote.interfaces['freeplay'] and remote.interfaces['freeplay'].set_disable_crashsite then
        remote.call('freeplay', 'set_disable_crashsite', true)
    end
end)

script.on_event(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)
    local force = player.force
    if #force.players > 1 then return end

    local intro_machine = 'crash-site-assembling-machine-1-repaired'
    local surface = player.surface
    local position = Position(player.position)
    for _ = 1, 2 do
        local from_player = position:random(5, 15)
        local pos = surface.find_non_colliding_position(intro_machine, from_player, 10, 1, true)
        if pos then surface.create_entity{name = intro_machine, position = pos, force = force} end
    end
end)

local function create_furnace(entity)
    local furnace = entity.surface.create_entity{
        name = 'magic-furnace',
        position = entity.position,
        force = entity.force
    }
    return furnace, furnace.get_output_inventory()
end

local function on_built(event)
    local entity = event.created_entity or event.entity
    local furnace, output = create_furnace(entity)
    local blackhole = {generator = entity, fuel = entity.get_fuel_inventory(), furnace = furnace, output = output}
    global.blackholes[entity.unit_nummber] = blackhole
end
script.on_event(defines.events.on_built_entity, on_built, event_filter)
script.on_event(defines.events.on_robot_built_entity, on_built, event_filter)
script.on_event(defines.events.script_raised_built, event_filter)
script.on_event(defines.events.script_raised_revive, event_filter)

local function destroy_furnace(data, unit_number)
    if data and data.furnace and data.furnace.valid then data.furnace.destroy() end
    global.blackholes[unit_number] = nil
end

local function on_entity_mined(event)
    local unit_number = event.entity.unit_number
    local data = global.blackholes[unit_number]
    destroy_furnace(data, unit_number)
end
script.on_event(defines.events.on_robot_mined_entity, on_entity_mined, event_filter)
script.on_event(defines.events.on_player_mined_entity, on_entity_mined, event_filter)
script.on_event(defines.events.script_raised_destroy, on_entity_mined, event_filter)

script.on_nth_tick(30, function()

    for unit_number, data in pairs(global.blackholes) do
        if data.generator.valid then
            if not data.output.valid then data.furnace, data.output = create_furnace(data.generator) end

            if data.fuel.get_item_count() <= 5 then
                local count = data.output.get_item_count()
                if count >= 1 then
                    data.fuel.insert({name = 'blackhole-fuel', count = count})
                    data.output.clear()
                end
            end
        else
            destroy_furnace(data, unit_number)
        end
    end
end)
