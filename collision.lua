-- Collision system module
local Collision = {}

function Collision:new()
    local collision = {
        mapPolygons = {},        -- Static geometry from map
        spatialGrid = {},         -- Grid for collision optimization
        cellSize = 64             -- Size of spatial grid cells
    }
    setmetatable(collision, { __index = self })
    return collision
end

function Collision:resolvePlayerEnemies(player, enemies)
    local radii = {player = player.width * 0.5, enemy = 32}  -- Assume all enemies same size

    for _, enemy in ipairs(enemies) do
        local dx = enemy.x - player.x
        local dy = enemy.y - player.y
        local dist = math.sqrt(dx*dx + dy*dy)
        local minDist = radii.player + radii.enemy
        
        if dist > 0 and dist < minDist then
            local overlap = minDist - dist
            local pushX = (dx / dist) * overlap * 0.5
            local pushY = (dy / dist) * overlap * 0.5
            player.x = player.x - pushX
            player.y = player.y - pushY
            enemy.x = enemy.x + pushX
            enemy.y = enemy.y + pushY
        end
    end
end

function Collision:resolveEnemiesEnemies(enemies)
    local radius = 32  -- Enemy collision radius

    for i, e1 in ipairs(enemies) do
        for j, e2 in ipairs(enemies) do
            if i < j then
                local dx = e2.x - e1.x
                local dy = e2.y - e1.y
                local dist = math.sqrt(dx*dx + dy*dy)
                local minDist = radius * 2
                
                if dist > 0 and dist < minDist then
                    local overlap = minDist - dist
                    local pushX = (dx / dist) * overlap * 0.5
                    local pushY = (dy / dist) * overlap * 0.5
                    e1.x = e1.x - pushX
                    e1.y = e1.y - pushY
                    e2.x = e2.x + pushX
                    e2.y = e2.y + pushY
                end
            end
        end
    end
end

function Collision:resolvePlayerBoundaries(player)
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()

    -- Boundary collision (treating view edges as solid walls)
    -- Left boundary
    if player.x < 0 then
        player.x = 0
        player.vx = 0  -- Handle horizontal velocity if it exists
    end

    -- Right boundary
    if player.x + player.width > screenW + 999999999 then
        player.x = screenW - player.width
        player.vx = 0
    end

    -- Top boundary
    if player.y < 0 then
        player.y = 0
        player.vy = 0
    end

    -- Bottom boundary
    if player.y + player.height > screenH + 9999999999 then
        player.y = screenH - player.height
        player.vy = 0
    end
end

function Collision:resolveEnemiesBoundaries(enemies)
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()

    for _, enemy in ipairs(enemies) do
        -- Left boundary
        if enemy.x < 0 then
            enemy.x = 0
        end

        -- Right boundary
        if enemy.x + enemy.width > screenW then
            enemy.x = screenW - enemy.width
        end

        -- Top boundary
        if enemy.y < 0 then
            enemy.y = 0
        end

        -- Bottom boundary
        if enemy.y + enemy.height > screenH then
            enemy.y = screenH - enemy.height
        end
    end
end

function Collision:createMapGeometry(map)
    if not map then return end
    self.map = map  -- Store map reference
    self.mapPolygons = map:getCollisionPolygons()
    self.mapBounds = map:getMapBounds()
    self:createSpatialGrid()
end

function Collision:getActivePolygons()
    -- Get only enabled polygons if map is available
    if self.map and self.map.getCollisionPolygonsEnabled then
        return self.map:getCollisionPolygonsEnabled()
    end
    return self.mapPolygons or {}
end

function Collision:createSpatialGrid()
    if not self.mapPolygons or #self.mapPolygons == 0 then return end

    -- Calculate grid dimensions
    self.gridWidth = math.ceil((self.mapBounds.w or 1280) / self.cellSize)
    self.gridHeight = math.ceil((self.mapBounds.h or 720) / self.cellSize)

    -- Initialize grid
    self.spatialGrid = {}
    for x = 1, self.gridWidth do
        self.spatialGrid[x] = {}
        for y = 1, self.gridHeight do
            self.spatialGrid[x][y] = {}
        end
    end

    -- Place polygons in grid cells
    for polyIndex, polygon in ipairs(self.mapPolygons) do
        -- Find bounding box of polygon
        local minX, maxX = math.huge, -math.huge
        local minY, maxY = math.huge, -math.huge

        for _, point in ipairs(polygon) do
            minX = math.min(minX, point[1])
            maxX = math.max(maxX, point[1])
            minY = math.min(minY, point[2])
            maxY = math.max(maxY, point[2])
        end

        -- Get grid cells that this polygon spans
        local startCol = math.max(1, math.floor(minX / self.cellSize) + 1)
        local endCol = math.min(self.gridWidth, math.floor(maxX / self.cellSize) + 1)
        local startRow = math.max(1, math.floor(minY / self.cellSize) + 1)
        local endRow = math.min(self.gridHeight, math.floor(maxY / self.cellSize) + 1)

        -- Add polygon to each intersecting cell
        for col = startCol, endCol do
            for row = startRow, endRow do
                table.insert(self.spatialGrid[col][row], polyIndex)
            end
        end
    end
