-- Particle effects system
local Particles = {}

function Particles:new()
    local particles = {
        systems = {},
        nextId = 1,
        -- Drawing layers
        LAYERS = {
            BEHIND_ENTITIES = "behind",
            ACROSS_ENTITIES = "across",
            ABOVE_ENTITIES = "above"
        }
    }
    setmetatable(particles, { __index = self })
    return particles
end

function Particles:createBloodSplat(x, y)
    local system = {
        id = self.nextId,
        x = x,
        y = y,
        particles = {},
        lifetime = 0.8,
        age = 0,
        active = true,
        layer = self.LAYERS.BEHIND_ENTITIES  -- Blood splats appear behind entities
    }
    
    -- Create blood particles
    for i = 1, 8 do
        local angle = math.random() * math.pi * 2
        local speed = math.random(20, 80)
        local size = math.random(3, 8)
        table.insert(system.particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            size = size,
            color = {0.8, 0.1, 0.1},
            lifetime = math.random(0.3, 0.8),
            age = 0
        })
    end
    
    self.nextId = self.nextId + 1
    table.insert(self.systems, system)
    return system.id
end

function Particles:createMuzzleFlash(x, y, angle)
    local system = {
        id = self.nextId,
        x = x,
        y = y,
        particles = {},
        lifetime = 0.2,
        age = 0,
        active = true,
        layer = self.LAYERS.ACROSS_ENTITIES  -- Muzzle flash appears at weapon level
    }
    
    -- Calculate emission point that rotates with player
    -- Offset from player center: 30px up and 5px right relative to player's facing direction
    -- Adjust for the 90° offset in the game's coordinate system
    local adjustedAngle = angle - math.pi/2  -- Compensate for 90° offset
    local offsetX = math.cos(adjustedAngle) * -10 - math.sin(adjustedAngle) * 85
    local offsetY = math.sin(adjustedAngle) * -10 + math.cos(adjustedAngle) * 85
    
    offsetX = 0
    offsetY = 0

    -- Create flash particles
    for i = 1, 12 do
        local particleAngle = angle + (math.random() - 0.5) * 0.5
        local speed = math.random(30, 100)
        local size = math.random(2, 6)
        table.insert(system.particles, {
            x = x + offsetX,  -- Rotated emission point
            y = y + offsetY,  -- Rotated emission point
            vx = math.cos(particleAngle) * speed,
            vy = math.sin(particleAngle) * speed,
            size = size,
            color = {1.0, 0.8, 0.2},
            lifetime = math.random(0.1, 0.3),
            age = 0
        })
    end
    
    self.nextId = self.nextId + 1
    table.insert(self.systems, system)
    return system.id
end

function Particles:createDashTrail(player)
    local system = {
        id = self.nextId,
        x = player.x + player.width/2,
        y = player.y + player.height/2,
        particles = {},
        lifetime = 0.5,
        age = 0,
        active = true,
        layer = self.LAYERS.ACROSS_ENTITIES  -- Dash trail appears around player
    }
    
    -- Create trail particles
    for i = 1, 6 do
        local offsetX = (math.random() - 0.5) * 20
        local offsetY = (math.random() - 0.5) * 20
        local size = math.random(2, 5)
        table.insert(system.particles, {
            x = player.x + player.width/2 + offsetX,
            y = player.y + player.height/2 + offsetY,
            vx = 0,
            vy = 0,
            size = size,
            color = {0.2, 0.6, 1.0},
            lifetime = math.random(0.2, 0.5),
            age = 0
        })
    end
    
    self.nextId = self.nextId + 1
    table.insert(self.systems, system)
    return system.id
end

