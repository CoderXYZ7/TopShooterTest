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
        DEBUG = false  -- Disable debug output
    }
    setmetatable(enemy, { __index = self })
    return enemy
end

function Enemy:update(dt, player)
    self.walkingFrameTime = self.walkingFrameTime + dt + math.random() * 0.01
    self.attackCooldown = math.max(0, self.attackCooldown - dt)
    
    -- Always use current player position for accurate tracking
    local dx = player.x - self.x
    local dy = player.y - self.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    -- Face the player
    self.angle = math.atan2(dy, dx)
    
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
            self.x = self.x + (dx/dist) * self.speed * dt
            self.y = self.y + (dy/dist) * self.speed * dt
        end
        
        -- Start attack if close enough and cooldown is ready
        if dist < self.attackRange and self.attackCooldown <= 0 then
            self.isAttacking = true
            self.attackTime = self.attackDuration
            self.attackFrameTime = 0
            self.attackCooldown = 1.0 / self.attackSpeed  -- Cooldown based on attack speed
        end
        
        -- Debug: Show attack status in console
        if self.DEBUG and math.random() < 0.01 then  -- Only print occasionally to avoid spam
            print(string.format("Enemy %s: dist=%.1f, range=%.1f, cooldown=%.1f, canAttack=%s", 
                               self.type, dist, self.attackRange, self.attackCooldown,
                               tostring(dist < self.attackRange and self.attackCooldown <= 0)))
        end
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
        local frame = math.floor(self.walkingFrameTime / self.zombieFrameDuration) % #assets.zombieWalkingImages + 1
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
