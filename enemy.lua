-- Enhanced Enemy module with multiple enemy types
local Enemy = {}

-- Enemy types
Enemy.TYPES = {
    ZOMBIE = {
        speed = 50,
        health = 30,
        damage = 10,
        score = 100,
        color = {0.3, 0.8, 0.3},
        scale = 0.5,
        attackSpeed = 1.0,  -- Attacks per second
        attackRange = 80, -- Increased from 50 to 80
        collisionBox = {
            width = 24,   -- Narrow horizontal hitbox
            height = 40,  -- Tall vertical hitbox
            offsetX = 0,  -- Centered horizontally
            offsetY = -4  -- Slightly higher (head level)
        },
        drops = {
            {type = "AMMO", chance = 1, amount = 5},
            {type = "MEDKIT", chance = 0.5, amount = 1}
        }
    },
    FAST_ZOMBIE = {
        speed = 120,
        health = 20,
        damage = 5,
        score = 150,
        color = {0.8, 0.8, 0.3},
        scale = 0.45,
        attackSpeed = 1.5,  -- Faster attacks
        attackRange = 70, -- Increased from 40 to 70
        collisionBox = {
            width = 20,   -- Narrow hitbox
            height = 35,  -- Short hitbox
            offsetX = 0,
            offsetY = -2
        },
        drops = {
            {type = "AMMO", chance = 1, amount = 3},
            {type = "MEDKIT", chance = 0.05, amount = 1}
        }
    },
    TANK_ZOMBIE = {
        speed = 30,
        health = 100,
        damage = 20,
        score = 300,
        color = {0.8, 0.3, 0.3},
        scale = 0.7,
        attackSpeed = 0.7,  -- Slower attacks
        attackRange = 90, -- Increased from 60 to 90
        collisionBox = {
            width = 35,   -- Wide hitbox
            height = 50,  -- Very tall hitbox
            offsetX = 0,
            offsetY = -2
        },
        drops = {
            {type = "AMMO", chance = 0.6, amount = 10},
            {type = "MEDKIT", chance = 0.3, amount = 1},
            {type = "WEAPON_UPGRADE", chance = 0.1, amount = 1}
        }
    }
}

function Enemy:new(x, y, enemyType)
    local type = enemyType or "ZOMBIE"
    local config = Enemy.TYPES[type]
    
    local enemy = {
        x = x or math.random(100, 1180),
        y = y or math.random(100, 620),
        width = 64,
        height = 64,
        speed = config.speed + (math.random(5,20)/10),
        angle = 0,
        currentFrame = math.random(0, 10),
        walkingFrameTime = 0,
        zombieFrameDuration = 0.1,
        attackFrameTime = 0,
        attackFrameDuration = 0.1,
        health = config.health,
        maxHealth = config.health,
        damage = config.damage,
        score = config.score,
        type = type,
        color = config.color,
        scale = config.scale,
        attackCooldown = 0,
        attackRange = config.attackRange,
        lastPlayerPos = {x = 0, y = 0},
        pathUpdateTimer = 0,
        isAttacking = false,
        attackTime = 0,
        attackDuration = 1.0 / config.attackSpeed,  -- Duration based on attack speed
        hasDealtDamage = false,
        attackSpeed = config.attackSpeed,
        DEBUG = false,  -- Disable debug output
        
        -- Pathfinding
        pathfinding = nil,
        path = nil,
        currentWaypoint = 1,
        pathfindingUpdateInterval = 0.5,  -- Update path every 0.5 seconds
        pathfindingTimer = 0,
        waypointReachDist = 20,  -- Distance to consider waypoint reached
        
        -- Smooth rotation
        targetAngle = 0,
        rotationSpeed = 8  -- Radians per second for rotation interpolation
    }
    setmetatable(enemy, { __index = self })
    return enemy
end

-- Helper function to interpolate angles with proper wrapping
local function lerpAngle(from, to, t)
    local diff = to - from
    -- Normalize to -pi to pi range
    while diff > math.pi do diff = diff - 2 * math.pi end
    while diff < -math.pi do diff = diff + 2 * math.pi end
    return from + diff * t
