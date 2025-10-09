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
local Map = require('map')
local Pathfinding = require('pathfinding')
local Shaders = require('shaders')

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
    map = nil,
    pathfinding = nil,
    DEBUG = true,
    mapStates = {},  -- Store saved map states
    currentMapPath = nil
}

function love.load()
    -- Store game state globally for map scripts
    love.gameState = game
    
    -- Initialize modules
    game.assets = Assets:new()
    game.assets:load()

    game.player = Player:new()
    game.collision = Collision:new()
    game.shooting = Shooting:new()
    game.ui = UI:new()
    game.particles = Particles:new()
    game.gameManager = GameManager:new()
    game.map = Map:new()
    game.shaders = Shaders:new()
    game.shaders:initializeDefaultShaders(game.DEBUG)

    -- Load map (fallback to default if loading fails)
    local mapLoaded = false
    if love.filesystem.getInfo("maps/arena_map/arena_map.json") then
        -- Load arena map
        game.map:load("maps/arena_map/arena_map")
        game.currentMapPath = "maps/arena_map/arena_map"
        mapLoaded = true
    elseif love.filesystem.getInfo("maps/test_map/test_map.json") then
        -- Fallback to test map
        game.map:load("maps/test_map/test_map")
        game.currentMapPath = "maps/test_map/test_map"
        mapLoaded = true
    else
        -- Create fallback infinite map with default floor tiles
        print("Map not found, using fallback rendering")
    end

    -- Initialize collision with map geometry
    if mapLoaded then
        game.collision:createMapGeometry(game.map)
        
        -- Initialize pathfinding with map and entity collision radius
        game.pathfinding = Pathfinding:new(32)  -- 32 pixel grid size
        game.pathfinding:initialize(game.map, 32)  -- 32 pixel entity collision radius
    end

    -- Initialize game manager with map spawners
    game.gameManager.map = game.map  -- Store map reference
    game.gameManager:initializeSpawners(game.map)

    -- Move player to spawn point if defined
    if game.gameManager.playerSpawnPoint then
        game.player.x = game.gameManager.playerSpawnPoint.x
        game.player.y = game.gameManager.playerSpawnPoint.y
    end

    -- Provide enemy creation callback to game manager
    game.gameManager.createEnemy = function(x, y, enemyType)
        return Enemy:new(x, y, enemyType)
    end

    -- Set random seed for consistent randomness
    math.randomseed(os.time())

    -- Spawn map-based entities (separated from wave system)
    game.gameManager:spawnMapEntities(game.enemies)

    -- Create initial wave enemies if needed
    if #game.enemies < 3 then
        for i = 1, 3 - #game.enemies do
            table.insert(game.enemies, Enemy:new())
        end
    end
end

