-- Map module for managing maps, collision geometry, and textures from JSON
local Map = {}

function Map:new()
    local map = {
        -- Core data
        data = nil,                -- Parsed JSON configuration
        script = nil,              -- Loaded Lua script functions
        textures = {},             -- Loaded LÖVE2D textures by name
        polygons = {},             -- Collision geometry (processed from groups)
        spawners = {},             -- Organized by type (player, wave, single)

        -- State management
        objects = {},              -- Interactive objects with state
        signals = {},              -- Active signal states
        mapBounds = {x=0,y=0,w=0,h=0}, -- World boundaries

        -- Rendering cache
        renderLayers = {}         -- Pre-sorted textures by layer
    }
    setmetatable(map, { __index = self })
    return map
end

function Map:load(mapPath)
    -- Store the map directory for texture loading
    self.mapDir = string.match(mapPath, "(.*/)")

    -- Load JSON configuration
    local jsonPath = mapPath .. ".json"
    if not love.filesystem.getInfo(jsonPath) then
        error("Map file not found: " .. jsonPath)
    end

    local jsonData = love.filesystem.read(jsonPath)
    self.data = require("dkjson").decode(jsonData) -- You'll need dkjson library

    -- Load associated Lua script
    local scriptPath = mapPath .. "_script.lua"
    if love.filesystem.getInfo(scriptPath) then
        self.script = love.filesystem.load(scriptPath)()
    else
        self.script = {} -- Empty script if none exists
    end

    -- Process geometry and set up collision polygons
    self:processGeometry()

    -- Organize spawners by type
    self:organizeSpawners()

    -- Load and cache textures
    self:loadTextures()

    -- Process interactive objects
    self:processObjects()
end

function Map:processGeometry()
    self.polygons = {}
    self.mapBounds = {x=math.huge, y=math.huge, w=-math.huge, h=-math.huge}

    -- Process general textures (background/foreground)
    if self.data.general then
        for key, generalTex in pairs(self.data.general) do
            if type(generalTex) == "table" and generalTex.texture then
                -- General textures use world coordinates directly (no offset)
                local absX = generalTex.position and generalTex.position[1] or 0
                local absY = generalTex.position and generalTex.position[2] or 0

                local textureEntry = {
                    name = key,
                    textureFile = generalTex.texture,
                    x = absX,
                    y = absY,
                    layer = generalTex.layer or 0,
                    size = generalTex.size, -- Support for custom size [width, height]
                    visible = true
                }

                table.insert(self.renderLayers, textureEntry)
            end
        end
    end

    for groupName, group in pairs(self.data.groups) do
        local originX, originY = group.origin[1], group.origin[2]

        -- Process collision polygons
        if group.collision then
            for polyIndex, poly in ipairs(group.collision) do
                -- Convert relative coordinates to absolute world coordinates
                local absPoly = {}
                for _, point in ipairs(poly) do
                    local x = originX + point[1]
                    local y = originY + point[2]
                    table.insert(absPoly, {x, y})

                    -- Update map bounds
                    self.mapBounds.x = math.min(self.mapBounds.x, x)
                    self.mapBounds.y = math.min(self.mapBounds.y, y)
                    self.mapBounds.w = math.max(self.mapBounds.w, x)
                    self.mapBounds.h = math.max(self.mapBounds.h, y)
                end
                
                -- Assign collision ID if mapping exists
                if group.collision_ids then
                    for id, index in pairs(group.collision_ids) do
                        if index == polyIndex then
                            absPoly.id = id
                            break
                        end
                    end
                end
                
                table.insert(self.polygons, absPoly)
            end
        end

        -- Process textures with layers
        if group.textures then
            for _, textureInfo in ipairs(group.textures) do
                local absX = originX + textureInfo.position[1]
                local absY = originY + textureInfo.position[2]

                local textureEntry = {
                    name = textureInfo.name,
                    textureFile = textureInfo.texture,
                    x = absX,
                    y = absY,
                    layer = textureInfo.layer,
                    size = textureInfo.size, -- Support for custom size [width, height]
                    hideArea = nil,
                    visible = true
                }

                -- Process hide area if specified
                if textureInfo.hide_area then
                    textureEntry.hideArea = {
                        x1 = originX + textureInfo.hide_area[1][1],
                        y1 = originY + textureInfo.hide_area[1][2],
                        x2 = originX + textureInfo.hide_area[2][1],
                        y2 = originY + textureInfo.hide_area[2][2],
                        x3 = originX + textureInfo.hide_area[3][1],
                        y3 = originY + textureInfo.hide_area[3][2],
                        x4 = originX + textureInfo.hide_area[4][1],
                        y4 = originY + textureInfo.hide_area[4][2]
                    }
                end

                table.insert(self.renderLayers, textureEntry)
            end
        end
    end

    -- Finalize map bounds
    self.mapBounds.w = self.mapBounds.w - self.mapBounds.x
    self.mapBounds.h = self.mapBounds.h - self.mapBounds.y

    -- Ensure minimum bounds if no geometry
    if self.mapBounds.w <= 0 then
        self.mapBounds = {x=0, y=0, w=1280, h=720} -- Default to screen size
    end

    -- Sort render layers by layer number
    table.sort(self.renderLayers, function(a, b) return a.layer < b.layer end)