end

function Collision:getNearbyPolygons(x, y, radius)
    local nearby = {}
    local startCol = math.max(1, math.floor((x - radius) / self.cellSize) + 1)
    local endCol = math.min(self.gridWidth or 1, math.floor((x + radius) / self.cellSize) + 1)
    local startRow = math.max(1, math.floor((y - radius) / self.cellSize) + 1)
    local endRow = math.min(self.gridHeight or 1, math.floor((y + radius) / self.cellSize) + 1)

    for col = startCol, endCol do
        for row = startRow, endRow do
            if self.spatialGrid and self.spatialGrid[col] and self.spatialGrid[col][row] then
                for _, polyIndex in ipairs(self.spatialGrid[col][row]) do
                    nearby[polyIndex] = true
                end
            end
        end
    end

    local result = {}
    for polyIndex in pairs(nearby) do
        table.insert(result, self.mapPolygons[polyIndex])
    end
    return result
end

function Collision:pointInPolygon(px, py, polygon)
    if not polygon or #polygon < 3 then return false end

    local inside = false
    local j = #polygon

    for i = 1, #polygon do
        local xi, yi = polygon[i][1], polygon[i][2]
        local xj, yj = polygon[j][1], polygon[j][2]

        if ((yi > py) ~= (yj > py)) and
           (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end

    return inside
end

function Collision:resolveEntityMapCollision(entity, polygon)
    if not polygon or #polygon < 3 then return false end

    local entityX = entity.x + entity.width / 2
    local entityY = entity.y + entity.height / 2
    local radius = math.max(entity.width, entity.height) / 2
    
    -- Find the closest edge of the polygon
    local minDist = math.huge
    local pushX, pushY = 0, 0
    
    for i = 1, #polygon do
        local j = (i % #polygon) + 1
        local x1, y1 = polygon[i][1], polygon[i][2]
        local x2, y2 = polygon[j][1], polygon[j][2]
        
        -- Calculate closest point on this edge to entity
        local edgeDx = x2 - x1
        local edgeDy = y2 - y1
        local edgeLengthSq = edgeDx * edgeDx + edgeDy * edgeDy
        
        if edgeLengthSq > 0 then
            local t = ((entityX - x1) * edgeDx + (entityY - y1) * edgeDy) / edgeLengthSq
            t = math.max(0, math.min(1, t))
            
            local closestX = x1 + t * edgeDx
            local closestY = y1 + t * edgeDy
            
            -- Distance from entity to edge
            local dx = entityX - closestX
            local dy = entityY - closestY
            local dist = math.sqrt(dx * dx + dy * dy)
            
            -- Check if this is the closest edge AND we're too close
            if dist < minDist then
                minDist = dist
                if dist > 0.001 then
                    pushX = dx / dist
                    pushY = dy / dist
                end
            end
        end
    end
    
    -- If we're too close to an edge, push away
    if minDist < radius then
        local overlap = radius - minDist
        entity.x = entity.x + pushX * overlap
        entity.y = entity.y + pushY * overlap
        return true
    end
    
    return false
end

function Collision:findClosestPointOnPolygon(px, py, polygon)
    local closestX, closestY, minDist = nil, nil, math.huge

    for i = 1, #polygon do
        local j = (i % #polygon) + 1
        local x1, y1 = polygon[i][1], polygon[i][2]
        local x2, y2 = polygon[j][1], polygon[j][2]

        -- Find closest point on this line segment
        local dx = x2 - x1
        local dy = y2 - y1
        local length = math.sqrt(dx * dx + dy * dy)

        if length > 0 then
            local t = math.max(0, math.min(1, ((px - x1) * dx + (py - y1) * dy) / (length * length)))
            local closestX_seg = x1 + t * dx
            local closestY_seg = y1 + t * dy
            local dist = math.sqrt((px - closestX_seg) * (px - closestX_seg) + (py - closestY_seg) * (py - closestY_seg))

            if dist < minDist then
                minDist = dist
                closestX = closestX_seg
                closestY = closestY_seg
            end
        end
    end

    return closestX, closestY
end

function Collision:updateEntityMapCollision(entity)
    local activePolygons = self:getActivePolygons()
    if not activePolygons or #activePolygons == 0 then return false end

    local entityX = entity.x + entity.width / 2
    local entityY = entity.y + entity.height / 2

    local collided = false
    for _, polygon in ipairs(activePolygons) do
        -- Check if polygon is enabled (default to true if not specified)
        if polygon.enabled ~= false then
            if self:resolveEntityMapCollision(entity, polygon) then
                collided = true
            end
        end
    end

    return collided
end

function Collision:update(player, enemies)
    -- Map collision before other collision types
    if self:updateEntityMapCollision(player) then
        -- Player collided with map, skip screen boundary check
    else
        self:resolvePlayerBoundaries(player)
    end

    for _, enemy in ipairs(enemies) do
        if self:updateEntityMapCollision(enemy) then
            -- Enemy collided with map, skip screen boundary check
        else
            self:resolveEnemyBoundary(enemy)
        end
    end

    -- Entity collisions
    if #enemies > 0 then
        self:resolvePlayerEnemies(player, enemies)
        self:resolveEnemiesEnemies(enemies)
    end
end

function Collision:resolveEnemyBoundary(enemy)
    -- Use map bounds if available, otherwise fall back to screen bounds
    if self.mapBounds then
        local margin = 10 -- Small margin to keep entities on screen

        if enemy.x < self.mapBounds.x then enemy.x = self.mapBounds.x end
        if enemy.y < self.mapBounds.y then enemy.y = self.mapBounds.y end
        if enemy.x + enemy.width > self.mapBounds.x + self.mapBounds.w then
            enemy.x = self.mapBounds.x + self.mapBounds.w - enemy.width
        end
        if enemy.y + enemy.height > self.mapBounds.y + self.mapBounds.h then
            enemy.y = self.mapBounds.y + self.mapBounds.h - enemy.height
        end
    else
        -- Original screen boundary logic
        local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
        if enemy.x < 0 then enemy.x = 0 end
        if enemy.x + enemy.width > screenW then enemy.x = screenW - enemy.width end
        if enemy.y < 0 then enemy.y = 0 end
        if enemy.y + enemy.height > screenH then enemy.y = screenH - enemy.height end
    end
end

-- Ray-polygon intersection for bullet/tracer collision
-- Returns the closest hit distance and hit point, or nil if no hit
function Collision:raycastAgainstWalls(startX, startY, dirX, dirY, maxDistance)
    if not self.mapPolygons or #self.mapPolygons == 0 then
        return nil
    end
    
    maxDistance = maxDistance or 10000
    
    -- Get nearby polygons using spatial grid
    local nearbyPolygons
    if self.spatialGrid and #self.spatialGrid > 0 then
        nearbyPolygons = self:getNearbyPolygons(startX, startY, maxDistance)
    else
        nearbyPolygons = self.mapPolygons
    end
    
    local closestDist = maxDistance
    local closestHitX, closestHitY = nil, nil
    
    -- Check each polygon
    for _, polygon in ipairs(nearbyPolygons) do
        if polygon and #polygon >= 3 then
            -- Check each edge of the polygon
            for i = 1, #polygon do
                local j = (i % #polygon) + 1
                local x1, y1 = polygon[i][1], polygon[i][2]
                local x2, y2 = polygon[j][1], polygon[j][2]
                
                -- Check if ray intersects this edge
                local hitX, hitY, dist = self:raySegmentIntersection(
                    startX, startY, dirX, dirY,
                    x1, y1, x2, y2
                )
                
                if hitX and dist < closestDist then
                    closestDist = dist
                    closestHitX = hitX
                    closestHitY = hitY
                end
            end
        end
    end
    
    if closestHitX then
        return closestDist, closestHitX, closestHitY
    end
    
    return nil
end

-- Ray-line segment intersection
-- Returns hit point and distance if intersection exists, nil otherwise
function Collision:raySegmentIntersection(rayX, rayY, rayDirX, rayDirY, segX1, segY1, segX2, segY2)
    -- Edge vector
    local edgeDx = segX2 - segX1
    local edgeDy = segY2 - segY1
    
    -- Calculate denominator for intersection formula
    local denom = rayDirX * edgeDy - rayDirY * edgeDx
    
    -- If denominator is close to 0, lines are parallel
    if math.abs(denom) < 0.0001 then
        return nil
    end
    
    -- Calculate parameters
    local t = ((segX1 - rayX) * edgeDy - (segY1 - rayY) * edgeDx) / denom
    local u = ((segX1 - rayX) * rayDirY - (segY1 - rayY) * rayDirX) / denom
    
    -- Check if intersection is valid
    -- t >= 0: ray goes forward from start point
    -- u between 0 and 1: intersection is on the line segment
    if t >= 0 and u >= 0 and u <= 1 then
        local hitX = rayX + rayDirX * t
        local hitY = rayY + rayDirY * t
        local dist = t * math.sqrt(rayDirX * rayDirX + rayDirY * rayDirY)
        return hitX, hitY, dist
    end
    
    return nil
end

return Collision
