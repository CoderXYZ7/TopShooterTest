-- A* Pathfinding module for enemy navigation
local Pathfinding = {}

function Pathfinding:new(gridSize)
    local pf = {
        gridSize = gridSize or 32,  -- Size of each grid cell
        grid = {},  -- Navigation grid
        mapBounds = {x = 0, y = 0, w = 0, h = 0},
        collisionPolygons = {},
        initialized = false
    }
    setmetatable(pf, { __index = self })
    return pf
end

-- Initialize the navigation grid based on map collision
function Pathfinding:initialize(map, entityRadius)
    if not map then return end
    
    self.mapBounds = map:getMapBounds()
    self.collisionPolygons = map:getCollisionPolygons()
    self.entityRadius = entityRadius or 32  -- Default collision radius for entities
    
    -- Calculate grid dimensions
    local gridWidth = math.ceil(self.mapBounds.w / self.gridSize)
    local gridHeight = math.ceil(self.mapBounds.h / self.gridSize)
    
    print(string.format("Pathfinding: Initializing grid %dx%d (cell size: %d, entity radius: %d)", 
        gridWidth, gridHeight, self.gridSize, self.entityRadius))
    
    -- Create grid and mark obstacles
    self.grid = {}
    for gx = 0, gridWidth do
        self.grid[gx] = {}
        for gy = 0, gridHeight do
            -- World position of this grid cell center
            local wx = self.mapBounds.x + gx * self.gridSize + self.gridSize / 2
            local wy = self.mapBounds.y + gy * self.gridSize + self.gridSize / 2
            
            -- Check if an entity with the specified radius can fit here
            -- We check the center and also points around the radius
            local isWalkable = self:canEntityFitAt(wx, wy, self.entityRadius)
            
            self.grid[gx][gy] = {
                walkable = isWalkable,
                x = gx,
                y = gy
            }
        end
    end
    
    self.initialized = true
    print("Pathfinding: Grid initialized")
end

