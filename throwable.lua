-- Throwable module for physics-based projectiles
local Throwable = {}

-- Throwable types with different properties
Throwable.TYPES = {
    GRENADE = {
        name = "Fragmentation Grenade",
        fuseTime = 3.0,           -- Time before explosion in seconds
        explosionRadius = 150,     -- Explosion damage radius
        explosionDamage = 80,     -- Base explosion damage
        throwForce = 400,         -- Initial throw velocity
        gravity = 0,              -- No gravity for top-down view
        drag = 0.98,              -- Air resistance for realistic slowdown
        bounceDamping = 0.6,      -- Energy retained on bounce (0.6 = 60% retained)
        maxBounces = 2,           -- Maximum bounces before coming to rest
        trailColor = {1.0, 0.8, 0.2},  -- Yellow/orange trail
        explosionColor = {1.0, 0.3, 0.1},  -- Orange explosion
        icon = "grenade_icon",
        description = "Explosive grenade with 3-second fuse"
    },
    MOLOTOV = {
        name = "Molotov Cocktail",
        fuseTime = 2.0,
        explosionRadius = 60,
        explosionDamage = 15,
        throwForce = 350,
        gravity = 0,              -- No gravity for top-down view
        drag = 0.98,
        bounceDamping = 0.4,
        maxBounces = 1,
        trailColor = {1.0, 0.4, 0.1},  -- Red/orange trail
        explosionColor = {1.0, 0.2, 0.1},  -- Red fire
        icon = "molotov_icon",
        description = "Fire grenade that creates burning area",
        createsFire = true,  -- Special property for fire creation
        fireDuration = 5.0,   -- How long the fire burns
        fireDamagePerSecond = 10  -- Damage per second from fire
    }
}

function Throwable:new(throwableType, x, y, angle, throwPower)
    local config = Throwable.TYPES[throwableType]
    if not config then
        error("Unknown throwable type: " .. tostring(throwableType))
    end

    local throwable = {
        -- Position and physics
        x = x,
        y = y,
        vx = math.cos(angle) * config.throwForce * throwPower,
        vy = math.sin(angle) * config.throwForce * throwPower,
        gravity = config.gravity,
        drag = config.drag,

        -- Properties
        type = throwableType,
        config = config,

        -- State
        isActive = true,
        hasExploded = false,
        creationTime = love.timer.getTime(),
        bounces = 0,

        -- Visual
        rotation = 0,
        rotationSpeed = 0,

        -- Collision
        radius = 8,  -- Collision radius
        restitution = config.bounceDamping
    }

    setmetatable(throwable, { __index = self })
    return throwable
end

function Throwable:update(dt, collision, enemies, particles)
    if not self.isActive or self.hasExploded then
        return false
    end

    local currentTime = love.timer.getTime()

    -- Check if fuse has expired (explode)
    if currentTime - self.creationTime >= self.config.fuseTime then
        self:explode(enemies, particles)
        return false
    end

    -- Update physics
    local oldX, oldY = self.x, self.y

    -- Apply gravity
    self.vy = self.vy + self.gravity * dt

    -- Apply drag
    self.vx = self.vx * math.pow(self.drag, dt * 60)  -- Scale drag with framerate
    self.vy = self.vy * math.pow(self.drag, dt * 60)

    -- Update rotation based on velocity
    self.rotationSpeed = math.sqrt(self.vx * self.vx + self.vy * self.vy) * 0.01
    self.rotation = self.rotation + self.rotationSpeed * dt

    -- Update position
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- Handle collisions with map geometry and enemies
    if collision then
        local collided = false

        -- Create a temporary entity-like object for collision checking
        local entity = {
            x = self.x - self.radius,
            y = self.y - self.radius,
            width = self.radius * 2,
            height = self.radius * 2
        }

        -- Check collision with map polygons
        if collision:updateEntityMapCollision(entity) then
            collided = true
        end

        -- Handle boundary collisions
        if self.x < 0 or self.x > love.graphics.getWidth() or
           self.y < 0 or self.y > love.graphics.getHeight() then
            collided = true
        end

        if collided then
            self:bounce(oldX, oldY)
        end
    end

    -- Check collision with enemies
    if enemies then
        self:checkEnemyCollisions(enemies)
    end

    return true
end

