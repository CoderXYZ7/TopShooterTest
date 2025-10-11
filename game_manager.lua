-- Game Manager for handling game states, waves, and progression
local GameManager = {}
local Shop = require('shop')
local Drops = require('drops')

function GameManager:new()
    local manager = {
        currentState = "START_MENU",  -- START_MENU, PLAYING, GAME_OVER, VICTORY, PAUSED, SHOP, SETTINGS
        wave = 1,
        enemiesPerWave = 5,
        enemiesSpawnedThisWave = 0,
        enemiesKilledThisWave = 0,
        waveTimer = 0,
        waveCooldown = 3,  -- Seconds between waves
        spawnTimer = 0,
        spawnInterval = 2.0,  -- Seconds between enemy spawns
        maxEnemies = 15,
        difficultyMultiplier = 1.0,
        waveCleared = false,
        createEnemy = nil,  -- Will be set by main.lua
        shop = Shop:new(),
        shopOpen = false,
        shopTimer = 0,
        shopDuration = 30,  -- 30 seconds to shop between waves
        drops = Drops:new(),  -- Drops and pickups management
        -- Menu states
        menuSelection = 1,
        settingsSelection = 1,
        -- Settings
        musicVolume = 0.5,
        soundVolume = 0.7,
        showTutorial = true,
        debugMode = false
    }
    setmetatable(manager, { __index = self })
    return manager
end

function GameManager:update(dt, player, enemies, particles, ui)
    if self.currentState == "PLAYING" then
        -- Update drops system (only temporary spawners and pickups)
        self.drops:updateTemporarySpawners(dt, player, particles)

        -- Check for player death
        if not player:isAlive() then
            self.currentState = "GAME_OVER"
            ui:gameOverScreen()
        end

        -- Update pickups through drops module
        self.drops:updatePickups(dt, player, particles)
        
    elseif self.currentState == "SHOP" then
        -- Handle shop state
        self.shopTimer = self.shopTimer + dt
        
        -- Close shop when time runs out or player presses escape
        if self.shopTimer >= self.shopDuration or love.keyboard.isDown('escape') then
            self.currentState = "PLAYING"
            self.shop:close()
            self:startNextWave()
        end
        
    elseif self.currentState == "GAME_OVER" or self.currentState == "VICTORY" then
        -- Handle restart
        if love.keyboard.isDown('r') then
            self:reset()
            return true  -- Signal to restart game
        end
    end
    
    return false
end

function GameManager:updateWaveSystem(dt, enemies, ui, player)
    -- Check if wave is cleared (all required enemies spawned and killed)
    if not self.waveCleared and self.enemiesSpawnedThisWave >= self.enemiesPerWave and #enemies == 0 then
        self.waveCleared = true
        self.waveTimer = 0
        
        -- Give player money for clearing wave
        local waveBonus = self.wave * 50
        player:addMoney(waveBonus)
        ui:addScore(waveBonus)
        
        -- Open shop between waves (except after wave 1)
        if self.wave > 1 then
            self.currentState = "SHOP"
            self.shop:open()
            self.shop:unlockWeapons(self.wave)
            self.shopTimer = 0
        else
            -- For wave 1, just proceed to next wave
            self:startNextWave()
        end
    end
    
    -- Handle wave cooldown (for wave 1 transition)
    if self.waveCleared and self.currentState == "PLAYING" then
        self.waveTimer = self.waveTimer + dt
        if self.waveTimer >= self.waveCooldown then
            self:startNextWave()
        end
    end
    
    ui:setEnemiesRemaining(self.enemiesPerWave - self.enemiesKilledThisWave)
end

function GameManager:startNextWave()
    -- Reset wave tracking
    self.enemiesSpawnedThisWave = 0
    self.enemiesKilledThisWave = 0
    self.waveCleared = false
    self.spawnTimer = 0
    
    -- Increase difficulty for next wave
    self.wave = self.wave + 1
    self.enemiesPerWave = math.min(30, 5 + self.wave * 2)
    self.difficultyMultiplier = 1.0 + (self.wave - 1) * 0.1
    self.spawnInterval = math.max(0.5, 2.0 - (self.wave - 1) * 0.1)
