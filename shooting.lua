-- Shooting system module
local Shooting = {}

function Shooting:new()
    local shooting = {}
    setmetatable(shooting, { __index = self })
    return shooting
end

function Shooting:shootRay(player, enemies, accuracy, range, maxRange, collateral, collateralFalloff, collision)
    -- Default values if not provided
    accuracy = accuracy or 0.95
    range = range or 500
    maxRange = maxRange or range * 1.6  -- Default max range if not provided
    collateral = collateral or 1  -- Default to hitting 1 enemy
    collateralFalloff = collateralFalloff or 1.0  -- Default to no falloff

    -- Get current weapon
    local weapon = player:getCurrentWeapon()
    local weaponType = weapon.type
    local weaponConfig = require('weapons').TYPES[weaponType]

    -- Special handling for shotgun (12 gauge) - fire multiple pellets
    if weaponConfig.ammoType == require('weapons').AMMO_TYPES.AMMO_12GAUGE then
        return self:shootShotgunPellets(player, enemies, accuracy, range, maxRange, collateral, collateralFalloff, weaponConfig, collision)
    end

    -- Default single-ray shooting logic
    local px, py = player:getMuzzlePosition()
    local dx = math.cos(player.angle)
    local dy = math.sin(player.angle)

    -- Apply accuracy spread
    local spreadAngle = (1 - accuracy) * math.pi/8  -- Max 22.5 degrees spread
    local actualAngle = player.angle + (math.random() - 0.5) * spreadAngle
    dx = math.cos(actualAngle)
    dy = math.sin(actualAngle)

    -- Check for wall collision first
    local wallHitDist = maxRange
    if collision then
        local hitDist, hitX, hitY = collision:raycastAgainstWalls(px, py, dx, dy, maxRange)
        if hitDist then
            wallHitDist = hitDist
        end
    end

    local hitEnemies = {}

    for i, enemy in ipairs(enemies) do
        -- Get enemy bounding box for precise collision detection
        local boxX, boxY, boxW, boxH = enemy:getBoundingBox()

        -- Check if the ray intersects the enemy's bounding box
        if self:lineIntersectsRect(px, py, dx, dy, boxX, boxY, boxW, boxH) then
            -- Calculate distance from muzzle to enemy center for sorting and hit distance
            local ex, ey = enemy:getCenter()
            local dist = math.sqrt((ex - px)^2 + (ey - py)^2)

            -- Only add enemy if it's not behind a wall and within range
            if dist <= maxRange and dist < wallHitDist then
                -- Calculate dot product for sorting (closer enemies first)
                local dot = (ex - px) * dx + (ey - py) * dy

                table.insert(hitEnemies, {
                    index = i,
                    distance = dot,  -- Use for sorting order
                    hitDistance = dist
                })
            end
        end
    end

    -- Sort enemies by distance (closest first)
    table.sort(hitEnemies, function(a, b) return a.distance < b.distance end)

    -- Return up to collateral number of enemies with damage multipliers
    -- Also include wall hit distance for tracer rendering
    local result = {}
    result.wallHitDist = wallHitDist
    
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

