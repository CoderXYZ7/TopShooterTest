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

function Collision:update(player, enemies)
    if #enemies > 0 then
        self:resolvePlayerEnemies(player, enemies)
        self:resolveEnemiesEnemies(enemies)
    end
end

return Collision
