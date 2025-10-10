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
        shopScrollOffset = 0,
        visibleShopItems = 6,  -- Number of items visible in shop at once
        -- New loadout manager state
        loadoutSelector = {
            panel = "loadout",  -- "loadout" or "inventory"
            index = 1,          -- Current selection index
            heldWeapon = nil    -- Currently held weapon
        }
    }
    setmetatable(ui, { __index = self })
    return ui
end

function UI:draw(player, debug, walkingFrameTime, walkingFrameDuration, soldierWalkingImages, gameManager)
    -- Only draw game UI when playing
    if gameManager:getState() == "PLAYING" then
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
    self.loadoutSelector = {
        panel = "loadout",
        index = 1,
        heldWeapon = nil
    }
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

-- Loadout management methods - Dual Panel System
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
    
    -- Calculate panel dimensions
    local panelWidth = (love.graphics.getWidth() - 300) / 2
    local panelHeight = love.graphics.getHeight() - 300
    
    -- Draw left panel (Loadout - Equipped Weapons)
    love.graphics.setColor(0.2, 0.2, 0.3, 0.8)
    love.graphics.rectangle('fill', 150, 200, panelWidth, panelHeight)
    love.graphics.setColor(0.4, 0.4, 0.8, 1)
    love.graphics.rectangle('line', 150, 200, panelWidth, panelHeight)
    
    -- Draw right panel (Inventory - Unequipped Weapons)
    love.graphics.setColor(0.2, 0.3, 0.2, 0.8)
    love.graphics.rectangle('fill', 150 + panelWidth + 20, 200, panelWidth, panelHeight)
    love.graphics.setColor(0.4, 0.8, 0.4, 1)
    love.graphics.rectangle('line', 150 + panelWidth + 20, 200, panelWidth, panelHeight)
    
    -- Draw panel titles
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("LOADOUT (EQUIPPED)", 150 + panelWidth/2 - 80, 180)
    love.graphics.print("INVENTORY (UNEQUIPPED)", 150 + panelWidth + 20 + panelWidth/2 - 100, 180)
    
    -- Draw equipped weapons (left panel)
    local slots = player:getWeaponSlots()
    local slotHeight = panelHeight / 3
    
    for slot = 1, 3 do
        local weapon = slots[slot]
        local y = 200 + (slot - 1) * slotHeight
        
        -- Draw slot background with highlight if selected
        if self.loadoutSelector.panel == "loadout" and self.loadoutSelector.index == slot then
            love.graphics.setColor(0.3, 0.5, 1, 0.6)  -- Highlight selected slot
        else
            love.graphics.setColor(0.3, 0.3, 0.4, 0.6)
        end
        love.graphics.rectangle('fill', 160, y + 10, panelWidth - 20, slotHeight - 20)
        
        -- Draw weapon info
        love.graphics.setColor(1, 1, 1)
        if weapon then
            love.graphics.print("SLOT " .. slot, 170, y + 20)
            love.graphics.print(weapon:getWeaponName(), 170, y + 40)
            local ammo, maxAmmo = weapon:getAmmoInfo()
            love.graphics.print("Ammo: " .. ammo .. "/" .. maxAmmo, 170, y + 60)
            
            -- Show ammo type
            local ammoType = weapon.ammoType
            love.graphics.print("Type: " .. ammoType, 170, y + 80)
        else
            love.graphics.print("SLOT " .. slot, 170, y + 20)
            love.graphics.print("EMPTY", 170, y + 50)
        end
    end
    
    -- Draw unequipped weapons (right panel)
    local unequipped = player:getUnequippedWeapons()
    local itemHeight = 80
    
    for i, weapon in ipairs(unequipped) do
        local y = 200 + (i - 1) * itemHeight
        
        -- Skip if outside panel
        if y + itemHeight > 200 + panelHeight then
            break
        end
        
        -- Draw weapon background with highlight if selected
        if self.loadoutSelector.panel == "inventory" and self.loadoutSelector.index == i then
            love.graphics.setColor(0.3, 0.8, 0.3, 0.6)  -- Highlight selected inventory item
        else
            love.graphics.setColor(0.3, 0.4, 0.3, 0.6)
        end
        love.graphics.rectangle('fill', 150 + panelWidth + 30, y + 10, panelWidth - 40, itemHeight - 20)
        
        -- Draw weapon info
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(weapon:getWeaponName(), 150 + panelWidth + 40, y + 20)
        local ammo, maxAmmo = weapon:getAmmoInfo()
        love.graphics.print("Ammo: " .. ammo .. "/" .. maxAmmo, 150 + panelWidth + 40, y + 40)
        
        -- Show ammo type
        local ammoType = weapon.ammoType
        love.graphics.print("Type: " .. ammoType, 150 + panelWidth + 40, y + 60)
    end
    
    -- Draw "No weapons" message if inventory is empty
    if #unequipped == 0 then
        love.graphics.print("No weapons in inventory", 150 + panelWidth + 20 + panelWidth/2 - 80, 200 + panelHeight/2)
    end
    
    -- Draw held weapon indicator
    if self.loadoutSelector.heldWeapon then
        local weapon = self.loadoutSelector.heldWeapon
        love.graphics.setColor(1, 1, 0, 0.8)
        love.graphics.print("HOLDING: " .. weapon:getWeaponName(), love.graphics.getWidth()/2 - 100, love.graphics.getHeight() - 180)
        love.graphics.setColor(1, 1, 1)
    end
    
    -- Draw instructions
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("ARROW KEYS: Move selector", 150, love.graphics.getHeight() - 150)
    love.graphics.print("SPACE: Pick up/drop weapon", 150, love.graphics.getHeight() - 130)
    love.graphics.print("Hold a weapon and move to transfer between panels", 150, love.graphics.getHeight() - 110)
    love.graphics.setColor(1, 1, 1)
