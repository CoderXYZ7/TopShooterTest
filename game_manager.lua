-- Game Manager for handling game states, waves, and progression
local GameManager = {}

function GameManager:new()
    local manager = {
        currentState = "PLAYING",  -- PLAYING, GAME_OVER, VICTORY, PAUSED
        wave = 1,
        enemiesPerWave = 5,
        waveTimer = 0,
        waveCooldown = 3,  -- Seconds between waves
        spawnTimer = 0,
        spawnInterval = 2.0,  -- Seconds between enemy spawns
        maxEnemies = 15,
        difficultyMultiplier = 1.0,
        pickupSpawnTimer = 0,
        pickupSpawnInterval = 10.0,  -- Seconds between pickup spawns
        pickups = {},
        waveCleared = false,
        createEnemy = nil  -- Will be set by main.lua
    }
    setmetatable(manager, { __index = self })
    return manager
end

function GameManager:update(dt, player, enemies, particles, ui)
    if self.currentState == "PLAYING" then
        -- Update wave system
        self:updateWaveSystem(dt, enemies, ui)
        
        -- Update enemy spawning
        self:updateEnemySpawning(dt, enemies)
        
        -- Update pickup spawning
        self:updatePickupSpawning(dt)
        
        -- Check for player death
        if not player:isAlive() then
            self.currentState = "GAME_OVER"
            ui:gameOverScreen()
        end
        
        -- Check for victory condition (survive 10 waves)
        if self.wave > 10 then
            self.currentState = "VICTORY"
            ui:victoryScreen()
        end
        
        -- Update pickups
        self:updatePickups(dt, player, particles)
        
    elseif self.currentState == "GAME_OVER" or self.currentState == "VICTORY" then
        -- Handle restart
        if love.keyboard.isDown('r') then
            self:reset()
            return true  -- Signal to restart game
        end
    end
    
    return false
end

function GameManager:updateWaveSystem(dt, enemies, ui)
    -- Check if wave is cleared
    if #enemies == 0 and not self.waveCleared then
        self.waveCleared = true
        self.waveTimer = 0
        
        -- Increase difficulty for next wave
        self.wave = self.wave + 1
        self.enemiesPerWave = math.min(30, 5 + self.wave * 2)
        self.difficultyMultiplier = 1.0 + (self.wave - 1) * 0.1
        self.spawnInterval = math.max(0.5, 2.0 - (self.wave - 1) * 0.1)
        
        ui:setWave(self.wave)
        ui:addScore(self.wave * 100)  -- Bonus for clearing wave
    end
    
    -- Handle wave cooldown
    if self.waveCleared then
        self.waveTimer = self.waveTimer + dt
        if self.waveTimer >= self.waveCooldown then
            self.waveCleared = false
            self.spawnTimer = 0
        end
    end
    
    ui:setEnemiesRemaining(#enemies)
end

function GameManager:updateEnemySpawning(dt, enemies)
    if not self.waveCleared and #enemies < self.maxEnemies then
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
    end
end

function GameManager:updatePickupSpawning(dt)
    self.pickupSpawnTimer = self.pickupSpawnTimer + dt
    if self.pickupSpawnTimer >= self.pickupSpawnInterval then
        self:spawnPickup()
        self.pickupSpawnTimer = 0
    end
end

function GameManager:spawnPickup()
    local pickupTypes = {"health", "ammo"}
    local type = pickupTypes[math.random(1, #pickupTypes)]
    
    local pickup = {
        x = math.random(100, love.graphics.getWidth() - 100),
        y = math.random(100, love.graphics.getHeight() - 100),
        type = type,
        lifetime = 15.0,  -- Pickups disappear after 15 seconds
        age = 0,
        size = 20
    }
    
    if type == "health" then
        pickup.color = {1, 0.2, 0.2}
    else
        pickup.color = {0.2, 0.2, 1}
    end
    
    table.insert(self.pickups, pickup)
end

function GameManager:updatePickups(dt, player, particles)
    for i = #self.pickups, 1, -1 do
        local pickup = self.pickups[i]
        pickup.age = pickup.age + dt
        
        -- Check collision with player
        local dx = pickup.x - (player.x + player.width/2)
        local dy = pickup.y - (player.y + player.height/2)
        local dist = math.sqrt(dx*dx + dy*dy)
        
        if dist < pickup.size + player.width/2 then
            -- Player collected pickup
            if pickup.type == "health" then
                player:heal(25)
                particles:createPickupEffect(pickup.x, pickup.y, {1, 0.2, 0.2})
            else
                player:addAmmo(15)
                particles:createPickupEffect(pickup.x, pickup.y, {0.2, 0.2, 1})
            end
            table.remove(self.pickups, i)
        elseif pickup.age >= pickup.lifetime then
            -- Pickup expired
            table.remove(self.pickups, i)
        end
    end
end

function GameManager:drawPickups()
    for _, pickup in ipairs(self.pickups) do
        local alpha = 1 - (pickup.age / pickup.lifetime) * 0.5
        love.graphics.setColor(pickup.color[1], pickup.color[2], pickup.color[3], alpha)
        love.graphics.circle('fill', pickup.x, pickup.y, pickup.size)
        
        -- Pulsing effect
        local pulse = math.sin(love.timer.getTime() * 5) * 2 + pickup.size
        love.graphics.setColor(1, 1, 1, alpha * 0.3)
        love.graphics.circle('line', pickup.x, pickup.y, pulse)
    end
    love.graphics.setColor(1, 1, 1, 1)
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
    self.waveTimer = 0
    self.spawnTimer = 0
    self.difficultyMultiplier = 1.0
    self.spawnInterval = 2.0
    self.pickupSpawnTimer = 0
    self.pickups = {}
    self.waveCleared = false
end

function GameManager:getState()
    return self.currentState
end

function GameManager:setState(state)
    self.currentState = state
end

return GameManager