function Particles:createDashImpact(x, y)
    local system = {
        id = self.nextId,
        x = x,
        y = y,
        particles = {},
        lifetime = 0.4,
        age = 0,
        active = true,
        layer = self.LAYERS.ACROSS_ENTITIES  -- Dash impact appears at entity level
    }
    
    -- Create impact particles (blue/white energy burst)
    for i = 1, 15 do
        local angle = math.random() * math.pi * 2
        local speed = math.random(50, 150)
        local size = math.random(3, 8)
        local colorChoice = math.random()
        local color = colorChoice > 0.5 and {0.2, 0.6, 1.0} or {0.8, 0.9, 1.0}  -- Blue or light blue/white
        
        table.insert(system.particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            size = size,
            color = color,
            lifetime = math.random(0.2, 0.4),
            age = 0
        })
    end
    
    self.nextId = self.nextId + 1
    table.insert(self.systems, system)
    return system.id
end

function Particles:createPickupEffect(x, y, color)
    local system = {
        id = self.nextId,
        x = x,
        y = y,
        particles = {},
        lifetime = 1.0,
        age = 0,
        active = true,
        layer = self.LAYERS.ABOVE_ENTITIES  -- Pickup effects appear above everything
    }

    -- Create pickup particles
    for i = 1, 15 do
        local angle = math.random() * math.pi * 2
        local speed = math.random(10, 40)
        local size = math.random(2, 4)
        table.insert(system.particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            size = size,
            color = color or {0.2, 0.8, 0.2},
            lifetime = math.random(0.5, 1.0),
            age = 0
        })
    end

    self.nextId = self.nextId + 1
    table.insert(self.systems, system)
    return system.id
end

function Particles:createBulletTracer(startX, startY, angle, distance, color)
    local system = {
        id = self.nextId,
        x = startX,
        y = startY,
        particles = {},
        lifetime = 0.3,  -- Short duration for quick visibility
        age = 0,
        active = true,
        layer = self.LAYERS.BEHIND_ENTITIES,  -- Bullet tracers appear behind entities
        tracerAngle = angle,
        tracerDistance = distance,
        tracerColor = color or {1.0, 0.8, 0.2}  -- Default yellow/orange
    }

    -- Single "particle" that represents the tracer line
    table.insert(system.particles, {
        x = startX,
        y = startY,
        vx = 0,
        vy = 0,
        size = 0,  -- Not used for line drawing
        color = system.tracerColor,
        lifetime = system.lifetime,
        age = 0,
        isTracer = true  -- Special flag for tracer particles
    })

    self.nextId = self.nextId + 1
    table.insert(self.systems, system)
    return system.id
end

function Particles:createChainLightning(startX, startY, endX, endY)
    local system = {
        id = self.nextId,
        x = startX,
        y = startY,
        particles = {},
        lifetime = 0.2,  -- Very short duration for lightning effect
        age = 0,
        active = true,
        layer = self.LAYERS.ACROSS_ENTITIES,  -- Lightning appears at entity level
        chainEndX = endX,
        chainEndY = endY
    }

    -- Create multiple lightning segments for a jagged effect
    local segments = 5
    local dx = (endX - startX) / segments
    local dy = (endY - startY) / segments
    
    for i = 1, segments do
        local segmentStartX = startX + dx * (i - 1)
        local segmentStartY = startY + dy * (i - 1)
        local segmentEndX = startX + dx * i
        local segmentEndY = startY + dy * i
        
        -- Add some randomness to make it look like lightning
        local offsetX = (math.random() - 0.5) * 20
        local offsetY = (math.random() - 0.5) * 20
        
        table.insert(system.particles, {
            x = segmentStartX,
            y = segmentStartY,
            segmentEndX = segmentEndX + offsetX,
            segmentEndY = segmentEndY + offsetY,
            size = 2,
            color = {0.5, 0.8, 1.0},  -- Electric blue color
            lifetime = system.lifetime,
            age = 0,
            isChainLightning = true
        })
    end

    self.nextId = self.nextId + 1
    table.insert(self.systems, system)
    return system.id
end