-- Special shotgun pellet shooting function
function Shooting:shootShotgunPellets(player, enemies, accuracy, range, maxRange, collateral, collateralFalloff, weaponConfig, collision)
    local px, py = player:getMuzzlePosition()
    local baseAngle = player.angle

    local allHitEnemies = {}
    local pelletTrajectoryInfo = {}
    local pelletsFired = (weaponConfig.specificVars and weaponConfig.specificVars.pellets) or 8
    local spreadAngle = (weaponConfig.specificVars and weaponConfig.specificVars.pelletSpread) or math.pi/6  -- from specificVars section

    -- Fire multiple pellets in a spread pattern
    for pellet = 1, pelletsFired do
        -- Calculate pellet angle within the spread cone
        local pelletAngle = baseAngle + (math.random() - 0.5) * spreadAngle * 2

        -- Apply additional accuracy deviation
        local accuracySpread = (1 - accuracy) * math.pi/8
        pelletAngle = pelletAngle + (math.random() - 0.5) * accuracySpread

        local dx = math.cos(pelletAngle)
        local dy = math.sin(pelletAngle)

        -- Check for wall collision for this pellet
        local pelletWallHitDist = maxRange
        if collision then
            local hitDist, hitX, hitY = collision:raycastAgainstWalls(px, py, dx, dy, maxRange)
            if hitDist then
                pelletWallHitDist = hitDist
            end
        end

        -- Track this pellet's trajectory info
        local pelletInfo = {
            angle = pelletAngle,
            hitDistance = pelletWallHitDist  -- Default to wall hit distance
        }

        -- Check hits for this pellet using bounding boxes
        for i, enemy in ipairs(enemies) do
            -- Get enemy bounding box for precise collision detection
            local boxX, boxY, boxW, boxH = enemy:getBoundingBox()

            -- Check if the pellet ray intersects the enemy's bounding box
            if self:lineIntersectsRect(px, py, dx, dy, boxX, boxY, boxW, boxH) then
                -- Calculate distance from muzzle to enemy center for sorting
                local ex, ey = enemy:getCenter()
                local dist = math.sqrt((ex - px)^2 + (ey - py)^2)

                -- Only count hit if enemy is not behind a wall and within range
                if dist <= maxRange and dist < pelletWallHitDist then
                    -- Calculate dot product for sorting order
                    local dot = (ex - px) * dx + (ey - py) * dy

                    table.insert(allHitEnemies, {
                        index = i,
                        distance = dot,  -- Use for sorting order
                        hitDistance = dist,
                        pelletAngle = pelletAngle  -- Track which pellet hit
                    })

                    -- Store hit distance for this pellet's tracer (enemy hit)
                    if not pelletInfo.hitDistance or dist < pelletInfo.hitDistance then
                        pelletInfo.hitDistance = dist
                    end
                end
            end
        end

        table.insert(pelletTrajectoryInfo, pelletInfo)
    end

    -- Process hits: count pellet hits per enemy (multiple pellets can hit same enemy)
    local enemyHitCounts = {}
    local enemyHitData = {}

    for _, hit in ipairs(allHitEnemies) do
        if not enemyHitCounts[hit.index] then
            enemyHitCounts[hit.index] = 0
            enemyHitData[hit.index] = {
                index = hit.index,
                hitDistance = hit.hitDistance,
                pelletCount = 0
            }
        end
        enemyHitCounts[hit.index] = enemyHitCounts[hit.index] + 1
        enemyHitData[hit.index].pelletCount = enemyHitCounts[hit.index]
    end

    -- Convert to array and sort by distance (closest first)
    local uniqueHits = {}
    for _, hitData in pairs(enemyHitData) do
        table.insert(uniqueHits, hitData)
    end
    table.sort(uniqueHits, function(a, b) return a.hitDistance < b.hitDistance end)

    -- Return results with pellet impact multipliers
    local result = {}
    for i = 1, math.min(collateral, #uniqueHits) do
        local hit = uniqueHits[i]
        -- Damage multiplier based on number of pellets that hit
        local pelletMultiplier = hit.pelletCount
        -- Apply any additional collateral falloff if multiple enemies hit
        local enemyFalloffMultiplier = math.pow(collateralFalloff, i - 1)
        table.insert(result, {
            enemyIndex = hit.index,
            hitDistance = hit.hitDistance,
            damageMultiplier = pelletMultiplier * enemyFalloffMultiplier,
            pelletCount = pelletMultiplier  -- Number of pellets that hit this enemy
        })
    end

    -- Attach pellet trajectory info to the result
    result.pelletHits = pelletTrajectoryInfo

    return result
end

function Shooting:drawRay(player, debug)
    if debug then
        love.graphics.setColor(1, 1, 0, 0.5)  -- Yellow for ray
        local rayLength = 500  -- Shorter for visibility
        local rayEndX = player.x + player.width/2 + math.cos(player.angle) * rayLength
        local rayEndY = player.y + player.height/2 + math.sin(player.angle) * rayLength
        love.graphics.line(player.x + player.width/2, player.y + player.height/2, rayEndX, rayEndY)
        love.graphics.setColor(1, 1, 1, 1)  -- Reset to white
    end
end

-- Calculate maximum tracer distance constrained by world boundaries (same as collision system)
function Shooting:getMaxWorldBoundaryDistance(player)
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local dx = math.cos(player.angle)
    local dy = math.sin(player.angle)

    -- Ray starts from muzzle position in world space
    local startX, startY = player:getMuzzlePosition()

    -- World boundaries (same solid walls entities collide with: screen edges)
    local worldLeft = 0
    local worldRight = screenW
    local worldTop = 0
    local worldBottom = screenH

    -- Calculate intersections with world boundaries (solid walls)
    local intersections = {}

    -- Right boundary (x = worldRight)
    if dx > 0 then
        local t = (worldRight - startX) / dx
        if t > 0 then
            local hitY = startY + dy * t
            if hitY >= worldTop and hitY <= worldBottom then
                table.insert(intersections, t)
            end
        end
    end

    -- Left boundary (x = worldLeft)
    if dx < 0 then
        local t = (worldLeft - startX) / dx
        if t > 0 then
            local hitY = startY + dy * t
            if hitY >= worldTop and hitY <= worldBottom then
                table.insert(intersections, t)
            end
        end
    end

    -- Bottom boundary (y = worldBottom)
    if dy > 0 then
        local t = (worldBottom - startY) / dy
        if t > 0 then
            local hitX = startX + dx * t
            if hitX >= worldLeft and hitX <= worldRight then
                table.insert(intersections, t)
            end
        end
    end

    -- Top boundary (y = worldTop)
    if dy < 0 then
        local t = (worldTop - startY) / dy
        if t > 0 then
            local hitX = startX + dx * t
            if hitX >= worldLeft and hitX <= worldRight then
                table.insert(intersections, t)
            end
        end
    end

    -- Find the smallest positive distance to solid wall
    local minDistance = 10000  -- Large default for open world
    for _, distance in ipairs(intersections) do
        if distance > 0 and distance < minDistance then
            minDistance = distance
        end
    end

    return math.min(minDistance, 10000)  -- Allow very long tracers if no wall in direction
end

-- Line-rectangle intersection helper function
-- Returns true if the ray from (lineX,lineY) with direction (dirX,dirY) intersects rectangle (rectX,rectY,rectW,rectH)
function Shooting:lineIntersectsRect(lineX, lineY, dirX, dirY, rectX, rectY, rectW, rectH)
    local rectRight = rectX + rectW
    local rectBottom = rectY + rectH

    -- Store intersection points and their distances
    local intersections = {}

    -- Left edge of rectangle
    if dirX ~= 0 then
        local t = (rectX - lineX) / dirX
        if t >= 0 then  -- Only forward direction, no upper bound since we can shoot unlimited distance
            local iy = lineY + dirY * t
            if iy >= rectY and iy <= rectBottom then
                return true  -- Found intersection, no need to check others
            end
        end

        -- Right edge of rectangle
        local t = (rectRight - lineX) / dirX
        if t >= 0 then
            local iy = lineY + dirY * t
            if iy >= rectY and iy <= rectBottom then
                return true
            end
        end
    end

    -- Top edge of rectangle
    if dirY ~= 0 then
        local t = (rectY - lineY) / dirY
        if t >= 0 then
            local ix = lineX + dirX * t
            if ix >= rectX and ix <= rectRight then
                return true
            end
        end

        -- Bottom edge of rectangle
        local t = (rectBottom - lineY) / dirY
        if t >= 0 then
            local ix = lineX + dirX * t
            if ix >= rectX and ix <= rectRight then
                return true
            end
        end
    end

    return false
end

return Shooting
