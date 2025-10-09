-- Simple Drops and Pickups management module
local Drops = {}

function Drops:new()
    local drops = {
        pickups = {}
    }
    setmetatable(drops, { __index = self })
    return drops
end

-- Create a drop at specified coordinates
function Drops:spawnDropAt(x, y, dropType, amount)
    print(string.format("SPAWNING DROP: x=%.1f, y=%.1f, type=%s", x, y, dropType))
    
    -- Create simple pickup
    local pickup = {
        x = x,
        y = y,
        type = dropType,
        lifetime = 15.0,
        age = 0,
        size = 20
    }

    -- Set color based on item type
    if dropType == "MEDKIT" then
        pickup.color = {1, 0.2, 0.2}  -- Red for health
    elseif dropType == "AMMO" then
        pickup.color = {1, 0.8, 0.2}  -- Gold for ammo
    elseif dropType == "WEAPON_UPGRADE" then
        pickup.color = {0.8, 0.2, 1}  -- Purple for upgrades
    else
        pickup.color = {0.5, 0.5, 0.5}  -- Gray for unknown
    end

    table.insert(self.pickups, pickup)
    print("  ✓ Drop created: " .. dropType .. " at " .. x .. ", " .. y)
    return true
end

-- Update pickups (check collection and expiration)
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
            if pickup.type == "MEDKIT" then
                player:heal(25)
                particles:createPickupEffect(pickup.x, pickup.y, {1, 0.2, 0.2})
                print("  ✓ Collected MEDKIT")
            elseif pickup.type == "AMMO" then
                player:addAmmo(15)
                particles:createPickupEffect(pickup.x, pickup.y, {0.2, 0.2, 1})
                print("  ✓ Collected AMMO")
            elseif pickup.type == "WEAPON_UPGRADE" then
                -- Give player money as upgrade alternative
                player:addMoney(100)
                particles:createPickupEffect(pickup.x, pickup.y, {0.8, 0.2, 1})
                print("  ✓ Collected WEAPON_UPGRADE")
            end
            table.remove(self.pickups, i)
        elseif pickup.age >= pickup.lifetime then
            -- Pickup expired
            table.remove(self.pickups, i)
        end
    end
end

-- Draw all pickups
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

-- Clear all pickups
function Drops:clear()
    self.pickups = {}
end

-- Backward compatibility
function Drops:createDrop(x, y, dropType, amount)
    return self:spawnDropAt(x, y, dropType, amount)
end

-- Empty functions for compatibility
function Drops:setMap(map) end
function Drops:updateTemporarySpawners(dt, player, particles) end
function Drops:spawnItemFromSpawner(spawner, spawnerId) end
function Drops:saveState() return {} end
function Drops:restoreState(state) end

return Drops
