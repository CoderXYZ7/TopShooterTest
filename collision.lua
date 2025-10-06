-- Collision system module
local Collision = {}

function Collision:new()
    local collision = {}
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
    if player.x + player.width > screenW then
        player.x = screenW - player.width
        player.vx = 0
    end

    -- Top boundary
    if player.y < 0 then
        player.y = 0
        player.vy = 0
    end

    -- Bottom boundary
    if player.y + player.height > screenH then
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

function Collision:update(player, enemies)
    -- World boundary collision (truly solid walls)
    self:resolvePlayerBoundaries(player)
    self:resolveEnemiesBoundaries(enemies)

    -- Entity collisions
    if #enemies > 0 then
        self:resolvePlayerEnemies(player, enemies)
        self:resolveEnemiesEnemies(enemies)
    end
end

return Collision