end

function GameManager:updateEnemySpawning(dt, enemies)
    if not self.waveCleared and #enemies < self.maxEnemies and self.enemiesSpawnedThisWave < self.enemiesPerWave then
        self.spawnTimer = self.spawnTimer + dt
        if self.spawnTimer >= self.spawnInterval then
            self:spawnEnemy(enemies)
            self.spawnTimer = 0
        end
    end
end

function GameManager:getRandomEnemyType()
    local rand = math.random()
    if rand < 0.6 then
        return "ZOMBIE"
    elseif rand < 0.85 then
        return "FAST_ZOMBIE"
    else
        return "TANK_ZOMBIE"
    end
end

function GameManager:spawnEnemy(enemies)
    local enemyType = self:getRandomEnemyType()
    
    -- Adjust spawn probabilities based on wave
    if self.wave >= 3 then
        local rand = math.random()
        if rand < 0.4 then
            enemyType = "ZOMBIE"
        elseif rand < 0.75 then
            enemyType = "FAST_ZOMBIE"
        else
            enemyType = "TANK_ZOMBIE"
        end
    elseif self.wave >= 5 then
        local rand = math.random()
        if rand < 0.3 then
            enemyType = "ZOMBIE"
        elseif rand < 0.65 then
            enemyType = "FAST_ZOMBIE"
        else
            enemyType = "TANK_ZOMBIE"
        end
    end
    
    -- Spawn enemy at edge of screen
    local side = math.random(1, 4)
    local x, y
    
    if side == 1 then  -- Top
        x = math.random(0, love.graphics.getWidth())
        y = -50
    elseif side == 2 then  -- Right
        x = love.graphics.getWidth() + 50
        y = math.random(0, love.graphics.getHeight())
    elseif side == 3 then  -- Bottom
        x = math.random(0, love.graphics.getWidth())
        y = love.graphics.getHeight() + 50
    else  -- Left
        x = -50
        y = math.random(0, love.graphics.getHeight())
    end
    
    -- Create enemy using the callback provided by main.lua
    if self.createEnemy then
        local enemy = self.createEnemy(x, y, enemyType)
        table.insert(enemies, enemy)
        self.enemiesSpawnedThisWave = self.enemiesSpawnedThisWave + 1
    end
end

-- Method to track enemy kills (call this when an enemy dies)
function GameManager:enemyKilled()
    self.enemiesKilledThisWave = self.enemiesKilledThisWave + 1
end

function GameManager:createDrop(x, y, dropType, amount)
    self.drops:createDrop(x, y, dropType, amount)
end

function GameManager:drawPickups()
    self.drops:drawPickups()
end

function GameManager:drawWaveInfo()
    if self.waveCleared then
        local timeLeft = math.ceil(self.waveCooldown - self.waveTimer)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.print("Wave " .. self.wave .. " starting in " .. timeLeft .. "...", 
                           love.graphics.getWidth()/2 - 100, 50)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function GameManager:reset()
    self.currentState = "PLAYING"
    self.wave = 1
    self.enemiesPerWave = 5
    self.enemiesSpawnedThisWave = 0
    self.enemiesKilledThisWave = 0
    self.waveTimer = 0
    self.spawnTimer = 0
    self.difficultyMultiplier = 1.0
    self.spawnInterval = 2.0
    self.waveCleared = false
    self.shop = Shop:new()
    self.shopTimer = 0
    self.drops:clear()  -- Clear drops and pickups
end

function GameManager:getState()
    return self.currentState
end

function GameManager:setState(state)
    self.currentState = state
end

-- Shop interaction methods
function GameManager:isShopOpen()
    return self.currentState == "SHOP"
end

function GameManager:getShop()
    return self.shop
end

function GameManager:getShopTimeLeft()
    return math.max(0, self.shopDuration - self.shopTimer)
end

