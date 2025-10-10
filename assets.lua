-- Asset manager module
local Assets = {}

function Assets:new()
    local assets = {
        soldierWalkingImages = {},
        soldierShootingImages = {},
        zombieWalkingImages = {},
        zombieAttackingImages = {},
        floorTile = nil,
        music = nil
    }
    setmetatable(assets, { __index = self })
    return assets
end

function Assets:load()
    -- Load frame images
    for i = 0, 16 do
        local frameName = string.format("assets/textures/soldier-walking/frame_%03d.png", i)
        table.insert(self.soldierWalkingImages, love.graphics.newImage(frameName))
    end
    for i = 0, 16 do
        local frameName = string.format("assets/textures/soldier-shooting/frame_%03d.png", i)
        table.insert(self.soldierShootingImages, love.graphics.newImage(frameName))
    end
    for i = 0, 10 do
        local frameName = string.format("assets/textures/zombie-walking/frame_%03d.png", i)
        table.insert(self.zombieWalkingImages, love.graphics.newImage(frameName))
    end
    for i = 0, 16 do
        local frameName = string.format("assets/textures/zombie-attacking/frame_%03d.png", i)
        table.insert(self.zombieAttackingImages, love.graphics.newImage(frameName))
    end

    -- Load floor tile
    self.floorTile = love.graphics.newImage('assets/textures/floortile192x192.png')
end

-- Note: Music functionality has been moved to the SoundManager module
-- These methods are kept for backward compatibility but now do nothing
function Assets:playMusic()
    -- Music is now handled by the SoundManager
end

function Assets:stopMusic()
    -- Music is now handled by the SoundManager
end

return Assets