function Throwable:bounce(oldX, oldY)
    -- Simple bounce logic - reflect velocity
    local tempVx = self.vx
    local tempVy = self.vy

    -- For simplicity, bounce off horizontal/vertical surfaces
    -- In a more advanced implementation, you'd calculate the normal of the collision surface
    if self.x <= 0 or self.x >= love.graphics.getWidth() then
        self.vx = -self.vx * self.restitution
        self.x = oldX  -- Restore position
    end

    if self.y <= 0 or self.y >= love.graphics.getHeight() then
        self.vy = -self.vy * self.restitution
        self.y = oldY  -- Restore position
    end

    -- Reduce velocity due to energy loss
    self.vx = self.vx * self.restitution
    self.vy = self.vy * self.restitution

    -- Count bounces
    self.bounces = self.bounces + 1

    -- Stop bouncing if too many bounces or velocity too low
    if self.bounces >= self.config.maxBounces or
       math.sqrt(self.vx * self.vx + self.vy * self.vy) < 50 then
        self.vx = 0
        self.vy = 0
        self.rotationSpeed = 0
    end
end

function Throwable:explode(enemies, particles)
    if self.hasExploded then
        return
    end

    self.hasExploded = true
    self.isActive = false

    -- Create explosion effect
    if particles then
        self:createExplosionEffect(particles)
    end

    -- Damage enemies in radius
    self:damageEnemiesInRadius(enemies)

    -- Special effects for different throwable types
    if self.config.createsFire then
        self:createFireArea(particles, enemies)
    end
end

function Throwable:createExplosionEffect(particles)
    if self.type == "MOLOTOV" then
        -- Create fiery explosion for Molotov (60px radius)
        self:createMolotovExplosion(particles)
    elseif self.type == "GRENADE" then
        -- Create fragment cloud for Grenade (150px radius)
        self:createGrenadeExplosion(particles)
    end
end

function Throwable:createMolotovExplosion(particles)
    -- Create intense fire explosion covering the full radius (60px)
    local numParticles = 35  -- More particles for bigger effect
    local radius = self.config.explosionRadius

    for i = 1, numParticles do
        -- Distribute particles across the explosion radius
        local distance = math.random() * radius
        local angle = math.random() * math.pi * 2

        local px = self.x + math.cos(angle) * distance
        local py = self.y + math.sin(angle) * distance

        -- Create fire particle system at this position
        particles:createFireEffect(px, py, 0.8)  -- Shorter duration for explosion effect
    end

    -- Add central fire burst
    particles:createFireEffect(self.x, self.y, 2.0)
end

function Throwable:createGrenadeExplosion(particles)
    -- Create fragment cloud covering the full radius (150px)
    local numParticles = 50  -- Lots of fragments
    local radius = self.config.explosionRadius

    for i = 1, numParticles do
        -- Distribute fragments across the explosion radius
        local distance = math.random() * radius * 0.7  -- Concentrate towards center
        local angle = math.random() * math.pi * 2

        local px = self.x + math.cos(angle) * distance
        local py = self.y + math.sin(angle) * distance

        -- Create fragment particle system using the existing particle creation methods
        -- Create multiple small explosion effects to simulate fragments
        particles:createFireImpact(px, py)
    end

    -- Add central bright flash using multiple fire impacts
    for i = 1, 8 do
        local angle = (i / 8) * math.pi * 2
        local distance = math.random(20, 40)
        local px = self.x + math.cos(angle) * distance
        local py = self.y + math.sin(angle) * distance
        particles:createFireImpact(px, py)
    end
end

function Throwable:damageEnemiesInRadius(enemies)
    for _, enemy in ipairs(enemies) do
        local ex, ey = enemy:getCenter()
        local dx = ex - self.x
        local dy = ey - self.y
        local distance = math.sqrt(dx * dx + dy * dy)

        if distance <= self.config.explosionRadius and distance > 0 then
            -- Calculate damage falloff based on distance
            local damageFalloff = 1 - (distance / self.config.explosionRadius)
            local damage = math.floor(self.config.explosionDamage * damageFalloff)

            -- Apply damage
            if enemy:takeDamage(damage) then
                -- Enemy died from explosion
                -- Handle death effects, drops, etc. (this would be handled by main game loop)
            end
        end
    end
end

function Throwable:createFireArea(particles, enemies)
    -- Create a persistent fire area that damages enemies who walk through it
    if particles then
        -- Create the initial explosion fire effect
        particles:createFireEffect(self.x, self.y, self.config.fireDuration)

        -- Create a fire area hazard that persists and damages enemies who enter it
        self:createPersistentFireArea(particles, enemies)
    end

    -- Apply immediate fire damage to enemies in the initial explosion
    if enemies then
        for _, enemy in ipairs(enemies) do
            local ex, ey = enemy:getCenter()
            local dx = ex - self.x
            local dy = ey - self.y
            local distance = math.sqrt(dx * dx + dy * dy)

            -- Apply fire to enemies within the explosion radius
            if distance <= self.config.explosionRadius and distance > 0 then
                -- Calculate fire damage (reduced from explosion damage)
                local fireDamagePerSecond = self.config.fireDamagePerSecond or 15
                local fireDuration = self.config.fireDuration or 5.0

                -- Set enemy on fire
                enemy:setOnFire(fireDamagePerSecond, fireDuration, particles, false)
            end
        end
    end
