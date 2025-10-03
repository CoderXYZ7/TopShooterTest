-- Top Down Shooter Game - Enhanced Modular Version with Inventory and Shop

-- Import modules
local Player = require('player')
local Enemy = require('enemy')
local Assets = require('assets')
local Collision = require('collision')
local Shooting = require('shooting')
local UI = require('ui')
local Particles = require('particles')
local GameManager = require('game_manager')
local Weapons = require('weapons')
local Shop = require('shop')

-- Game state
local game = {
    player = nil,
    enemies = {},
    assets = nil,
    collision = nil,
    shooting = nil,
    ui = nil,
    particles = nil,
    gameManager = nil,
    DEBUG = true
}

function love.load()
    -- Initialize modules
    game.assets = Assets:new()
    game.assets:load()
    
    game.player = Player:new()
    game.collision = Collision:new()
    game.shooting = Shooting:new()
    game.ui = UI:new()
    game.particles = Particles:new()
    game.gameManager = GameManager:new()
    
    -- Provide enemy creation callback to game manager
    game.gameManager.createEnemy = function(x, y, enemyType)
        return Enemy:new(x, y, enemyType)
    end
    
    -- Set random seed for consistent randomness
    math.randomseed(os.time())
    
    -- Create initial enemies
    for i = 1, 3 do
        table.insert(game.enemies, Enemy:new())
    end
end

function love.update(dt)
    -- Check if we need to restart the game
    if game.gameManager:update(dt, game.player, game.enemies, game.particles, game.ui) then
        restartGame()
        return
    end
    
    if game.gameManager:getState() == "PLAYING" then
        -- Update player and check if they shot
        local playerShot = game.player:update(dt, game.assets)
        
        -- Update enemies and handle attacks
        for i = #game.enemies, 1, -1 do
            local enemy = game.enemies[i]
            local canAttack = enemy:update(dt, game.player)
            
            -- Handle enemy attacks
            if canAttack then
                local ex, ey = enemy:getCenter()
                if game.player:takeDamage(enemy:getDamage(), ex, ey) then
                    -- Create blood effect when player takes damage
                    local px, py = game.player:getCenter()
                    game.particles:createBloodSplat(px, py)
                end
            end
            
            -- Remove dead enemies
            if not enemy:isAlive() then
                -- Create blood effect
                local ex, ey = enemy:getCenter()
                game.particles:createBloodSplat(ex, ey)
                
                -- Add score
                game.ui:addScore(enemy:getScore())
                
                -- Track enemy kill for wave progression
                game.gameManager:enemyKilled()
                
                table.remove(game.enemies, i)
            end
        end
        
        -- Handle shooting
        if playerShot then
            -- Create muzzle flash at correct weapon position
            local mx, my = game.player:getMuzzlePosition()
            game.particles:createMuzzleFlash(mx, my, game.player.angle)
            
            -- Perform shooting with weapon damage, range falloff, and collateral damage
            local weapon = game.player:getCurrentWeapon()
            local weaponConfig = Weapons.TYPES[weapon.type]
            local hitEnemies = game.shooting:shootRay(game.player, game.enemies, weapon.accuracy, weapon.range, weapon.maxRange, weaponConfig.collateral, weaponConfig.collateralFalloff)
            
            for _, hit in ipairs(hitEnemies) do
                -- Calculate damage based on distance falloff
                local baseDamage = weapon.damage
                local finalDamage = baseDamage
                
                -- Apply damage falloff beyond optimal range
                if hit.hitDistance > weapon.range then
                    local falloffRange = weapon.maxRange - weapon.range
                    local distanceBeyondRange = hit.hitDistance - weapon.range
                    local falloffPercent = distanceBeyondRange / falloffRange
                    local damageMultiplier = math.max(0.3, 1.0 - falloffPercent * 0.7)  -- Minimum 30% damage at max range
                    finalDamage = math.floor(baseDamage * damageMultiplier)
                end
                
                -- Apply collateral damage falloff
                finalDamage = math.floor(finalDamage * hit.damageMultiplier)
                
                -- Damage the enemy with calculated damage
                local enemy = game.enemies[hit.enemyIndex]
                if enemy:takeDamage(finalDamage) then
                    -- Enemy died from this shot
                    local ex, ey = enemy:getCenter()
                    game.particles:createBloodSplat(ex, ey)
                    game.ui:addScore(enemy:getScore())
                    game.gameManager:enemyKilled()
                    table.remove(game.enemies, hit.enemyIndex)
                else
                    -- Enemy hit but not killed
                    local ex, ey = enemy:getCenter()
                    game.particles:createBloodSplat(ex, ey)
                end
            end
        end
        
        -- Handle collisions
        game.collision:update(game.player, game.enemies)
        
        -- Update particles
        game.particles:update(dt)
        
        -- Update UI time
        game.ui:updateTime(dt)
        
        -- Create dash trail effect
        if game.player.isDashing then
            game.particles:createDashTrail(game.player)
        end
    end
    
    -- Update shop message timer
    game.ui:updateShopMessage(dt)