end

function Map:organizeSpawners()
    self.spawners = {player={}, wave={}, single={}}

    if self.data.spawners then
        for spawnerId, spawner in pairs(self.data.spawners) do
            spawner.id = spawnerId
            
            -- Ensure the spawner type table exists
            if not self.spawners[spawner.type] then
                self.spawners[spawner.type] = {}
            end
            
            table.insert(self.spawners[spawner.type], spawner)
        end
    end
end

function Map:loadTextures()
    for _, layer in ipairs(self.renderLayers) do
        if not self.textures[layer.name] and layer.textureFile then
            local fullPath = layer.textureFile
            if self.mapDir then
                fullPath = self.mapDir .. layer.textureFile
            end
            self.textures[layer.name] = love.graphics.newImage(fullPath)
            layer.image = self.textures[layer.name]
        end
    end
end

function Map:processObjects()
    self.objects = {}

    for groupName, group in pairs(self.data.groups) do
        if group.objects then
            local originX, originY = group.origin[1], group.origin[2]

            for _, objData in ipairs(group.objects) do
                local object = {
                    id = objData.id,
                    type = objData.type,
                    trigger = objData.trigger,
                    collision_id = objData.collision_id,
                    target_map = objData.target_map,
                    remember = objData.remember,
                    spawn_x = objData.spawn_x,
                    spawn_y = objData.spawn_y,
                    position = {
                        x = originX + objData.position[1],
                        y = originY + objData.position[2]
                    },
                    state = {
                        active = true,
                        triggered = false,
                        health = 100,
                        open = false  -- For doors
                    }
                }
                self.objects[objData.id] = object
            end
        end
    end
end

function Map:getCollisionPolygons()
    return self.polygons
end

function Map:getSpawners(type)
    return self.spawners[type] or {}
end

function Map:getMapBounds()
    return self.mapBounds
end

function Map:update(dt, playerPos)
    if not self.data then return end

    -- Check trigger conditions
    self:checkTriggerConditions(playerPos)
end

function Map:checkTriggerConditions(playerPos)
    for _, obj in pairs(self.objects) do
        if obj.state.active then
            -- Check range-based triggers
            if obj.trigger.on_range then
                local distance = self:distanceToPlayer(obj.position, playerPos)
                if distance <= 100 then -- Default range
                    if obj.trigger.on_range and not obj.state.triggered then
                        self:executeTrigger(obj.trigger.on_range, obj, playerPos)
                        obj.state.triggered = true
                    end
                end
            end

            if obj.trigger.on_enter then
                local distance = self:distanceToPlayer(obj.position, playerPos)
                if distance <= 50 and not obj.state.triggered then
                    self:executeTrigger(obj.trigger.on_enter, obj, playerPos)
                    obj.state.triggered = true
                end
            end
        end
    end
end

function Map:executeTrigger(triggerName, object, playerPos)
    if self.script and self.script[triggerName] then
        -- Pass arguments to the script function
        self.script[triggerName]({
            position = object.position,
            player = playerPos,
            objectId = object.id
        }, {
            -- Provide limited game API access
            setTextureVisible = function(name, visible)
                self:setTextureVisible(name, visible)
            end,
            playSound = function(sound) end, -- Stub for now
            sendSignal = function(target, event, args)
                self:sendSignal(target, event, args)
            end,
            openShop = function()
                -- Access game manager through global or require
                local gameState = love.gameState
                if gameState and gameState.gameManager then
                    gameState.gameManager:setState("SHOP")
                    gameState.gameManager.shop:open()
                end
            end,
            toggleCollision = function(collisionId, enabled)
                self:toggleCollision(collisionId, enabled)
            end,
            getObject = function(objectId)
                return self.objects[objectId]
            end,
            loadMap = function(mapPath, remember, spawnX, spawnY)
                -- Access global loadMap function
                if loadMap then
                    loadMap(mapPath, remember, spawnX, spawnY)
                end
            end
        })
    end