end

function Throwable:createPersistentFireArea(particles, enemies)
    -- Create a fire area that persists for several seconds and damages enemies who enter it
    local fireArea = {
        x = self.x,
        y = self.y,
        radius = self.config.explosionRadius,
        duration = 3.0,  -- Fire area lasts 3 seconds
        creationTime = love.timer.getTime(),
        isActive = true,
        damagePerSecond = self.config.fireDamagePerSecond or 15,
        fireDuration = 3.0,  -- How long enemies burn when they enter the area
        color = {1.0, 0.3, 0.1, 0.3},  -- Semi-transparent fire area
        particleId = nil
    }

    -- Create persistent fire particle effect
    if particles then
        fireArea.particleId = particles:createFireEffect(self.x, self.y, fireArea.duration)
    end

    -- Add to game state's fire areas (we'll need to modify main.lua to handle this)
    return fireArea
end

function Throwable:draw()
    if not self.isActive then
        return
    end

    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.rotation)

    -- Draw throwable as a simple circle for now
    love.graphics.setColor(self.config.trailColor)
    love.graphics.circle('fill', 0, 0, self.radius)

    -- Draw simple highlight
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.circle('fill', -2, -2, self.radius * 0.3)

    love.graphics.pop()
end

function Throwable:getPosition()
    return self.x, self.y
end

function Throwable:isExpired()
    return not self.isActive
end

function Throwable:checkEnemyCollisions(enemies)
    for _, enemy in ipairs(enemies) do
        -- Get enemy collision box
        local ex, ey = enemy:getCenter()
        local ew, eh = 32, 32  -- Default enemy size if getBoundingBox not available

        -- Try to get proper bounding box
        if enemy.getBoundingBox then
            local boxX, boxY, boxW, boxH = enemy:getBoundingBox()
            ex, ey = enemy:getCenter()  -- Reset to center
            ew, eh = boxW, boxH
        end

        -- Calculate distance between throwable and enemy center
        local dx = ex - self.x
        local dy = ey - self.y
        local distance = math.sqrt(dx * dx + dy * dy)

        -- Minimum distance for collision (throwable radius + enemy collision radius)
        local minDistance = self.radius + (ew / 2)

        -- Check if collision occurred
        if distance < minDistance and distance > 0 then
            -- Calculate collision response
            local nx = dx / distance  -- Normal vector
            local ny = dy / distance

            -- Reflect velocity based on collision normal
            local dotProduct = self.vx * nx + self.vy * ny
            self.vx = self.vx - 2 * dotProduct * nx
            self.vy = self.vy - 2 * dotProduct * ny

            -- Apply energy loss from collision
            self.vx = self.vx * 0.8
            self.vy = self.vy * 0.8

            -- Move throwable outside of enemy collision box
            local pushDistance = minDistance - distance + 2
            self.x = self.x - nx * pushDistance
            self.y = self.y - ny * pushDistance

            -- Add some randomness to the bounce for more realistic physics
            local randomAngle = (math.random() - 0.5) * math.pi * 0.3
            local cosRandom = math.cos(randomAngle)
            local sinRandom = math.sin(randomAngle)

            local newVx = self.vx * cosRandom - self.vy * sinRandom
            local newVy = self.vx * sinRandom + self.vy * cosRandom

            self.vx = newVx * 0.9
            self.vy = newVy * 0.9

            -- Different behavior based on throwable type
            if self.type == "GRENADE" then
                -- Fragmentation grenades bounce off enemies (more tactical)
                -- Just bounce and continue, don't explode
                return true  -- Signal that collision occurred
            elseif self.type == "MOLOTOV" then
                -- Molotov cocktails explode on enemy contact
                self:explode(enemies, nil)  -- Pass enemies but no particles (will be handled by main loop)
                return true  -- Signal that collision occurred
            end
        end
    end

    return false
end

-- Utility function to get all throwable types
function Throwable.getAllTypes()
    local types = {}
    for key, _ in pairs(Throwable.TYPES) do
        table.insert(types, key)
    end
    return types
end

return Throwable