function Particles:update(dt)
    -- Update all particle systems
    for i = #self.systems, 1, -1 do
        local system = self.systems[i]
        system.age = system.age + dt
        
        -- Update particles in this system
        for j = #system.particles, 1, -1 do
            local particle = system.particles[j]
            particle.age = particle.age + dt
            
            -- Update position (only for particles that have velocity)
            if particle.vx and particle.vy then
                particle.x = particle.x + particle.vx * dt
                particle.y = particle.y + particle.vy * dt
                
                -- Apply gravity to blood particles
                if particle.color[1] > 0.7 and particle.color[2] < 0.2 then
                    particle.vy = particle.vy + 100 * dt
                end
            end
            
            -- Remove dead particles
            if particle.age >= particle.lifetime then
                table.remove(system.particles, j)
            end
        end
        
        -- Remove empty or expired systems
        if system.age >= system.lifetime or #system.particles == 0 then
            table.remove(self.systems, i)
        end
    end
end

function Particles:draw()
    for _, system in ipairs(self.systems) do
        for _, particle in ipairs(system.particles) do
            local alpha = 1 - (particle.age / particle.lifetime)
            love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)

            if particle.isTracer then
                -- Draw tracer line instead of circle
                local endX = system.x + math.cos(system.tracerAngle) * system.tracerDistance
                local endY = system.y + math.sin(system.tracerAngle) * system.tracerDistance
                love.graphics.setLineWidth(2)
                love.graphics.line(system.x, system.y, endX, endY)
                love.graphics.setLineWidth(1)  -- Reset line width
            elseif particle.isChainLightning then
                -- Draw chain lightning segment
                local alpha = 1 - (particle.age / particle.lifetime)
                love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)
                love.graphics.setLineWidth(3)
                love.graphics.line(particle.x, particle.y, particle.segmentEndX, particle.segmentEndY)
                love.graphics.setLineWidth(1)
            else
                -- Draw regular particle as circle
                love.graphics.circle('fill', particle.x, particle.y, particle.size)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw particles that appear behind entities (bullet tracers, blood)
function Particles:drawBehindEntities()
    for _, system in ipairs(self.systems) do
        if system.layer == self.LAYERS.BEHIND_ENTITIES then
            for _, particle in ipairs(system.particles) do
                local alpha = 1 - (particle.age / particle.lifetime)
                love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)

                if particle.isTracer then
                    local endX = system.x + math.cos(system.tracerAngle) * system.tracerDistance
                    local endY = system.y + math.sin(system.tracerAngle) * system.tracerDistance
                    love.graphics.setLineWidth(2)
                    love.graphics.line(system.x, system.y, endX, endY)
                    love.graphics.setLineWidth(1)
                else
                    love.graphics.circle('fill', particle.x, particle.y, particle.size)
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw particles that appear at entity level (muzzle flash, dash trail)
function Particles:drawAcrossEntities()
    for _, system in ipairs(self.systems) do
        if system.layer == self.LAYERS.ACROSS_ENTITIES then
            for _, particle in ipairs(system.particles) do
                local alpha = 1 - (particle.age / particle.lifetime)
                love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)

                if particle.isTracer then
                    local endX = system.x + math.cos(system.tracerAngle) * system.tracerDistance
                    local endY = system.y + math.sin(system.tracerAngle) * system.tracerDistance
                    love.graphics.setLineWidth(2)
                    love.graphics.line(system.x, system.y, endX, endY)
                    love.graphics.setLineWidth(1)
                else
                    love.graphics.circle('fill', particle.x, particle.y, particle.size)
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw particles that appear above entities (pickup effects)
function Particles:drawAboveEntities()
    for _, system in ipairs(self.systems) do
        if system.layer == self.LAYERS.ABOVE_ENTITIES then
            for _, particle in ipairs(system.particles) do
                local alpha = 1 - (particle.age / particle.lifetime)
                love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], alpha)

                if particle.isTracer then
                    local endX = system.x + math.cos(system.tracerAngle) * system.tracerDistance
                    local endY = system.y + math.sin(system.tracerAngle) * system.tracerDistance
                    love.graphics.setLineWidth(2)
                    love.graphics.line(system.x, system.y, endX, endY)
                    love.graphics.setLineWidth(1)
                else
                    love.graphics.circle('fill', particle.x, particle.y, particle.size)
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Particles:clear()
    self.systems = {}
end

return Particles
