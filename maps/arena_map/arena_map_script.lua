-- Arena map script with interactive objects

return {
    -- Chest interaction - opens shop
    chest_interact = function(args, api)
        api.openShop()
    end,
    
    -- Door interaction - toggles pass-through
    door_interact = function(args, api)
        local door = api.getObject(args.objectId)
        
        if door and door.state then
            door.state.open = not door.state.open
            
            if door.collision_id then
                api.toggleCollision(door.collision_id, not door.state.open)
            end
        end
    end,
    
    -- Portal interaction - travels to another map
    portal_interact = function(args, api)
        local portal = api.getObject(args.objectId)

        if portal then
            -- Load the target map with remember flag
            api.loadMap(portal.target_map, portal.remember or true, portal.spawn_x, portal.spawn_y)
        end
    end
}