end

function UI:toggleLoadoutMode()
    self.loadoutMode = not self.loadoutMode
    if self.loadoutMode then
        -- Reset selector state
        self.loadoutSelector = {
            panel = "loadout",
            index = 1,
            heldWeapon = nil
        }
    end
end

function UI:isLoadoutMode()
    return self.loadoutMode
end

function UI:handleLoadoutInput(key, player)
    if not self.loadoutMode then
        return false
    end
    
    local slots = player:getWeaponSlots()
    local unequipped = player:getUnequippedWeapons()
    
    if key == 'up' then
        -- Move selector up
        if self.loadoutSelector.panel == "loadout" then
            if self.loadoutSelector.index > 1 then
                self.loadoutSelector.index = self.loadoutSelector.index - 1
            end
        else
            if self.loadoutSelector.index > 1 then
                self.loadoutSelector.index = self.loadoutSelector.index - 1
            end
        end
        return true
        
    elseif key == 'down' then
        -- Move selector down
        if self.loadoutSelector.panel == "loadout" then
            if self.loadoutSelector.index < 3 then
                self.loadoutSelector.index = self.loadoutSelector.index + 1
            end
        else
            if self.loadoutSelector.index < #unequipped then
                self.loadoutSelector.index = self.loadoutSelector.index + 1
            end
        end
        return true
        
    elseif key == 'left' or key == 'right' then
        -- Switch between panels
        if self.loadoutSelector.panel == "loadout" then
            self.loadoutSelector.panel = "inventory"
            self.loadoutSelector.index = math.min(self.loadoutSelector.index, math.max(1, #unequipped))
        else
            self.loadoutSelector.panel = "loadout"
            self.loadoutSelector.index = math.min(self.loadoutSelector.index, 3)
        end
        return true
        
    elseif key == 'space' then
        -- Pick up or drop weapon
        if self.loadoutSelector.heldWeapon then
            -- Drop the held weapon
            if self.loadoutSelector.panel == "loadout" then
                -- Drop into loadout slot
                local targetSlot = self.loadoutSelector.index
                local currentWeapon = slots[targetSlot]
                
                if currentWeapon then
                    -- Swap weapons
                    player:addWeaponToInventory(self.loadoutSelector.heldWeapon)
                    player:equipWeapon(targetSlot, currentWeapon)
                else
                    -- Just equip the held weapon
                    player:equipWeapon(targetSlot, self.loadoutSelector.heldWeapon)
                end
            else
                -- Drop into inventory
                player:addWeaponToInventory(self.loadoutSelector.heldWeapon)
            end
            
            self.loadoutSelector.heldWeapon = nil
            
        else
            -- Pick up weapon from current selection
            if self.loadoutSelector.panel == "loadout" then
                local weapon = slots[self.loadoutSelector.index]
                if weapon then
                    self.loadoutSelector.heldWeapon = weapon
                    player:unequipWeapon(self.loadoutSelector.index)
                end
            else
                local weapon = unequipped[self.loadoutSelector.index]
                if weapon then
                    self.loadoutSelector.heldWeapon = weapon
                    player:removeWeaponFromInventory(self.loadoutSelector.index)
                end
            end
        end
        return true
    end
    
    return false
end

-- Menu system methods
function UI:drawStartMenu(gameManager)
    local ww, wh = love.graphics.getDimensions()
    
    -- Draw background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle('fill', 0, 0, ww, wh)
    
    -- Draw title
    love.graphics.setColor(0.8, 0.2, 0.2, 1)
    love.graphics.print("TOP SHOOTER", ww/2 - 150, wh/2 - 150, 0, 3, 3)
    
    -- Draw menu options
    local options = {"Start Game", "Settings", "Quit"}
    local optionY = wh/2 - 50
    
    for i, option in ipairs(options) do
        if i == gameManager.menuSelection then
            love.graphics.setColor(0.2, 0.6, 1, 1)  -- Highlight selected
        else
            love.graphics.setColor(1, 1, 1, 0.8)
        end
        
        love.graphics.print(option, ww/2 - 50, optionY + (i-1)*40, 0, 1.5, 1.5)
    end
    
    -- Draw instructions
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.print("Use ARROW KEYS to navigate, ENTER to select", ww/2 - 180, wh - 100)
    love.graphics.setColor(1, 1, 1, 1)
end

function UI:drawPauseMenu(gameManager)
    local ww, wh = love.graphics.getDimensions()
    
    -- Draw semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle('fill', 0, 0, ww, wh)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("PAUSED", ww/2 - 80, wh/2 - 150, 0, 3, 3)
    
    -- Draw menu options
    local options = {"Resume", "Settings", "Main Menu"}
    local optionY = wh/2 - 50
    
    for i, option in ipairs(options) do
        if i == gameManager.menuSelection then
            love.graphics.setColor(0.2, 0.6, 1, 1)  -- Highlight selected
        else
            love.graphics.setColor(1, 1, 1, 0.8)
        end
        
        love.graphics.print(option, ww/2 - 50, optionY + (i-1)*40, 0, 1.5, 1.5)
    end
    
    -- Draw instructions
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.print("Press ESC to resume", ww/2 - 80, wh - 100)
    love.graphics.setColor(1, 1, 1, 1)
end

function UI:drawSettingsMenu(gameManager)
    local ww, wh = love.graphics.getDimensions()
    
    -- Draw background
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle('fill', 0, 0, ww, wh)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("SETTINGS", ww/2 - 80, 100, 0, 2, 2)
    
    -- Draw settings options
    local settings = {
        {name = "Music Volume", value = gameManager.musicVolume, type = "slider"},
        {name = "Sound Volume", value = gameManager.soundVolume, type = "slider"},
        {name = "Show Tutorial", value = gameManager.showTutorial, type = "toggle"},
        {name = "Debug Mode", value = gameManager.debugMode, type = "toggle"},
        {name = "Back", value = nil, type = "back"}
    }
    
    local optionY = 200
    
    for i, setting in ipairs(settings) do
        -- Highlight selected option
        if i == gameManager.settingsSelection then
            love.graphics.setColor(0.2, 0.6, 1, 1)
        else
            love.graphics.setColor(1, 1, 1, 0.8)
        end
        
        -- Draw setting name
        love.graphics.print(setting.name, 200, optionY + (i-1)*50)
        
        -- Draw setting value based on type
        if setting.type == "slider" then
            -- Draw slider background
            love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
            love.graphics.rectangle('fill', 400, optionY + (i-1)*50 + 5, 200, 20)
            
            -- Draw slider fill
            love.graphics.setColor(0.2, 0.8, 0.2, 0.8)
            love.graphics.rectangle('fill', 400, optionY + (i-1)*50 + 5, 200 * setting.value, 20)
            
            -- Draw slider text
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(string.format("%d%%", math.floor(setting.value * 100)), 610, optionY + (i-1)*50)
            
        elseif setting.type == "toggle" then
            if setting.value then
                love.graphics.setColor(0.2, 0.8, 0.2, 1)
                love.graphics.print("ON", 400, optionY + (i-1)*50)
            else
                love.graphics.setColor(0.8, 0.2, 0.2, 1)
                love.graphics.print("OFF", 400, optionY + (i-1)*50)
            end
        elseif setting.type == "back" then
            love.graphics.print("← Back", 400, optionY + (i-1)*50)
        end
        
        love.graphics.setColor(1, 1, 1, 1)
    end
    
    -- Draw instructions
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.print("ARROW KEYS: Navigate | LEFT/RIGHT: Adjust | ENTER: Toggle | ESC: Back", 
                       ww/2 - 250, wh - 100)
    love.graphics.setColor(1, 1, 1, 1)
end

return UI