end

function love.draw()
    local ww, wh = love.graphics.getDimensions()
    
    -- Only draw game world if not in shop
    if not game.gameManager:isShopOpen() then
        love.graphics.push()
        love.graphics.translate(ww/2 - game.player.x - game.player.width/2, wh/2 - game.player.y - game.player.height/2)

        -- Draw floor tiles
        if game.assets.floorTile then
            local tw = game.assets.floorTile:getWidth()
            local th = game.assets.floorTile:getHeight()
            local tilesX = math.ceil(ww / tw) + 2
            local tilesY = math.ceil(wh / th) + 2
            
            -- Calculate offset to center the player and make movement smoother
            local offsetX = -game.player.x - game.player.width/2
            local offsetY = -game.player.y - game.player.height/2
            
            -- Snap to tile grid for smoother movement
            local snapX = math.floor(offsetX / tw) * tw
            local snapY = math.floor(offsetY / th) * th
            
            for i = -1, tilesX do
                for j = -1, tilesY do
                    love.graphics.draw(game.assets.floorTile, snapX + i * tw, snapY + j * th)
                end
            end
        end

        -- Draw pickups
        game.gameManager:drawPickups()

        -- Draw enemies
        for _, enemy in ipairs(game.enemies) do
            enemy:draw(game.assets, game.DEBUG)
        end

        -- Draw player
        game.player:draw(game.assets, game.DEBUG)

        -- Draw particles
        game.particles:draw()

        -- Draw shooting ray
        game.shooting:drawRay(game.player, game.DEBUG)

        -- Draw debug boundaries
        if game.DEBUG then
            love.graphics.setColor(0, 1, 0, 0.3)  -- Green for boundaries
            love.graphics.rectangle('line', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
            love.graphics.setColor(1, 1, 1, 1)
        end

        love.graphics.pop()
    end

    -- Draw UI (always visible)
    game.ui:draw(game.player, game.DEBUG, game.player.walkingFrameTime, game.player.walkingFrameDuration, game.assets.soldierWalkingImages, game.gameManager)
    
    -- Draw shop interface if shop is open
    if game.gameManager:isShopOpen() then
        game.ui:drawShop(game.gameManager, game.player)
    end
    
    -- Draw wave info
    game.gameManager:drawWaveInfo()
end

function love.keypressed(key)
    -- Toggle debug mode
    if key == 'f1' then
        game.DEBUG = not game.DEBUG
    end
    
    -- Restart game
    if key == 'r' and (game.ui:isGameOver() or game.ui:isVictory()) then
        restartGame()
    end
    
    -- Shop interaction
    if game.gameManager:isShopOpen() then
        local shop = game.gameManager:getShop()
        local items = shop:getAvailableItems()
        
        if key == 'up' then
            shop.selectedItem = math.max(1, shop.selectedItem - 1)
        elseif key == 'down' then
            shop.selectedItem = math.min(#items, shop.selectedItem + 1)
        elseif key == 'return' then
            -- Buy selected item
            if #items > 0 then
                local selectedItem = items[shop.selectedItem]
                local success, message = game.gameManager:buyItem(game.player, selectedItem.type, selectedItem)
                game.ui:setShopMessage(message)
            end
        elseif key == 'left' then
            -- Switch shop categories
            if shop.selectedCategory == "WEAPONS" then
                shop.selectedCategory = "HEALTH"
            elseif shop.selectedCategory == "AMMO" then
                shop.selectedCategory = "WEAPONS"
            elseif shop.selectedCategory == "HEALTH" then
                shop.selectedCategory = "AMMO"
            end
            shop.selectedItem = 1
        elseif key == 'right' then
            -- Switch shop categories
            if shop.selectedCategory == "WEAPONS" then
                shop.selectedCategory = "AMMO"
            elseif shop.selectedCategory == "AMMO" then
                shop.selectedCategory = "HEALTH"
            elseif shop.selectedCategory == "HEALTH" then
                shop.selectedCategory = "WEAPONS"
            end
            shop.selectedItem = 1
        end
    end
end

function restartGame()
    -- Reset all game state
    game.player = Player:new()
    game.enemies = {}
    game.collision = Collision:new()
    game.shooting = Shooting:new()
    game.ui:reset()
    game.particles:clear()
    game.gameManager:reset()
    
    -- Reinitialize some enemies to start
    for i = 1, 3 do
        table.insert(game.enemies, Enemy:new())
    end
end
