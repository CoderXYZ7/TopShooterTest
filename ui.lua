-- Enhanced UI module
local UI = {}

function UI:new()
    local ui = {
        score = 0,
        health = 100,
        maxHealth = 100,
        wave = 1,
        enemiesRemaining = 0,
        timeSurvived = 0,
        highScore = 0,
        showTutorial = true,
        tutorialTime = 0,
        gameOver = false,
        victory = false
    }
    setmetatable(ui, { __index = self })
    return ui
end

function UI:draw(player, debug, walkingFrameTime, walkingFrameDuration, soldierWalkingImages)
    -- Draw main UI panel
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', 0, 0, 300, 120)
    love.graphics.setColor(1, 1, 1)
    
    -- Health bar
    local healthPercent = player.health / player.maxHealth
    love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
    love.graphics.rectangle('fill', 10, 10, 200, 20)
    love.graphics.setColor(1 - healthPercent, healthPercent, 0, 1)
    love.graphics.rectangle('fill', 10, 10, 200 * healthPercent, 20)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Health: " .. math.ceil(player.health) .. "/" .. player.maxHealth, 15, 12)
    
    -- Ammo display with weapon system and inventory - showing [Loaded]/[Inventory] format
    local currentAmmo, maxAmmo, weaponName, inventoryAmmo, ammoType = player:getWeaponInfo()
    love.graphics.print("Ammo: " .. currentAmmo .. "/" .. inventoryAmmo, 10, 40)
    love.graphics.print("Weapon: " .. weaponName, 10, 55)
    love.graphics.print("Ammo Type: " .. ammoType, 10, 70)
    love.graphics.print("Magazine: " .. currentAmmo .. "/" .. maxAmmo, 10, 85)
    
    if player:isReloading() then
        local reloadPercent = player:getReloadProgress()
        love.graphics.setColor(1, 0.8, 0, 0.8)
        love.graphics.rectangle('fill', 80, 95, 100 * reloadPercent, 5)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("RELOADING", 10, 100)
    end
    
    -- Score and wave
    love.graphics.print("Score: " .. self.score, 150, 40)
    love.graphics.print("Wave: " .. self.wave, 150, 55)
    love.graphics.print("Enemies: " .. self.enemiesRemaining, 150, 70)
    
    -- Time survived
    local minutes = math.floor(self.timeSurvived / 60)
    local seconds = math.floor(self.timeSurvived % 60)
    love.graphics.print(string.format("Time: %02d:%02d", minutes, seconds), 150, 70)
    
    -- High score
    if self.highScore > 0 then
        love.graphics.print("High Score: " .. self.highScore, 150, 85)
    end
    
    -- Dash cooldown indicator
    if player.dashCooldown > 0 then
        love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
        love.graphics.rectangle('fill', 220, 10, 70, 15)
        love.graphics.setColor(1, 0.5, 0, 1)
        love.graphics.rectangle('fill', 220, 10, 70 * (1 - player.dashCooldown/1.5), 15)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("DASH", 225, 12)
    else
        love.graphics.setColor(0.2, 0.8, 0.2, 1)
        love.graphics.print("DASH READY", 225, 12)
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Debug information
    if debug then
        local walkingFrame = math.floor(walkingFrameTime / walkingFrameDuration) % #soldierWalkingImages + 1
        love.graphics.print("walkingFrame: " .. walkingFrame, 310, 10)
        love.graphics.print("FPS: " .. love.timer.getFPS(), 310, 25)
        love.graphics.print("Player: " .. math.floor(player.x) .. ", " .. math.floor(player.y), 310, 40)
    end
    
    -- Tutorial messages
    if self.showTutorial and self.tutorialTime < 10 then
        self.tutorialTime = self.tutorialTime + love.timer.getDelta()
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print("WASD: Move", 500, 10)
        love.graphics.print("Mouse: Aim and Shoot", 500, 25)
        love.graphics.print("R: Reload", 500, 40)
        love.graphics.print("SPACE: Dash", 500, 55)
        love.graphics.setColor(1, 1, 1)
        
        if self.tutorialTime > 5 then
            love.graphics.setColor(1, 1, 1, 0.6)
            love.graphics.print("Survive as long as possible!", 500, 80)
            love.graphics.setColor(1, 1, 1)
        end
    end
    
    -- Game over screen
    if self.gameOver then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1, 0.2, 0.2, 1)
        love.graphics.print("GAME OVER", love.graphics.getWidth()/2 - 100, love.graphics.getHeight()/2 - 50, 0, 2, 2)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Final Score: " .. self.score, love.graphics.getWidth()/2 - 80, love.graphics.getHeight()/2)
        love.graphics.print("Time Survived: " .. string.format("%02d:%02d", minutes, seconds), love.graphics.getWidth()/2 - 80, love.graphics.getHeight()/2 + 30)
        love.graphics.print("Press R to restart", love.graphics.getWidth()/2 - 80, love.graphics.getHeight()/2 + 60)
    end
    
    -- Victory screen
    if self.victory then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(0.2, 1, 0.2, 1)
        love.graphics.print("VICTORY!", love.graphics.getWidth()/2 - 80, love.graphics.getHeight()/2 - 50, 0, 2, 2)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Final Score: " .. self.score, love.graphics.getWidth()/2 - 80, love.graphics.getHeight()/2)
        love.graphics.print("Time: " .. string.format("%02d:%02d", minutes, seconds), love.graphics.getWidth()/2 - 80, love.graphics.getHeight()/2 + 30)
        love.graphics.print("Press R to play again", love.graphics.getWidth()/2 - 80, love.graphics.getHeight()/2 + 60)
    end
end

function UI:addScore(points)
    self.score = self.score + points
    if self.score > self.highScore then
        self.highScore = self.score
    end
end

function UI:setHealth(newHealth)
    self.health = newHealth
end

function UI:updateTime(dt)
    if not self.gameOver and not self.victory then
        self.timeSurvived = self.timeSurvived + dt
    end
end

function UI:setWave(wave)
    self.wave = wave
end

function UI:setEnemiesRemaining(count)
    self.enemiesRemaining = count
end

function UI:gameOverScreen()
    self.gameOver = true
end

function UI:victoryScreen()
    self.victory = true
end

function UI:reset()
    self.score = 0
    self.health = 100
    self.wave = 1
    self.enemiesRemaining = 0
    self.timeSurvived = 0
    self.gameOver = false
    self.victory = false
    self.showTutorial = true
    self.tutorialTime = 0
end

function UI:getScore()
    return self.score
end

function UI:getHealth()
    return self.health
end

function UI:isGameOver()
    return self.gameOver
end

function UI:isVictory()
    return self.victory
end

return UI
