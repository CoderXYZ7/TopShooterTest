-- Particle effects system
local Particles = {}

function Particles:new()
    local particles = {
        systems = {},
        nextId = 1
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
        active = true
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
        active = true
    }
    
    -- Calculate emission point that rotates with player
    -- Offset from player center: 30px up and 5px right relative to player's facing direction
    -- Adjust for the 90° offset in the game's coordinate system
    local adjustedAngle = angle - math.pi/2  -- Compensate for 90° offset
    local offsetX = math.cos(adjustedAngle) * -10 - math.sin(adjustedAngle) * 85
    local offsetY = math.sin(adjustedAngle) * -10 + math.cos(adjustedAngle) * 85
    
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
        active = true
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

function Particles:createPickupEffect(x, y, color)
    local system = {
        id = self.nextId,
        x = x,
        y = y,
        particles = {},
        lifetime = 1.0,
        age = 0,
        active = true
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

function Particles:update(dt)
    -- Update all particle systems
    for i = #self.systems, 1, -1 do
        local system = self.systems[i]
        system.age = system.age + dt
        
        -- Update particles in this system
        for j = #system.particles, 1, -1 do
            local particle = system.particles[j]
            particle.age = particle.age + dt
            
            -- Update position
            particle.x = particle.x + particle.vx * dt
            particle.y = particle.y + particle.vy * dt
            
            -- Apply gravity to blood particles
            if system.particles[j].color[1] > 0.7 and system.particles[j].color[2] < 0.2 then
                particle.vy = particle.vy + 100 * dt
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
            love.graphics.circle('fill', particle.x, particle.y, particle.size)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Particles:clear()
    self.systems = {}
end

return Particles
