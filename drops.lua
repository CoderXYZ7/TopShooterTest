-- Drops and Pickups management module
local Drops = {}

function Drops:new()
    local drops = {
        pickups = {}
    }
    setmetatable(drops, { __index = self })
    return drops
end

function Drops:update(dt)
    -- Only handle temporary spawners and pickups, no random spawning
end

function Drops:createDrop(x, y, dropType, amount)
    print(string.format("createDrop called: x=%.1f, y=%.1f, type=%s, amount=%s", x, y, dropType, tostring(amount)))
    print("  Map exists: " .. tostring(self.map ~= nil))
    if self.map then
        print("  Map.data exists: " .. tostring(self.map.data ~= nil))
        if self.map.data then
            print("  Map.data.spawners exists: " .. tostring(self.map.data.spawners ~= nil))
        end
    end
    
    -- Create a temporary item spawner at the drop location
    local tempSpawner = {
        type = "item",
        position = {x, y},
        item = dropType,
        temporary = true,
        lifetime = 20.0,
        age = 0
    }

    -- Add to map's item spawners if map exists
    if self.map and self.map.data and self.map.data.spawners then
        local spawnerId = "drop_" .. love.timer.getTime() .. "_" .. math.random(1000)
        self.map.data.spawners[spawnerId] = tempSpawner
        print("  Added temporary spawner: " .. spawnerId)
    else
        print("  ERROR: Could not add spawner - missing map/data/spawners")
    end
end

function Drops:setMap(map)
    self.map = map
end

function Drops:updateTemporarySpawners(dt, player, particles)
    if not self.map or not self.map.data or not self.map.data.spawners then 
        print("Drop system: No map or spawners")
        return 
    end

    -- Update temporary spawners and spawn items
    for spawnerId, spawner in pairs(self.map.data.spawners) do
        if spawner.temporary and spawner.type == "item" then
            spawner.age = (spawner.age or 0) + dt

            -- Check if player is near the spawner to spawn item
            local dx = spawner.position[1] - (player.x + player.width/2)
            local dy = spawner.position[2] - (player.y + player.height/2)
            local dist = math.sqrt(dx*dx + dy*dy)

            print(string.format("Temporary spawner %s: dist=%.1f, spawned=%s, age=%.1f", 
                spawnerId, dist, tostring(spawner.spawned), spawner.age))

            -- Spawn immediately without distance check (enemy just died there)
            if not spawner.spawned then
                -- Spawn the item
                print("Spawning item from temporary spawner: " .. spawner.item .. " at " .. spawner.position[1] .. ", " .. spawner.position[2])
                self:spawnItemFromSpawner(spawner, spawnerId)
                spawner.spawned = true
            elseif spawner.age >= spawner.lifetime then
                -- Remove expired temporary spawner
                print("Removing expired temporary spawner")
                self.map.data.spawners[spawnerId] = nil
            end
        end
    end
end

function Drops:spawnItemFromSpawner(spawner, spawnerId)
    if not spawner.item then return end

    local itemType = spawner.item

    -- Create item pickup based on type
    local pickup = {
        x = spawner.position[1],
        y = spawner.position[2],
        type = itemType:lower(),
        lifetime = 15.0,  -- Items last 15 seconds
        age = 0,
        size = 20,
        spawnerId = spawnerId  -- Track which spawner created this
    }

    -- Set color based on item type
    if itemType == "MEDKIT" then
        pickup.color = {1, 0.2, 0.2}  -- Red for health
    elseif itemType == "AMMO" then
        pickup.color = {1, 0.8, 0.2}  -- Gold for ammo
    elseif itemType == "WEAPON_UPGRADE" then
        pickup.color = {0.8, 0.2, 1}  -- Purple for upgrades
    else
        pickup.color = {0.5, 0.5, 0.5}  -- Gray for unknown
    end

    table.insert(self.pickups, pickup)
end