end

function Enemy:update(dt, player, pathfinding)
    self.walkingFrameTime = self.walkingFrameTime + dt + math.random() * 0.01
    self.attackCooldown = math.max(0, self.attackCooldown - dt)
    self.pathfindingTimer = self.pathfindingTimer + dt
    
    -- Store pathfinding reference
    if pathfinding then
        self.pathfinding = pathfinding
    end
    
    -- Calculate distance to player
    local ex, ey = self:getCenter()
    local px, py = player.x + player.width/2, player.y + player.height/2
    local dx = px - ex
    local dy = py - ey
    local dist = math.sqrt(dx*dx + dy*dy)
    
    -- Handle attacking state
    if self.isAttacking then
        self.attackTime = self.attackTime - dt
        self.attackFrameTime = self.attackFrameTime + dt
        
        -- Deal damage at the middle of the attack animation
        if self.attackTime <= self.attackDuration * 0.5 and not self.hasDealtDamage then
            self.hasDealtDamage = true
            return true  -- Signal that enemy can attack
        end
        
        if self.attackTime <= 0 then
            self.isAttacking = false
            self.hasDealtDamage = false
        end
    else
        -- Move towards player if not attacking and in range
        if dist > 0 and dist < 800 then
            -- Update pathfinding periodically OR if we don't have a path
            if self.pathfinding and (self.pathfindingTimer >= self.pathfindingUpdateInterval or not self.path) then
                self.pathfindingTimer = 0
                local newPath = self.pathfinding:findPath(ex, ey, px, py)
                
                if newPath then
                    self.path = self.pathfinding:simplifyPath(newPath)
                    self.currentWaypoint = 1
                end
                -- If pathfinding fails, keep old path if we have one
            end
            
            -- Follow path if available
            if self.path and #self.path > 0 then
                local waypoint = self.path[self.currentWaypoint]
                if waypoint then
                    local wdx = waypoint.x - ex
                    local wdy = waypoint.y - ey
                    local wdist = math.sqrt(wdx*wdx + wdy*wdy)
                    
                    if wdist < self.waypointReachDist then
                        -- Reached waypoint, move to next
                        self.currentWaypoint = self.currentWaypoint + 1
                        if self.currentWaypoint > #self.path then
                            -- Reached end of path, request new path immediately
                            self.path = nil
                            self.pathfindingTimer = self.pathfindingUpdateInterval -- Trigger immediate recalc
                        end
                    else
                        -- Set target angle towards waypoint
                        self.targetAngle = math.atan2(wdy, wdx)
                        
                        -- Move towards waypoint
                        self.x = self.x + (wdx/wdist) * self.speed * dt
                        self.y = self.y + (wdy/wdist) * self.speed * dt
                    end
                end
            else
                -- No path available - try pathfinding more frequently
                self.pathfindingTimer = self.pathfindingUpdateInterval * 0.5 -- Try again sooner
                
                -- Set target angle towards player when stuck
                self.targetAngle = math.atan2(dy, dx)
            end
        end
        
        -- Start attack if close enough and cooldown is ready
        if dist < self.attackRange and self.attackCooldown <= 0 then
            self.isAttacking = true
            self.attackTime = self.attackDuration
            self.attackFrameTime = 0
            self.attackCooldown = 1.0 / self.attackSpeed
            self.path = nil  -- Clear path when attacking
            
            -- Set target angle towards player when attacking
            self.targetAngle = math.atan2(dy, dx)
        end
    end
    
    -- Smoothly interpolate angle towards target
    local angleDiff = self.targetAngle - self.angle
    -- Normalize to -pi to pi range
    while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
    while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end
    
    -- Interpolate angle with rotation speed limit
    local maxRotation = self.rotationSpeed * dt
    if math.abs(angleDiff) < maxRotation then
        self.angle = self.targetAngle
    else
        self.angle = self.angle + math.min(maxRotation, math.max(-maxRotation, angleDiff))
    end
    
    return false
end