-- Check if an entity with given radius can fit at position
function Pathfinding:canEntityFitAt(cx, cy, radius)
    -- Check center point
    if self:pointInAnyPolygon(cx, cy) then
        return false
    end
    
    -- Check points around the circumference (8 points for efficiency)
    local numChecks = 8
    for i = 0, numChecks - 1 do
        local angle = (i / numChecks) * math.pi * 2
        local checkX = cx + math.cos(angle) * radius
        local checkY = cy + math.sin(angle) * radius
        
        if self:pointInAnyPolygon(checkX, checkY) then
            return false
        end
    end
    
    -- Also check if entity is too close to any wall edge
    for _, polygon in ipairs(self.collisionPolygons) do
        if polygon.enabled ~= false then
            for i = 1, #polygon do
                local j = (i % #polygon) + 1
                local x1, y1 = polygon[i][1], polygon[i][2]
                local x2, y2 = polygon[j][1], polygon[j][2]
                
                -- Find closest point on edge to entity center
                local edgeDx = x2 - x1
                local edgeDy = y2 - y1
                local edgeLengthSq = edgeDx * edgeDx + edgeDy * edgeDy
                
                if edgeLengthSq > 0 then
                    local t = ((cx - x1) * edgeDx + (cy - y1) * edgeDy) / edgeLengthSq
                    t = math.max(0, math.min(1, t))
                    
                    local closestX = x1 + t * edgeDx
                    local closestY = y1 + t * edgeDy
                    
                    -- Distance from entity center to edge
                    local dx = cx - closestX
                    local dy = cy - closestY
                    local dist = math.sqrt(dx * dx + dy * dy)
                    
                    -- If too close to wall, this position is not walkable
                    if dist < radius then
                        return false
                    end
                end
            end
        end
    end
    
    return true
end

-- Check if a point is inside any collision polygon
function Pathfinding:pointInAnyPolygon(x, y)
    for _, polygon in ipairs(self.collisionPolygons) do
        if polygon.enabled ~= false and self:pointInPolygon(x, y, polygon) then
            return true
        end
    end
    return false
end

-- Point in polygon test using ray casting algorithm
function Pathfinding:pointInPolygon(x, y, polygon)
    local inside = false
    local j = #polygon
    
    for i = 1, #polygon do
        local xi, yi = polygon[i][1], polygon[i][2]
        local xj, yj = polygon[j][1], polygon[j][2]
        
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        
        j = i
    end
    
    return inside
end

-- Convert world coordinates to grid coordinates
function Pathfinding:worldToGrid(x, y)
    local gx = math.floor((x - self.mapBounds.x) / self.gridSize)
    local gy = math.floor((y - self.mapBounds.y) / self.gridSize)
    return gx, gy
end

-- Convert grid coordinates to world coordinates (center of cell)
function Pathfinding:gridToWorld(gx, gy)
    local wx = self.mapBounds.x + gx * self.gridSize + self.gridSize / 2
    local wy = self.mapBounds.y + gy * self.gridSize + self.gridSize / 2
    return wx, wy
end

-- Get neighbors of a grid cell
function Pathfinding:getNeighbors(gx, gy)
    local neighbors = {}
    local directions = {
        {0, -1},  -- Up
        {1, 0},   -- Right
        {0, 1},   -- Down
        {-1, 0},  -- Left
        {1, -1},  -- Up-Right
        {1, 1},   -- Down-Right
        {-1, 1},  -- Down-Left
        {-1, -1}  -- Up-Left
    }
    
    for _, dir in ipairs(directions) do
        local nx = gx + dir[1]
        local ny = gy + dir[2]
        
        if self.grid[nx] and self.grid[nx][ny] and self.grid[nx][ny].walkable then
            table.insert(neighbors, {x = nx, y = ny, cost = (dir[1] ~= 0 and dir[2] ~= 0) and 1.414 or 1})
        end
    end
    
    return neighbors
end

-- Heuristic function (Manhattan distance)
function Pathfinding:heuristic(gx1, gy1, gx2, gy2)
    return math.abs(gx1 - gx2) + math.abs(gy1 - gy2)
end

-- A* pathfinding algorithm
function Pathfinding:findPath(startX, startY, endX, endY)
    if not self.initialized then 
        return nil 
    end
    
    local startGx, startGy = self:worldToGrid(startX, startY)
    local endGx, endGy = self:worldToGrid(endX, endY)
    
    -- Check if start and end are valid
    if not self.grid[startGx] or not self.grid[startGx][startGy] then
        return nil
    end
    if not self.grid[endGx] or not self.grid[endGx][endGy] then
        return nil
    end
    if not self.grid[startGx][startGy].walkable or not self.grid[endGx][endGy].walkable then
        return nil
    end
    
    -- Initialize open and closed lists
    local openSet = {}
    local closedSet = {}
    local cameFrom = {}
    local gScore = {}
    local fScore = {}
    
    -- Create unique key for grid positions
    local function key(gx, gy)
        return gx .. "," .. gy
    end
    
    local startKey = key(startGx, startGy)
    table.insert(openSet, {x = startGx, y = startGy})
    gScore[startKey] = 0
    fScore[startKey] = self:heuristic(startGx, startGy, endGx, endGy)
    
    while #openSet > 0 do
        -- Find node with lowest fScore
        local currentIdx = 1
        local currentKey = key(openSet[1].x, openSet[1].y)
        for i = 2, #openSet do
            local k = key(openSet[i].x, openSet[i].y)
            if fScore[k] < fScore[currentKey] then
                currentIdx = i
                currentKey = k
            end
        end
        
        local current = openSet[currentIdx]
        
        -- Check if we reached the goal
        if current.x == endGx and current.y == endGy then
            return self:reconstructPath(cameFrom, current, startGx, startGy)
        end
        
        -- Move current from open to closed
        table.remove(openSet, currentIdx)
        closedSet[currentKey] = true
        
        -- Check all neighbors
        for _, neighbor in ipairs(self:getNeighbors(current.x, current.y)) do
            local neighborKey = key(neighbor.x, neighbor.y)
            
            if not closedSet[neighborKey] then
                local tentativeGScore = gScore[currentKey] + neighbor.cost
                
                local inOpenSet = false
                for _, node in ipairs(openSet) do
                    if node.x == neighbor.x and node.y == neighbor.y then
                        inOpenSet = true
                        break
                    end
                end
                
                if not inOpenSet then
                    table.insert(openSet, {x = neighbor.x, y = neighbor.y})
                elseif tentativeGScore >= (gScore[neighborKey] or math.huge) then
                    goto continue
                end
                
                -- This path is the best so far
                cameFrom[neighborKey] = current
                gScore[neighborKey] = tentativeGScore
                fScore[neighborKey] = tentativeGScore + self:heuristic(neighbor.x, neighbor.y, endGx, endGy)
            end
            
            ::continue::
        end
    end
    
    -- No path found
    return nil
end

-- Reconstruct path from A* result
function Pathfinding:reconstructPath(cameFrom, current, startGx, startGy)
    local path = {}
    local function key(gx, gy)
        return gx .. "," .. gy
    end
    
    while current do
        local wx, wy = self:gridToWorld(current.x, current.y)
        table.insert(path, 1, {x = wx, y = wy})
        
        if current.x == startGx and current.y == startGy then
            break
        end
        
        current = cameFrom[key(current.x, current.y)]
    end
    
    return path
end

-- Simplify path by removing unnecessary waypoints
function Pathfinding:simplifyPath(path)
    if not path or #path <= 2 then
        return path
    end
    
    local simplified = {path[1]}
    local current = 1
    
    while current < #path do
        local farthest = current + 1
        
        -- Try to find the farthest point we can reach directly
        for i = #path, current + 1, -1 do
            if self:hasLineOfSight(path[current].x, path[current].y, path[i].x, path[i].y) then
                farthest = i
                break
            end
        end
        
        table.insert(simplified, path[farthest])
        current = farthest
    end
    
    return simplified
end

-- Check if there's line of sight between two points with collision radius safety
function Pathfinding:hasLineOfSight(x1, y1, x2, y2)
    local steps = math.max(math.abs(x2 - x1), math.abs(y2 - y1)) / (self.gridSize / 2)
    
    -- Check multiple points along the path
    for i = 0, steps do
        local t = i / steps
        local x = x1 + (x2 - x1) * t
        local y = y1 + (y2 - y1) * t
        
        -- Check if this point (with entity radius) can safely fit
        if not self:canEntityFitAt(x, y, self.entityRadius) then
            return false
        end
    end
    
    return true
end

-- Debug draw the navigation grid
function Pathfinding:debugDraw()
    if not self.initialized then return end
    
    for gx, col in pairs(self.grid) do
        for gy, cell in pairs(col) do
            local wx, wy = self:gridToWorld(gx, gy)
            
            if cell.walkable then
                love.graphics.setColor(0, 1, 0, 0.1)
            else
                love.graphics.setColor(1, 0, 0, 0.2)
            end
            
            love.graphics.rectangle('fill', wx - self.gridSize/2, wy - self.gridSize/2, 
                self.gridSize, self.gridSize)
        end
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

-- Debug draw a path
function Pathfinding:debugDrawPath(path)
    if not path or #path < 2 then return end
    
    love.graphics.setColor(0, 1, 1, 0.8)
    love.graphics.setLineWidth(3)
    
    for i = 1, #path - 1 do
        love.graphics.line(path[i].x, path[i].y, path[i + 1].x, path[i + 1].y)
    end
    
    -- Draw waypoints
    for _, waypoint in ipairs(path) do
        love.graphics.circle('fill', waypoint.x, waypoint.y, 5)
    end
    
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

return Pathfinding