function Drops:updatePickups(dt, player, particles)
    for i = #self.pickups, 1, -1 do
        local pickup = self.pickups[i]
        pickup.age = pickup.age + dt

        -- Check collision with player
        local dx = pickup.x - (player.x + player.width/2)
        local dy = pickup.y - (player.y + player.height/2)
        local dist = math.sqrt(dx*dx + dy*dy)

        if dist < pickup.size + player.width/2 then
            -- Player collected pickup
            if pickup.type == "health" or pickup.type == "medkit" or pickup.type == "MEDKIT" then
                player:heal(25)
                particles:createPickupEffect(pickup.x, pickup.y, {1, 0.2, 0.2})
            elseif pickup.type == "ammo" or pickup.type == "AMMO" then
                player:addAmmo(15)
                particles:createPickupEffect(pickup.x, pickup.y, {0.2, 0.2, 1})
            elseif pickup.type == "weapon_upgrade" or pickup.type == "WEAPON_UPGRADE" then
                -- Try to purchase a random upgrade
                local upgradeTypes = {"damage", "health", "speed", "accuracy"}
                local upgradeType = upgradeTypes[math.random(1, #upgradeTypes)]
                local success = player:purchaseUpgrade(upgradeType)
                if success then
                    particles:createPickupEffect(pickup.x, pickup.y, {0.8, 0.2, 1})
                else
                    -- If upgrade failed, give ammo instead
                    player:addAmmo(20)
                    particles:createPickupEffect(pickup.x, pickup.y, {1, 0.8, 0.2})
                end
            end
            table.remove(self.pickups, i)
        elseif pickup.age >= pickup.lifetime then
            -- Pickup expired
            table.remove(self.pickups, i)
        end
    end
end

function Drops:drawPickups()
    for _, pickup in ipairs(self.pickups) do
        local alpha = 1 - (pickup.age / pickup.lifetime) * 0.5
        love.graphics.setColor(pickup.color[1], pickup.color[2], pickup.color[3], alpha)
        love.graphics.circle('fill', pickup.x, pickup.y, pickup.size)

        -- Pulsing effect
        local pulse = math.sin(love.timer.getTime() * 5) * 2 + pickup.size
        love.graphics.setColor(1, 1, 1, alpha * 0.3)
        love.graphics.circle('line', pickup.x, pickup.y, pulse)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Drops:clear()
    self.pickups = {}
end

function Drops:getPickups()
    return self.pickups
end

-- Save drops state for persistence
function Drops:saveState()
    local state = {
        pickups = {},
        spawners = {}
    }
    
    -- Save active pickups
    for _, pickup in ipairs(self.pickups) do
        table.insert(state.pickups, {
            x = pickup.x,
            y = pickup.y,
            type = pickup.type,
            lifetime = pickup.lifetime,
            age = pickup.age,
            size = pickup.size,
            color = pickup.color,
            spawnerId = pickup.spawnerId
        })
    end
    
    -- Save temporary spawners from map
    if self.map and self.map.data and self.map.data.spawners then
        for spawnerId, spawner in pairs(self.map.data.spawners) do
            if spawner.temporary then
                state.spawners[spawnerId] = {
                    type = spawner.type,
                    position = {spawner.position[1], spawner.position[2]},
                    item = spawner.item,
                    temporary = true,
                    lifetime = spawner.lifetime,
                    age = spawner.age or 0,
                    spawned = spawner.spawned
                }
            end
        end
    end
    
    return state
end

-- Restore drops state from saved data
function Drops:restoreState(state)
    if not state then return end
    
    -- Restore pickups
    self.pickups = {}
    if state.pickups then
        for _, pickup in ipairs(state.pickups) do
            table.insert(self.pickups, {
                x = pickup.x,
                y = pickup.y,
                type = pickup.type,
                lifetime = pickup.lifetime,
                age = pickup.age,
                size = pickup.size,
                color = pickup.color,
                spawnerId = pickup.spawnerId
            })
        end
    end
    
    -- Restore temporary spawners to map
    if state.spawners and self.map and self.map.data and self.map.data.spawners then
        for spawnerId, spawner in pairs(state.spawners) do
            self.map.data.spawners[spawnerId] = {
                type = spawner.type,
                position = {spawner.position[1], spawner.position[2]},
                item = spawner.item,
                temporary = spawner.temporary,
                lifetime = spawner.lifetime,
                age = spawner.age,
                spawned = spawner.spawned
            }
        end
    end
end

return Drops
