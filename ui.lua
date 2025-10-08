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
        selectedInventoryWeapon = 1,
        shopScrollOffset = 0,
        visibleShopItems = 6  -- Number of items visible in shop at once
    }
    setmetatable(ui, { __index = self })
    return ui
end

function UI:draw(player, debug, walkingFrameTime, walkingFrameDuration, soldierWalkingImages, gameManager)
    -- Draw main UI panel - much smaller and cleaner
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', 0, 0, 250, 80)
    love.graphics.setColor(1, 1, 1)
    
    -- Health bar (top left)
    local healthPercent = player.health / player.maxHealth
    love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
    love.graphics.rectangle('fill', 10, 10, 120, 15)
    love.graphics.setColor(1 - healthPercent, healthPercent, 0, 1)
    love.graphics.rectangle('fill', 10, 10, 120 * healthPercent, 15)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(math.ceil(player.health) .. "/" .. player.maxHealth, 15, 12)
    
    -- Consolidated weapon info (top right)
    local currentAmmo, maxAmmo, weaponName, inventoryAmmo, ammoType = player:getWeaponInfo()
    love.graphics.print(weaponName .. ": " .. currentAmmo .. "/" .. inventoryAmmo, 140, 12)
    
    -- Game stats (bottom row)
    love.graphics.print("Wave: " .. self.wave, 10, 35)
    love.graphics.print("$" .. player:getMoney(), 80, 35)
    love.graphics.print("Score: " .. self.score, 140, 35)
    
    -- Enemies remaining and time (second bottom row)
    love.graphics.print("Enemies: " .. self.enemiesRemaining, 10, 50)
    local minutes = math.floor(self.timeSurvived / 60)
    local seconds = math.floor(self.timeSurvived % 60)
    love.graphics.print(string.format("Time: %02d:%02d", minutes, seconds), 140, 50)
    
    -- Dash cooldown indicator (small and clean)
    if player.dashCooldown > 0 then
        love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
        love.graphics.rectangle('fill', 10, 65, 60, 10)
        love.graphics.setColor(1, 0.5, 0, 1)
        love.graphics.rectangle('fill', 10, 65, 60 * (1 - player.dashCooldown/1.5), 10)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("DASH", 15, 66)
    else
        love.graphics.setColor(0.2, 0.8, 0.2, 1)
        love.graphics.print("DASH", 15, 66)
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Reload indicator (when reloading)
    if player:isReloading() then
        local reloadPercent = player:getReloadProgress()
        love.graphics.setColor(1, 0.8, 0, 0.8)
        love.graphics.rectangle('fill', 80, 65, 60 * reloadPercent, 10)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("RELOAD", 85, 66)
    end
    
    -- Draw inventory slots
    self:drawInventory(player)
    
    -- Debug information (moved to bottom right to avoid clutter)
    if debug then
        local walkingFrame = math.floor(walkingFrameTime / walkingFrameDuration) % #soldierWalkingImages + 1
        love.graphics.print("FPS: " .. love.timer.getFPS(), love.graphics.getWidth() - 100, 10)
        love.graphics.print("Frame: " .. walkingFrame, love.graphics.getWidth() - 100, 25)
        love.graphics.print("Pos: " .. math.floor(player.x) .. "," .. math.floor(player.y), love.graphics.getWidth() - 100, 40)
    end
    
    -- Tutorial messages (simplified and less intrusive)
    if self.showTutorial and self.tutorialTime < 10 then
        self.tutorialTime = self.tutorialTime + love.timer.getDelta()
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print("WASD: Move | Mouse: Aim/Shoot | R: Reload | SPACE: Dash", 400, 10)
        love.graphics.setColor(1, 1, 1)
        
        if self.tutorialTime > 5 then
            love.graphics.setColor(1, 1, 1, 0.6)
            love.graphics.print("Survive as long as possible!", 400, 30)
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
    self.shopScrollOffset = 0
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

