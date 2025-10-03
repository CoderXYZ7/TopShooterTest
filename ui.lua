-- Enhanced UI module with inventory and shop display
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
        victory = false,
        money = 0,
        shopMessage = "",
        shopMessageTimer = 0,
        loadoutMode = false,
        selectedLoadoutSlot = 1,
        selectedInventoryWeapon = 1
    }
    setmetatable(ui, { __index = self })
    return ui
end

function UI:draw(player, debug, walkingFrameTime, walkingFrameDuration, soldierWalkingImages, gameManager)
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
    
    -- Money display
    love.graphics.print("Money: $" .. player:getMoney(), 150, 85)
    
    -- High score
    if self.highScore > 0 then
        love.graphics.print("High Score: " .. self.highScore, 150, 100)
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
    
    -- Draw inventory slots
    self:drawInventory(player)
    
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

-- Inventory display methods
function UI:drawInventory(player)
    local slots = player:getWeaponSlots()
    local currentSlot = player:getCurrentWeaponSlot()
    
    -- Draw inventory panel
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', 0, love.graphics.getHeight() - 80, 300, 80)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("INVENTORY", 10, love.graphics.getHeight() - 75)
    
    -- Draw weapon slots
    for slot = 1, 3 do
        local weapon = slots[slot]
        local x = 10 + (slot - 1) * 90
        local y = love.graphics.getHeight() - 55
        
        -- Draw slot background
        if slot == currentSlot then
            love.graphics.setColor(0.2, 0.6, 1, 0.8)  -- Highlight current slot
        else
            love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
        end
        love.graphics.rectangle('fill', x, y, 80, 40)
        
        -- Draw weapon info
        love.graphics.setColor(1, 1, 1)
        if weapon then
            love.graphics.print(weapon:getWeaponName(), x + 5, y + 5)
            local ammo, maxAmmo = weapon:getAmmoInfo()
            love.graphics.print("Ammo: " .. ammo .. "/" .. maxAmmo, x + 5, y + 20)
        else
            love.graphics.print("Empty", x + 25, y + 15)
        end
        
        -- Draw slot number
        love.graphics.print(slot, x + 35, y - 15)
    end
end

-- Shop display methods
function UI:drawShop(gameManager, player)
    if not gameManager:isShopOpen() then
        return
    end
    
    local shop = gameManager:getShop()
    local timeLeft = gameManager:getShopTimeLeft()
    
    -- Draw shop background
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle('fill', 100, 100, love.graphics.getWidth() - 200, love.graphics.getHeight() - 200)
    
    -- Draw shop header
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("WEAPONS SHOP - Wave " .. self.wave, love.graphics.getWidth()/2 - 100, 120)
    love.graphics.print("Time left: " .. math.ceil(timeLeft) .. "s", love.graphics.getWidth()/2 - 50, 140)
    love.graphics.print("Money: $" .. player:getMoney(), love.graphics.getWidth()/2 - 50, 160)
    
    -- Draw available items
    local items = shop:getAvailableItems()
    for i, item in ipairs(items) do
        local y = 200 + (i - 1) * 60
        
        -- Draw item background
        if shop.selectedItem == i then
            love.graphics.setColor(0.2, 0.4, 0.8, 0.8)  -- Highlight selected item
        else
            love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        end
        love.graphics.rectangle('fill', 150, y, love.graphics.getWidth() - 300, 50)
        
        -- Draw item info
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(item.name, 160, y + 5)
        love.graphics.print(item.description, 160, y + 20)
        love.graphics.print("$" .. item.cost, love.graphics.getWidth() - 200, y + 15)
        
        -- Draw purchase button
        love.graphics.setColor(0.2, 0.8, 0.2, 0.8)
        love.graphics.rectangle('fill', love.graphics.getWidth() - 120, y + 10, 100, 30)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("BUY", love.graphics.getWidth() - 100, y + 18)
    end
    
    -- Draw shop message
    if self.shopMessage ~= "" then
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print(self.shopMessage, love.graphics.getWidth()/2 - 100, love.graphics.getHeight() - 150)
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Draw instructions
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.print("Press ENTER to continue to next wave", love.graphics.getWidth()/2 - 150, love.graphics.getHeight() - 100)
    love.graphics.setColor(1, 1, 1)
end

function UI:setShopMessage(message)
    self.shopMessage = message
    self.shopMessageTimer = 3.0  -- Show message for 3 seconds
end

function UI:updateShopMessage(dt)
    if self.shopMessageTimer > 0 then
        self.shopMessageTimer = self.shopMessageTimer - dt
        if self.shopMessageTimer <= 0 then
            self.shopMessage = ""
        end
    end
end

