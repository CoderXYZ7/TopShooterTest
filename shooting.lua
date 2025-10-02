-- Shooting system module
local Shooting = {}

function Shooting:new()
    local shooting = {}
    setmetatable(shooting, { __index = self })
    return shooting
end

function Shooting:shootRay(player, enemies, accuracy, range, maxRange, collateral, collateralFalloff)
    -- Default values if not provided
    accuracy = accuracy or 0.95
    range = range or 500
    maxRange = maxRange or range * 1.6  -- Default max range if not provided
    collateral = collateral or 1  -- Default to hitting 1 enemy
    collateralFalloff = collateralFalloff or 1.0  -- Default to no falloff
    
    -- Get player position and direction
    local px, py = player:getCenter()
    local dx = math.cos(player.angle)
    local dy = math.sin(player.angle)
    
    -- Apply accuracy spread
    local spreadAngle = (1 - accuracy) * math.pi/8  -- Max 22.5 degrees spread
    local actualAngle = player.angle + (math.random() - 0.5) * spreadAngle
    dx = math.cos(actualAngle)
    dy = math.sin(actualAngle)
    
    local hitEnemies = {}
    
    for i, enemy in ipairs(enemies) do
        local ex, ey = enemy:getCenter()
        
        -- Calculate distance from player to enemy
        local dist = math.sqrt((ex - px)^2 + (ey - py)^2)
        
        if dist <= maxRange then
            -- Calculate projection of enemy position onto ray
            local dot = (ex - px) * dx + (ey - py) * dy
            
            -- Calculate perpendicular distance from enemy to ray
            local perpDist = math.sqrt(dist^2 - dot^2)
            
            -- Check if enemy is in front of player and within hit radius
            if dot > 0 and perpDist < 30 then  -- Hit radius of 30 pixels
                table.insert(hitEnemies, {
                    index = i,
                    distance = dot,  -- Use dot product for ordering (closest first)
                    hitDistance = dist
                })
            end
        end
    end
    
    -- Sort enemies by distance (closest first)
    table.sort(hitEnemies, function(a, b) return a.distance < b.distance end)
    
    -- Return up to collateral number of enemies with damage multipliers
    local result = {}
    for i = 1, math.min(collateral, #hitEnemies) do
        local hit = hitEnemies[i]
        local damageMultiplier = math.pow(collateralFalloff, i - 1)  -- First enemy gets full damage
        table.insert(result, {
            enemyIndex = hit.index,
            hitDistance = hit.hitDistance,
            damageMultiplier = damageMultiplier
        })
    end
    
    return result
end

function Shooting:drawRay(player, debug)
    if debug then
        love.graphics.setColor(1, 1, 0, 0.5)  -- Yellow for ray
        local rayLength = 500  -- Shorter for visibility
        local rayEndX = player.x + player.width/2 + math.cos(player.angle) * rayLength
        local rayEndY = player.y + player.height/2 + math.sin(player.angle) * rayLength
        love.graphics.line(player.x + player.width/2, player.y + player.height/2, rayEndX, rayEndY)
        love.graphics.setColor(1, 1, 1)  -- Reset to white
    end
end

return Shooting