-- Shop display methods with scrolling
function UI:drawShop(gameManager, player)
    if not gameManager:isShopOpen() then
        return
    end
    
    local shop = gameManager:getShop()
    local timeLeft = gameManager:getShopTimeLeft()
    local items = shop:getAvailableItems()
    
    -- Calculate scroll bounds
    local maxScroll = math.max(0, #items - self.visibleShopItems) * 60
    
    -- Draw shop background
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle('fill', 100, 100, love.graphics.getWidth() - 200, love.graphics.getHeight() - 200)
    
    -- Draw shop header (compact)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("SHOP - Wave " .. self.wave .. " | $" .. player:getMoney() .. " | " .. math.ceil(timeLeft) .. "s", 
                       love.graphics.getWidth()/2 - 150, 120)
    
    -- Draw category tabs
    local categories = {"WEAPONS", "AMMO", "HEALTH", "UPGRADES"}
    local tabWidth = 120
    for i, category in ipairs(categories) do
        local x = 150 + (i - 1) * tabWidth
        if shop.selectedCategory == category then
            love.graphics.setColor(0.2, 0.4, 0.8, 0.9)
        else
            love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
        end
        love.graphics.rectangle('fill', x, 150, tabWidth - 5, 25)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(category, x + 10, 155)
    end
    
    -- Draw visible items with scrolling
    local startIndex = math.floor(self.shopScrollOffset / 60) + 1
    local endIndex = math.min(#items, startIndex + self.visibleShopItems - 1)
    
    for i = startIndex, endIndex do
        local item = items[i]
        local y = 200 + (i - startIndex) * 60 - (self.shopScrollOffset % 60)
        
        -- Skip items that are scrolled out of view
        if y < 200 or y > 200 + (self.visibleShopItems * 60) then
            goto continue
        end
        
        -- Calculate actual cost and level for upgrades
        local actualCost = item.cost
        local currentLevel = 0
        local maxLevel = item.maxLevel or 0
        
        if item.type == "upgrade" then
            actualCost = shop:getUpgradeCost(item.upgradeType, player)
            currentLevel = shop:getUpgradeLevel(item.upgradeType, player)
        end
        
        -- Draw item background
        if shop.selectedItem == i then
            love.graphics.setColor(0.2, 0.4, 0.8, 0.8)  -- Highlight selected item
        else
            love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        end
        love.graphics.rectangle('fill', 150, y, love.graphics.getWidth() - 300, 50)
        
        -- Draw item info (compact)
        love.graphics.setColor(1, 1, 1)
        
        if item.type == "upgrade" then
            -- Show upgrade with level info
            love.graphics.print(item.name .. " Lvl " .. currentLevel .. "/" .. maxLevel, 160, y + 5)
            love.graphics.print(item.description, 160, y + 20)
        else
            -- Show regular items
            love.graphics.print(item.name, 160, y + 5)
            love.graphics.print(item.description, 160, y + 20)
        end
        
        -- Draw cost and purchase button
        love.graphics.print("$" .. actualCost, love.graphics.getWidth() - 200, y + 15)
        
        -- Draw purchase button
        if item.type == "upgrade" and currentLevel >= maxLevel then
            -- Max level reached
            love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
            love.graphics.rectangle('fill', love.graphics.getWidth() - 120, y + 10, 100, 30)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("MAX", love.graphics.getWidth() - 100, y + 18)
        else
            love.graphics.setColor(0.2, 0.8, 0.2, 0.8)
            love.graphics.rectangle('fill', love.graphics.getWidth() - 120, y + 10, 100, 30)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("BUY", love.graphics.getWidth() - 100, y + 18)
        end
        
        ::continue::
    end
    
    -- Draw scroll indicators if needed
    if #items > self.visibleShopItems then
        -- Scroll bar
        local scrollBarHeight = 200
        local scrollBarWidth = 10
        local scrollBarX = love.graphics.getWidth() - 120
        local scrollBarY = 200
        
        love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
        love.graphics.rectangle('fill', scrollBarX, scrollBarY, scrollBarWidth, scrollBarHeight)
        
        local scrollThumbHeight = scrollBarHeight * (self.visibleShopItems / #items)
        local scrollThumbY = scrollBarY + (self.shopScrollOffset / maxScroll) * (scrollBarHeight - scrollThumbHeight)
        
        love.graphics.setColor(0.6, 0.6, 0.8, 0.9)
        love.graphics.rectangle('fill', scrollBarX, scrollThumbY, scrollBarWidth, scrollThumbHeight)
        
        -- Scroll instructions
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.print("PG UP/DN: Scroll", scrollBarX - 100, scrollBarY + scrollBarHeight + 10)
    end
    
    -- Draw shop message
    if self.shopMessage ~= "" then
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print(self.shopMessage, love.graphics.getWidth()/2 - 100, love.graphics.getHeight() - 150)
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Draw instructions (compact)
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.print("ENTER: Buy | ARROWS: Navigate | TAB: Categories | ESC: Continue", 
                       love.graphics.getWidth()/2 - 200, love.graphics.getHeight() - 100)
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