-- Loadout management methods
function UI:drawLoadoutManager(player)
    if not self.loadoutMode then
        return
    end
    
    -- Draw loadout background
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle('fill', 100, 100, love.graphics.getWidth() - 200, love.graphics.getHeight() - 200)
    
    -- Draw header
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("LOADOUT MANAGEMENT", love.graphics.getWidth()/2 - 100, 120)
    love.graphics.print("Press TAB to exit loadout mode", love.graphics.getWidth()/2 - 120, 150)
    
    -- Draw equipped weapon slots
    love.graphics.print("EQUIPPED WEAPONS", 150, 200)
    local slots = player:getWeaponSlots()
    
    for slot = 1, 3 do
        local weapon = slots[slot]
        local x = 150 + (slot - 1) * 200
        local y = 230
        
        -- Draw slot background
        if slot == self.selectedLoadoutSlot then
            love.graphics.setColor(0.2, 0.6, 1, 0.8)  -- Highlight selected slot
        else
            love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
        end
        love.graphics.rectangle('fill', x, y, 180, 80)
        
        -- Draw weapon info
        love.graphics.setColor(1, 1, 1)
        if weapon then
            love.graphics.print("Slot " .. slot, x + 10, y + 5)
            love.graphics.print(weapon:getWeaponName(), x + 10, y + 25)
            local ammo, maxAmmo = weapon:getAmmoInfo()
            love.graphics.print("Ammo: " .. ammo .. "/" .. maxAmmo, x + 10, y + 45)
        else
            love.graphics.print("Slot " .. slot, x + 10, y + 5)
            love.graphics.print("Empty", x + 70, y + 40)
        end
    end
    
    -- Draw unequipped weapons
    local unequipped = player:getUnequippedWeapons()
    love.graphics.print("UNEQUIPPED WEAPONS", 150, 350)
    
    if #unequipped > 0 then
        for i, weapon in ipairs(unequipped) do
            local x = 150 + ((i - 1) % 3) * 200
            local y = 380 + math.floor((i - 1) / 3) * 80
            
            -- Draw weapon background
            if i == self.selectedInventoryWeapon then
                love.graphics.setColor(0.2, 0.8, 0.2, 0.8)  -- Highlight selected inventory weapon
            else
                love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
            end
            love.graphics.rectangle('fill', x, y, 180, 60)
            
            -- Draw weapon info
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(weapon:getWeaponName(), x + 10, y + 5)
            local ammo, maxAmmo = weapon:getAmmoInfo()
            love.graphics.print("Ammo: " .. ammo .. "/" .. maxAmmo, x + 10, y + 25)
        end
    else
        love.graphics.print("No unequipped weapons", 150, 380)
    end
    
    -- Draw instructions
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.print("ARROW KEYS: Navigate", 150, love.graphics.getHeight() - 150)
    love.graphics.print("ENTER: Swap selected slot with selected inventory weapon", 150, love.graphics.getHeight() - 130)
    love.graphics.print("S: Swap weapon slots (when both slots selected)", 150, love.graphics.getHeight() - 110)
    love.graphics.setColor(1, 1, 1)
end

function UI:toggleLoadoutMode()
    self.loadoutMode = not self.loadoutMode
    if self.loadoutMode then
        self.selectedLoadoutSlot = 1
        self.selectedInventoryWeapon = 1
    end
end

function UI:isLoadoutMode()
    return self.loadoutMode
end

function UI:handleLoadoutInput(key, player)
    if not self.loadoutMode then
        return false
    end
    
    local unequipped = player:getUnequippedWeapons()
    
    if key == 'up' then
        if self.selectedLoadoutSlot > 1 then
            self.selectedLoadoutSlot = self.selectedLoadoutSlot - 1
        end
        return true
    elseif key == 'down' then
        if self.selectedLoadoutSlot < 3 then
            self.selectedLoadoutSlot = self.selectedLoadoutSlot + 1
        end
        return true
    elseif key == 'left' then
        if self.selectedInventoryWeapon > 1 then
            self.selectedInventoryWeapon = self.selectedInventoryWeapon - 1
        end
        return true
    elseif key == 'right' then
        if self.selectedInventoryWeapon < #unequipped then
            self.selectedInventoryWeapon = self.selectedInventoryWeapon + 1
        end
        return true
    elseif key == 'return' then
        -- Swap selected slot with selected inventory weapon
        if #unequipped > 0 then
            player:swapWeaponWithInventory(self.selectedLoadoutSlot, self.selectedInventoryWeapon)
        end
        return true
    elseif key == 's' then
        -- Swap weapon slots
        local targetSlot = (self.selectedLoadoutSlot % 3) + 1
        player:moveWeapon(self.selectedLoadoutSlot, targetSlot)
        self.selectedLoadoutSlot = targetSlot
        return true
    end
    
    return false
end

return UI