function Enemy:draw(assets, debug)
    love.graphics.setColor(self.color[1], self.color[2], self.color[3])
    love.graphics.push()
    love.graphics.translate(self.x + self.width/2, self.y + self.height/2)
    love.graphics.rotate(self.angle + math.pi/2)
    
    local img, imgWidth, imgHeight
    
    if self.isAttacking then
        -- Use attack animation
        local frame = math.floor(self.attackFrameTime / self.attackFrameDuration) % #assets.zombieAttackingImages + 1
        img = assets.zombieAttackingImages[frame]
        imgWidth = img:getWidth() * self.scale
        imgHeight = img:getHeight() * self.scale
    else
        -- Use walking animation
        local frame = math.floor(self.walkingFrameTime / self.zombieFrameDuration*(self.speed/50)) % #assets.zombieWalkingImages + 1
        img = assets.zombieWalkingImages[frame]
        imgWidth = img:getWidth() * self.scale
        imgHeight = img:getHeight() * self.scale
    end
    
    -- Center the texture properly
    love.graphics.draw(img, -imgWidth/2, -imgHeight/2, 0, self.scale, self.scale)
    love.graphics.pop()

    -- Health bar
    if self.health < self.maxHealth then
        local barWidth = 40
        local barHeight = 4
        local healthPercent = self.health / self.maxHealth
        
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', self.x + (self.width - barWidth)/2, self.y - 10, barWidth, barHeight)
        
        love.graphics.setColor(1 - healthPercent, healthPercent, 0, 1)
        love.graphics.rectangle('fill', self.x + (self.width - barWidth)/2, self.y - 10, barWidth * healthPercent, barHeight)
    end

    -- Debug visualization
    if debug then
        love.graphics.setColor(0, 0, 1, 0.5)
        love.graphics.rectangle('line', self.x, self.y, self.width, self.height)

        -- Bounding box visualization (collision box used for shooting)
        local boxX, boxY, boxW, boxH = self:getBoundingBox()
        love.graphics.setColor(1, 0, 1, 0.8)  -- Magenta for hitboxes
        love.graphics.rectangle('line', boxX, boxY, boxW, boxH)

        -- Attack range visualization
        love.graphics.setColor(1, 0, 0, 0.3)
        love.graphics.circle('line', self.x + self.width/2, self.y + self.height/2, self.attackRange)

        love.graphics.setColor(1, 1, 1)
    else
        love.graphics.setColor(1, 1, 1)
    end
end

function Enemy:takeDamage(amount)
    self.health = self.health - amount
    return self.health <= 0
end

function Enemy:getDrops()
    local config = Enemy.TYPES[self.type]
    local drops = {}

    print("grt drops")

    if config.drops then
        for _, drop in ipairs(config.drops) do
            if math.random() < drop.chance then
                table.insert(drops, {
                    type = drop.type,
                    amount = drop.amount
                })
                print("Enemy " .. self.type .. " dropped: " .. drop.type)
            end
        end
    end

    if #drops > 0 then
        print("Enemy " .. self.type .. " total drops: " .. #drops)
    end

    return drops
end

function Enemy:getCenter()
    return self.x + self.width/2, self.y + self.height/2
end

function Enemy:getBoundingBox()
    local config = Enemy.TYPES[self.type]
    local centerX, centerY = self:getCenter()

    -- Apply collision box offset from enemy center
    local boxX = centerX + (config.collisionBox.offsetX or 0) - config.collisionBox.width / 2
    local boxY = centerY + (config.collisionBox.offsetY or 0) - config.collisionBox.height / 2
    local boxWidth = config.collisionBox.width
    local boxHeight = config.collisionBox.height

    return boxX, boxY, boxWidth, boxHeight
end

function Enemy:getType()
    return self.type
end

function Enemy:getScore()
    return self.score
end

function Enemy:getDamage()
    return self.damage
end

function Enemy:isAlive()
    return self.health > 0
end

-- Utility function to get random enemy type with weighted probabilities
function Enemy.getRandomType()
    local rand = math.random()
    if rand < 0.6 then
        return "ZOMBIE"
    elseif rand < 0.85 then
        return "FAST_ZOMBIE"
    else
        return "TANK_ZOMBIE"
    end
end

return Enemy
