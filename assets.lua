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

    -- Load music
    self.music = love.audio.newSource('assets/music/space-marine-theme.ogg', 'stream')
    self.music:setLooping(true)
    love.audio.play(self.music)

    -- Load floor tile
    self.floorTile = love.graphics.newImage('assets/textures/floortile192x192.png')
end

function Assets:playMusic()
    if self.music then
        love.audio.play(self.music)
    end
end

function Assets:stopMusic()
    if self.music then
        love.audio.stop(self.music)
    end
end

return Assets