function GameManager:initializeSpawners(map)
    if not map then 
        print("GameManager: No map provided to initializeSpawners")
        return 
    end

    -- Set player spawn position
    local playerSpawns = map:getSpawners("player")
    if #playerSpawns > 0 then
        self.playerSpawnPoint = {
            x = playerSpawns[1].position[1],
            y = playerSpawns[1].position[2]
        }
    end

    -- Set map reference in drops module
    self.drops:setMap(map)
    print("GameManager: Map reference set in drops system")
    print("GameManager: Map has data: " .. tostring(map.data ~= nil))
    if map.data then
        print("GameManager: Map has spawners: " .. tostring(map.data.spawners ~= nil))
    end
end

function GameManager:spawnMapEntities(enemies)
    if not self.map then return end

    -- Spawn single entities (not tied to waves)
    local singleSpawners = self.map:getSpawners("single")
    for _, spawner in ipairs(singleSpawners) do
        local enemyType = spawner.entity
        if enemyType and not spawner.spawned then
            local enemy = self.createEnemy(spawner.position[1], spawner.position[2], enemyType)
            if enemy then
                table.insert(enemies, enemy)
                spawner.spawned = true -- Mark as spawned
            end
        end
    end

    -- Spawn items from map item spawners
    if self.map.data and self.map.data.spawners then
        for spawnerId, spawner in pairs(self.map.data.spawners) do
            if spawner.type == "item" and not spawner.temporary and not spawner.spawned then
                self.drops:spawnItemFromSpawner(spawner, spawnerId)
                spawner.spawned = true -- Mark as spawned
            end
        end
    end

    -- Potentially add wave spawners here if wanted, but keeping them separate as requested
end

function GameManager:spawnEnemyFromMapSpawner(spawner)
    local enemyType = spawner.entities[math.random(#spawner.entities)]
    local angle = math.rad(math.random(0, 360))
    local distance = math.random(0, spawner.spawn_range)
    local x = spawner.position[1] + math.cos(angle) * distance
    local y = spawner.position[2] + math.sin(angle) * distance

    local enemy = self.createEnemy(x, y, enemyType)
    table.insert(enemies, enemy)
    return enemy
end

function GameManager:buyItem(player, itemType, itemData)
    if not self:isShopOpen() then
        return false, "Shop is not open"
    end

    local cost = 0
    local success = false

    if itemType == "weapon" then
        cost = self.shop:getWeaponCost(itemData.weaponType)
        if player:spendMoney(cost) then
            success = player:addWeapon(itemData.weaponType)
            if not success then
                player:addMoney(cost) -- Refund if weapon couldn't be added
                return false, "Already have this weapon"
            end
        else
            return false, "Not enough money"
        end
    elseif itemType == "ammo" then
        cost = self.shop:getAmmoCost(itemData.ammoType)
        if player:spendMoney(cost) then
            -- Convert shop ammo type to weapons ammo type
            local Weapons = require('weapons')
            local weaponsAmmoType = nil
            if itemData.ammoType == "9mm" then
                weaponsAmmoType = Weapons.AMMO_TYPES.AMMO_9MM
            elseif itemData.ammoType == ".30-06" then
                weaponsAmmoType = Weapons.AMMO_TYPES.AMMO_3006
            end
            player:addAmmo(itemData.amount, weaponsAmmoType)
            success = true
        else
            return false, "Not enough money"
        end
    elseif itemType == "health" then
        cost = self.shop:getHealthCost(itemData.healthType)
        if player:spendMoney(cost) then
            player:heal(itemData.amount)
            success = true
        else
            return false, "Not enough money"
        end
    elseif itemType == "upgrade" then
        cost = self.shop:getUpgradeCost(itemData.upgradeType, player)
        if player:spendMoney(cost) then
            success, message = player:purchaseUpgrade(itemData.upgradeType)
            if not success then
                player:addMoney(cost) -- Refund if upgrade couldn't be purchased
                return false, message
            end
        else
            return false, "Not enough money"
        end
    elseif itemType == "throwable" then
        cost = Shop.THROWABLE_COSTS[itemData.throwableType].cost
        if player:spendMoney(cost) then
            success, message = player:addThrowable(itemData.throwableType, itemData.amount)
            if not success then
                player:addMoney(cost) -- Refund if throwable couldn't be added
                return false, message
            end
        else
            return false, "Not enough money"
        end
    end

    return success, success and "Purchase successful" or "Purchase failed"
end

return GameManager