end

function Map:sendSignal(targetId, event, args)
    local target = self.objects[targetId]
    if target and target.trigger[event] then
        self:executeTrigger(target.trigger[event], target, args)
    end
end

function Map:setTextureVisible(textureName, visible)
    for _, layer in ipairs(self.renderLayers) do
        if layer.name == textureName then
            layer.visible = visible
        end
    end
end

function Map:toggleCollision(collisionId, enabled)
    -- Find and toggle collision polygon by ID
    for i, poly in ipairs(self.polygons) do
        if poly.id == collisionId then
            poly.enabled = enabled
            return true
        end
    end
    return false
end

function Map:getCollisionPolygonsEnabled()
    -- Return only enabled collision polygons
    local enabled = {}
    for _, poly in ipairs(self.polygons) do
        if poly.enabled ~= false then  -- Default to enabled
            table.insert(enabled, poly)
        end
    end
    return enabled
end

function Map:draw(layerMin, layerMax)
    if not self.data then return end

    for _, layer in ipairs(self.renderLayers) do
        if layer.visible and layer.layer >= layerMin and layer.layer <= layerMax and layer.image then
            if layer.size then
                -- Draw with custom size
                love.graphics.draw(layer.image, layer.x, layer.y, 0, layer.size[1] / layer.image:getWidth(), layer.size[2] / layer.image:getHeight())
            else
                -- Draw at original size
                love.graphics.draw(layer.image, layer.x, layer.y)
            end
        end
    end
end

function Map:drawObjects()
    if not self.objects then return end
    
    for id, obj in pairs(self.objects) do
        if obj.state.active then
            -- Draw object based on type
            if obj.type == "chest" then
                -- Draw chest as a golden box
                love.graphics.setColor(0.8, 0.6, 0.2, 1)
                love.graphics.rectangle('fill', obj.position.x - 20, obj.position.y - 20, 40, 40)
                love.graphics.setColor(1, 0.8, 0.3, 1)
                love.graphics.rectangle('line', obj.position.x - 20, obj.position.y - 20, 40, 40)
                
                -- Draw interaction indicator
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.circle('line', obj.position.x, obj.position.y, 30)
                love.graphics.setColor(1, 1, 1, 1)
            elseif obj.type == "door" then
                -- Draw door - color depends on open/closed state
                local isOpen = obj.state.open
                if isOpen then
                    -- Open door - green and transparent
                    love.graphics.setColor(0.2, 0.8, 0.2, 0.5)
                else
                    -- Closed door - red and solid
                    love.graphics.setColor(0.8, 0.2, 0.2, 0.8)
                end
                love.graphics.rectangle('fill', obj.position.x - 10, obj.position.y - 30, 20, 60)
                
                -- Draw door frame
                love.graphics.setColor(0.4, 0.3, 0.2, 1)
                love.graphics.rectangle('line', obj.position.x - 10, obj.position.y - 30, 20, 60)
                
                -- Draw interaction indicator
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.circle('line', obj.position.x, obj.position.y, 35)
                love.graphics.setColor(1, 1, 1, 1)
            elseif obj.type == "portal" then
                -- Draw portal with animated effect
                local time = love.timer.getTime()
                local pulse = math.sin(time * 3) * 0.3 + 0.7
                
                -- Outer glow
                love.graphics.setColor(0.2, 0.6, 1, 0.3 * pulse)
                love.graphics.circle('fill', obj.position.x, obj.position.y, 50)
                
                -- Middle ring
                love.graphics.setColor(0.4, 0.8, 1, 0.6 * pulse)
                love.graphics.circle('fill', obj.position.x, obj.position.y, 35)
                
                -- Inner portal
                love.graphics.setColor(0.6, 1, 1, 0.9 * pulse)
                love.graphics.circle('fill', obj.position.x, obj.position.y, 25)
                
                -- Portal frame
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.circle('line', obj.position.x, obj.position.y, 40)
                love.graphics.circle('line', obj.position.x, obj.position.y, 30)
                
                -- Interaction indicator
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.circle('line', obj.position.x, obj.position.y, 55)
                love.graphics.setColor(1, 1, 1, 1)
            end
        end
    end
end

function Map:distanceToPlayer(pos1, pos2)
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    return math.sqrt(dx*dx + dy*dy)
end

function Map:unload()
    -- Clean up textures and data
    self.textures = {}
    self.polygons = {}
    self.spawners = {}
    self.renderLayers = {}
    self.objects = {}
    self.data = nil
    self.script = nil
end

return Map