function love.update(dt)
    -- Update shaders
    game.shaders:update(dt)
    
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
            local canAttack = enemy:update(dt, game.player, game.pathfinding)
            
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

                -- Handle enemy drops
                local drops = enemy:getDrops()
                print("Enemy died, checking drops. Total drops: " .. #drops)
                for _, drop in ipairs(drops) do
                    -- Get enemy position for drop
                    local dropX, dropY = enemy:getCenter()
                    print("Creating drop at " .. dropX .. ", " .. dropY .. " - Type: " .. drop.type)
                    game.gameManager:createDrop(dropX, dropY, drop.type, drop.amount)
                end

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
            
            -- Trigger screen shake effect based on weapon type
            local weapon = game.player:getCurrentWeapon()
            local weaponConfig = Weapons.TYPES[weapon.type]
            local shakeIntensity = weaponConfig.screenShakeIntensity or 0.1  -- Use weapon-specific intensity
            
            -- Activate screen shake for 0.2 seconds with weapon-specific intensity
            game.shaders:activateShader("screen_shake", 0.2, shakeIntensity)

            -- Perform shooting with weapon damage, range falloff, and collateral damage
            local weapon = game.player:getCurrentWeapon()
            local weaponConfig = Weapons.TYPES[weapon.type]
            local hitEnemies = game.shooting:shootRay(game.player, game.enemies, weapon.accuracy, weapon.range, weapon.maxRange, weaponConfig.collateral, weaponConfig.collateralFalloff, game.collision)

            -- Create bullet tracer(s) - single for normal weapons, multiple for shotguns
            local weapon = game.player:getCurrentWeapon()
            local weaponConfig = Weapons.TYPES[weapon.type]

            if weaponConfig.ammoType == Weapons.AMMO_TYPES.AMMO_12GAUGE and hitEnemies.pelletHits then
                -- Multi-pellet shotgun tracers - create one tracer per pellet
                -- Each pellet's hitDistance already accounts for walls
                for i, pelletHit in ipairs(hitEnemies.pelletHits) do
                    local pelletTracerDistance = pelletHit.hitDistance
                    game.particles:createBulletTracer(mx, my, pelletHit.angle, pelletTracerDistance)
                end
            else
                -- Single tracer for normal weapons (pistol, rifles, etc.)
                -- Use wall hit distance, or enemy hit distance if closer
                local tracerDistance = hitEnemies.wallHitDist or game.shooting:getMaxWorldBoundaryDistance(game.player)
                if #hitEnemies > 0 then
                    local lastDamagedEnemy = hitEnemies[#hitEnemies]
                    tracerDistance = math.min(tracerDistance, lastDamagedEnemy.hitDistance)
                end
                game.particles:createBulletTracer(mx, my, game.player.angle, tracerDistance)
            end
            
            -- Track enemies that died from this shot
            local deadEnemyIndices = {}
            
            for _, hit in ipairs(hitEnemies) do
                -- Calculate damage based on distance falloff with upgrade effects
                local baseDamage = game.player:getEffectiveDamage(weapon)
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
                if enemy and enemy:takeDamage(finalDamage) then
                    -- Enemy died from this shot
                    local ex, ey = enemy:getCenter()
                    game.particles:createBloodSplat(ex, ey)
                    game.ui:addScore(enemy:getScore())
                    
                    -- Handle enemy drops (FIXED: Added missing drop logic)
                    local drops = enemy:getDrops()
                    for _, drop in ipairs(drops) do
                        game.gameManager:createDrop(ex, ey, drop.type, drop.amount)
                    end
                    
                    game.gameManager:enemyKilled()
                    table.insert(deadEnemyIndices, hit.enemyIndex)
                else
                    -- Enemy hit but not killed
                    local ex, ey = enemy:getCenter()
                    game.particles:createBloodSplat(ex, ey)
                end
            end
            
            -- Remove dead enemies in reverse order to avoid index shifting issues
            table.sort(deadEnemyIndices, function(a, b) return a > b end)
            for _, index in ipairs(deadEnemyIndices) do
                table.remove(game.enemies, index)
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
            
            -- Check for dash damage to enemies
            local dashDamageLevel = game.player:getUpgradeLevel("dash_damage")
            if dashDamageLevel > 0 then
                -- Calculate dash damage based on level (20, 40, 60 damage per level)
                local dashDamage = 20 * dashDamageLevel
                local playerX, playerY = game.player:getCenter()
                
                for i, enemy in ipairs(game.enemies) do
                    local ex, ey = enemy:getCenter()
                    local dx = ex - playerX
                    local dy = ey - playerY
                    local dist = math.sqrt(dx*dx + dy*dy)
                    
                    -- Damage enemies within 80 pixels during dash
                    if dist < 80 then
                        -- Create dash impact effect
                        game.particles:createDashImpact(ex, ey)
                        
                        -- Damage the enemy
                        if enemy:takeDamage(dashDamage) then
                            -- Enemy died from dash damage
                            game.particles:createBloodSplat(ex, ey)
                            game.ui:addScore(enemy:getScore())
                            game.gameManager:enemyKilled()
                            table.remove(game.enemies, i)
                            break  -- Break to avoid index issues
                        else
                            -- Enemy hit but not killed
                            game.particles:createBloodSplat(ex, ey)
                        end
                    end
                end
            end
        end
    end
    
    -- Update shop message timer
    game.ui:updateShopMessage(dt)
end

function love.draw()
    local ww, wh = love.graphics.getDimensions()
    
    -- Start capturing the game to canvas for shader effects
    game.shaders:beginCapture()
    
    -- Only draw game world if not in shop
    if not game.gameManager:isShopOpen() then
        love.graphics.push()
        love.graphics.translate(ww/2 - game.player.x - game.player.width/2, wh/2 - game.player.y - game.player.height/2)

        -- Draw map (background layers 0-49)
        game.map:draw(0, 49)

        -- Fallback to default floor tiles if no map loaded
        if not game.map.data then
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
        end

        -- Draw map (foreground layers 50-100)
        game.map:draw(50, 100)
        
        -- Draw interactive objects (chests, etc.)
        game.map:drawObjects()

        -- Draw pickups
        game.gameManager:drawPickups()

        -- Draw particles that appear behind entities (bullet tracers, blood)
        game.particles:drawBehindEntities()

        -- Draw enemies
        for _, enemy in ipairs(game.enemies) do
            enemy:draw(game.assets, game.DEBUG)
            
            -- Draw enemy path in debug mode
            if game.DEBUG and enemy.path and game.pathfinding then
                game.pathfinding:debugDrawPath(enemy.path)
            end
        end

        -- Draw player
        game.player:draw(game.assets, game.DEBUG)

        -- Draw particles that appear across entities (muzzle flash, dash trail)
        game.particles:drawAcrossEntities()

        -- Draw particles that appear above entities (pickup effects)
        game.particles:drawAboveEntities()

        -- Draw shooting ray
        game.shooting:drawRay(game.player, game.DEBUG)

        -- Draw debug boundaries and map collision
        if game.DEBUG then
            love.graphics.setColor(0, 1, 0, 0.3)  -- Green for screen boundaries
            love.graphics.rectangle('line', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

            -- Draw map collision polygons (filled)
            love.graphics.setColor(1, 0, 1, 0.3)  -- Magenta filled polygons
            love.graphics.setBlendMode("multiply", "premultiplied")
            for _, polygon in ipairs(game.map:getCollisionPolygons()) do
                if #polygon >= 3 then
                    local vertices = {}
                    for _, point in ipairs(polygon) do
                        table.insert(vertices, point[1])
                        table.insert(vertices, point[2])
                    end
                    -- Draw filled polygon (assuming convex polygons)
                    if #vertices >= 6 then  -- Need at least 3 points (6 coords)
                        love.graphics.polygon("fill", vertices)
                    end
                end
            end
            love.graphics.setBlendMode("alpha", "alphamultiply")

            -- Draw debug labels (in world space considering camera position)
            -- Position labels relative to player's world position so they move with camera
            local labelWorldX = game.player.x - ww/2 + 10  -- Screen x=10 relative to camera
            local labelWorldY = game.player.y - wh/2 + 10  -- Screen y=10 relative to camera
            love.graphics.setColor(0, 1, 0, 1)  -- Bright green for text
            love.graphics.print("Screen Bounds", labelWorldX, labelWorldY)
            love.graphics.setColor(1, 0, 1, 1)  -- Bright magenta for text
            love.graphics.print("Map Collision Polygons", labelWorldX, labelWorldY + 15)
            love.graphics.setColor(0, 1, 1, 1)  -- Bright cyan for text
            love.graphics.print("Entities", labelWorldX, labelWorldY + 30)

            love.graphics.setColor(1, 1, 1, 1)  -- Reset to white

            -- Draw player collision bounds if any
            love.graphics.setColor(0, 1, 1, 0.3)  -- Cyan for entities

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
    
    -- Draw loadout manager if in loadout mode
    if game.ui:isLoadoutMode() then
        game.ui:drawLoadoutManager(game.player)
    end
    
    -- Draw wave info
    game.gameManager:drawWaveInfo()
    
    -- End capture and apply shaders
    game.shaders:endCapture()
end

function love.mousepressed(x, y, button, istouch, presses)
    if button == 2 and game.gameManager:getState() == "PLAYING" then  -- Right click
        -- Check for interactable objects in front of player
        local interactRange = 100
        local px, py = game.player:getCenter()
        local playerAngle = game.player.angle
        
        -- Calculate position in front of player
        local checkX = px + math.cos(playerAngle) * interactRange
        local checkY = py + math.sin(playerAngle) * interactRange
        
        -- Check map objects for interactions
        if game.map and game.map.objects then
            for id, obj in pairs(game.map.objects) do
                local dx = obj.position.x - px
                local dy = obj.position.y - py
                local dist = math.sqrt(dx * dx + dy * dy)
                
                -- Check if object is within range and roughly in front of player
                if dist <= interactRange then
                    local angleToObj = math.atan2(dy, dx)
                    local angleDiff = math.abs(angleToObj - playerAngle)
                    -- Normalize angle difference
                    if angleDiff > math.pi then
                        angleDiff = 2 * math.pi - angleDiff
                    end
                    
                    -- If object is within 90 degrees in front of player
                    if angleDiff < math.pi / 2 then
                        -- Execute interact trigger
                        if obj.trigger and obj.trigger.on_interact then
                            game.map:executeTrigger(obj.trigger.on_interact, obj, {x = px, y = py})
                        end
                        break  -- Only interact with closest object
                    end
                end
            end
        end
    end
end

function love.keypressed(key)
    -- Toggle debug mode
    if key == 'f1' then
        game.DEBUG = not game.DEBUG
    end
    
    -- Toggle loadout mode (only when not in shop)
    if key == 'tab' and not game.gameManager:isShopOpen() then
        game.ui:toggleLoadoutMode()
    end
    
    -- Handle loadout input if in loadout mode
    if game.ui:isLoadoutMode() then
        if game.ui:handleLoadoutInput(key, game.player) then
            return
        end
    end
    
    -- Restart game
    if key == 'r' and (game.ui:isGameOver() or game.ui:isVictory()) then
        restartGame()
    end
    
    -- Shader controls (only when playing and not in shop/loadout)
    if game.gameManager:getState() == "PLAYING" and not game.gameManager:isShopOpen() and not game.ui:isLoadoutMode() then
        -- Debug-only test shaders
        if game.DEBUG then
            -- 'k' key: Toggle red tint shader continuously
            if key == 'k' then
                if game.shaders:isShaderActive("red_tint") then
                    game.shaders:deactivateShader("red_tint")
                else
                    game.shaders:activateShader("red_tint", 0) -- 0 = continuous
                end
            end
            
            -- 't' key: Activate blue wave shader for 2 seconds
            if key == 't' then
                game.shaders:activateShader("blue_wave", 2.0)
            end
        end
    end
    
    -- Shop interaction
    if game.gameManager:isShopOpen() then
        local shop = game.gameManager:getShop()
        local items = shop:getAvailableItems()
        
        if key == 'up' then
            shop.selectedItem = math.max(1, shop.selectedItem - 1)
            -- Auto-scroll when moving up
            if shop.selectedItem <= math.floor(game.ui.shopScrollOffset / 60) then
                game.ui.shopScrollOffset = math.max(0, game.ui.shopScrollOffset - 60)
            end
        elseif key == 'down' then
            shop.selectedItem = math.min(#items, shop.selectedItem + 1)
            -- Auto-scroll when moving down
            local visibleBottomIndex = math.floor(game.ui.shopScrollOffset / 60) + game.ui.visibleShopItems
            if shop.selectedItem > visibleBottomIndex then
                game.ui.shopScrollOffset = math.min((#items - game.ui.visibleShopItems) * 60, game.ui.shopScrollOffset + 60)
            end
        elseif key == 'pageup' then
            -- Scroll up one page
            game.ui.shopScrollOffset = math.max(0, game.ui.shopScrollOffset - (game.ui.visibleShopItems * 60))
            -- Update selected item to match scroll position
            shop.selectedItem = math.max(1, math.floor(game.ui.shopScrollOffset / 60) + 1)
        elseif key == 'pagedown' then
            -- Scroll down one page
            local maxScroll = math.max(0, #items - game.ui.visibleShopItems) * 60
            game.ui.shopScrollOffset = math.min(maxScroll, game.ui.shopScrollOffset + (game.ui.visibleShopItems * 60))
            -- Update selected item to match scroll position
            shop.selectedItem = math.min(#items, math.floor(game.ui.shopScrollOffset / 60) + game.ui.visibleShopItems)
        elseif key == 'return' then
            -- Buy selected item
            if #items > 0 then
                local selectedItem = items[shop.selectedItem]
                local success, message = game.gameManager:buyItem(game.player, selectedItem.type, selectedItem)
                game.ui:setShopMessage(message)
            end
        elseif key == 'tab' then
            -- Switch shop categories
            local categories = {"WEAPONS", "AMMO", "HEALTH", "UPGRADES"}
            local currentIndex = 1
            for i, cat in ipairs(categories) do
                if shop.selectedCategory == cat then
                    currentIndex = i
                    break
                end
            end
            local nextIndex = (currentIndex % #categories) + 1
            shop.selectedCategory = categories[nextIndex]
            shop.selectedItem = 1
            game.ui.shopScrollOffset = 0
        elseif key == 'left' then
            -- Switch shop categories (backward)
            local categories = {"WEAPONS", "AMMO", "HEALTH", "UPGRADES"}
            local currentIndex = 1
            for i, cat in ipairs(categories) do
                if shop.selectedCategory == cat then
                    currentIndex = i
                    break
                end
            end
            local prevIndex = ((currentIndex - 2) % #categories) + 1
            shop.selectedCategory = categories[prevIndex]
            shop.selectedItem = 1
            game.ui.shopScrollOffset = 0
        elseif key == 'right' then
            -- Switch shop categories (forward)
            local categories = {"WEAPONS", "AMMO", "HEALTH", "UPGRADES"}
            local currentIndex = 1
            for i, cat in ipairs(categories) do
                if shop.selectedCategory == cat then
                    currentIndex = i
                    break
                end
            end
            local nextIndex = (currentIndex % #categories) + 1
            shop.selectedCategory = categories[nextIndex]
            shop.selectedItem = 1
            game.ui.shopScrollOffset = 0
        end
    end
end

function saveMapState(mapPath)
    -- Save current map state
    game.mapStates[mapPath] = {
        enemies = {},
        playerX = game.player.x,
        playerY = game.player.y,
        objectStates = {},
        dropState = nil,
        spawnerStates = {}
    }
    
    -- Save enemies (create deep copy to avoid reference issues)
    for _, enemy in ipairs(game.enemies) do
        table.insert(game.mapStates[mapPath].enemies, {
            x = enemy.x,
            y = enemy.y,
            type = enemy.type,
            health = enemy.health,
            maxHealth = enemy.maxHealth
        })
    end
    
    -- Save object states (doors open/closed, etc.)
    if game.map and game.map.objects then
        for id, obj in pairs(game.map.objects) do
            game.mapStates[mapPath].objectStates[id] = {
                open = obj.state.open,
                active = obj.state.active,
                triggered = obj.state.triggered
            }
        end
    end
    
    -- Save drop system state (pickups and temporary spawners)
    if game.gameManager and game.gameManager.drops then
        game.mapStates[mapPath].dropState = game.gameManager.drops:saveState()
    end
    
    -- Save permanent spawner states (whether they've been spawned)
    if game.map and game.map.data and game.map.data.spawners then
        for spawnerId, spawner in pairs(game.map.data.spawners) do
            if not spawner.temporary then
                game.mapStates[mapPath].spawnerStates[spawnerId] = {
                    spawned = spawner.spawned or false
                }
            end
        end
    end
    
    print("Saved map state for: " .. mapPath)
end

function loadMap(mapPath, remember, spawnX, spawnY)
    -- Save current map state if remember mode
    if remember and game.currentMapPath then
        saveMapState(game.currentMapPath)
    end
    
    -- Load new map
    game.map = Map:new()
    game.map:load(mapPath)
    game.currentMapPath = mapPath
    
    -- Reinitialize collision with new map
    game.collision = Collision:new()
    game.collision:createMapGeometry(game.map)
    
    -- Reinitialize pathfinding with new map and entity collision radius
    game.pathfinding = Pathfinding:new(32)
    game.pathfinding:initialize(game.map, 32)  -- 32 pixel entity collision radius
    
    -- Reinitialize game manager with new map
    game.gameManager.map = game.map
    game.gameManager:initializeSpawners(game.map)
    
    -- Set map reference in drops system
    game.gameManager.drops:setMap(game.map)
    
    -- Restore or reset map state
    if remember and game.mapStates[mapPath] then
        -- Restore saved state
        local state = game.mapStates[mapPath]
        print("Restoring map state for: " .. mapPath)
        
        -- Restore enemies (recreate Enemy objects from saved data)
        game.enemies = {}
        for _, enemyData in ipairs(state.enemies) do
            local enemy = Enemy:new(enemyData.x, enemyData.y, enemyData.type)
            enemy.health = enemyData.health
            enemy.maxHealth = enemyData.maxHealth
            table.insert(game.enemies, enemy)
        end
        
        -- Restore player position
        game.player.x = state.playerX
        game.player.y = state.playerY
        
        -- Restore object states
        for id, objState in pairs(state.objectStates) do
            if game.map.objects[id] then
                game.map.objects[id].state.open = objState.open
                game.map.objects[id].state.active = objState.active
                game.map.objects[id].state.triggered = objState.triggered
                
                -- Update collision if it's a door
                if game.map.objects[id].collision_id then
                    game.map:toggleCollision(game.map.objects[id].collision_id, not objState.open)
                end
            end
        end
        
        -- Restore drop system state (pickups and temporary spawners)
        if state.dropState then
            game.gameManager.drops:restoreState(state.dropState)
        end
        
        -- Restore permanent spawner states
        if state.spawnerStates and game.map.data and game.map.data.spawners then
            for spawnerId, spawnerState in pairs(state.spawnerStates) do
                if game.map.data.spawners[spawnerId] then
                    game.map.data.spawners[spawnerId].spawned = spawnerState.spawned
                end
            end
        end
    else
        -- Reset state - spawn new enemies and move player to spawn
        print("Loading fresh map state for: " .. mapPath)
        game.enemies = {}
        
        -- Clear any existing drops
        game.gameManager.drops:clear()
        
        -- Spawn map entities
        game.gameManager:spawnMapEntities(game.enemies)
        
        -- Position player
        if spawnX and spawnY then
            game.player.x = spawnX
            game.player.y = spawnY
        elseif game.gameManager.playerSpawnPoint then
            game.player.x = game.gameManager.playerSpawnPoint.x
            game.player.y = game.gameManager.playerSpawnPoint.y
        end
    end
end

function restartGame()
    -- Reset all game state
    game.player = Player:new()

    -- Re-position player to spawn point if available
    if game.gameManager and game.gameManager.playerSpawnPoint then
        game.player.x = game.gameManager.playerSpawnPoint.x
        game.player.y = game.gameManager.playerSpawnPoint.y
    end

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
