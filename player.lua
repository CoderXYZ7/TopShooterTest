-- Enhanced Player module with weapon system
local Player = {}
local Weapons = require('weapons')

function Player:new()
    local player = {
        x = 640,
        y = 360,
        width = 64,
        height = 64,
        speed = 300,  -- Increased speed
        angle = 0,
        health = 100,
        maxHealth = 100,
        invulnerable = false,
        invulnerableTime = 0,
        dashCooldown = 0,
        dashDuration = 0,
        isDashing = false,
        dashSpeed = 600,
        walkingFrameDuration = 0.08,
        walkingFrameTime = 0,
        currentWeapon = Weapons:new("BOLT_ACTION"),  -- Start with bolt action
        weaponSwitchCooldown = 0,
        lastShotTime = 0,
        isShooting = false,
        shootingTime = 0,
        shootingDuration = 0.3,  -- Duration of shooting animation
        shootingCurrentFrame = 1,
        -- Ammo inventory
        ammoInventory = {
            [Weapons.AMMO_TYPES.AMMO_9MM] = 60,  -- Start with 60 9mm rounds
            [Weapons.AMMO_TYPES.AMMO_3006] = 20   -- Start with 20 .30-06 rounds
        },
        -- Weapon inventory to preserve weapon states
        weaponInventory = {}
    }
    setmetatable(player, { __index = self })
    return player
end

function Player:update(dt, assets)
    local currentTime = love.timer.getTime()
    
    -- Update weapon reload with inventory
    self.currentWeapon:updateReload(dt, self.ammoInventory)
    
    -- Handle weapon switching
    self.weaponSwitchCooldown = math.max(0, self.weaponSwitchCooldown - dt)
    
    -- Weapon switching keys
    if self.weaponSwitchCooldown <= 0 then
        if love.keyboard.isDown('1') then
            self:switchWeapon("BOLT_ACTION")
            self.weaponSwitchCooldown = 0.5
        elseif love.keyboard.isDown('2') then
            self:switchWeapon("SEMI_AUTO_PISTOL")
            self.weaponSwitchCooldown = 0.5
        elseif love.keyboard.isDown('3') then
            self:switchWeapon("SMG")
            self.weaponSwitchCooldown = 0.5
        end
    end

    -- Handle invulnerability
    if self.invulnerable then
        self.invulnerableTime = self.invulnerableTime - dt
        if self.invulnerableTime <= 0 then
            self.invulnerable = false
        end
    end

    -- Handle dashing
    if self.isDashing then
        self.dashDuration = self.dashDuration - dt
        if self.dashDuration <= 0 then
            self.isDashing = false
        end
    else
        self.dashCooldown = math.max(0, self.dashCooldown - dt)
    end

    -- Weapon-specific movement restrictions
    local canMove = true
    local canAim = true
    
    -- Check if currently shooting (during shooting animation)
    local isShooting = self.isShooting
    
    -- Apply weapon-specific restrictions from weapon definitions
    if isShooting then
        local weaponType = self.currentWeapon.type
        local weaponConfig = Weapons.TYPES[weaponType]
        canMove = weaponConfig.canMoveWhileShooting
        canAim = weaponConfig.canAimWhileShooting
    end

    -- Movement with dash and weapon restrictions
    local moved = false
    local currentSpeed = self.isDashing and self.dashSpeed or self.speed
    
    if canMove then
        if love.keyboard.isDown('w') or love.keyboard.isDown('up') then
            self.y = self.y - currentSpeed * dt
            moved = true
        end
        if love.keyboard.isDown('s') or love.keyboard.isDown('down') then
            self.y = self.y + currentSpeed * dt
            moved = true
        end
        if love.keyboard.isDown('a') or love.keyboard.isDown('left') then
            self.x = self.x - currentSpeed * dt
            moved = true
        end
        if love.keyboard.isDown('d') or love.keyboard.isDown('right') then
            self.x = self.x + currentSpeed * dt
            moved = true
        end
    end

    -- Dash ability
    if love.keyboard.isDown('space') and not self.isDashing and self.dashCooldown <= 0 then
        self.isDashing = true
        self.dashDuration = 0.2
        self.dashCooldown = 1.5
        self.invulnerable = true
        self.invulnerableTime = 0.2
    end

    -- Reload weapon with inventory check
    if love.keyboard.isDown('r') and not self.currentWeapon.isReloading then
        self.currentWeapon:startReload(self.ammoInventory)
    end

    -- Update walking time only if moving
    if moved then
        self.walkingFrameTime = self.walkingFrameTime + dt
    end

    -- Aiming (world space) with weapon restrictions
    if canAim then
        local ww, wh = love.graphics.getDimensions()
        local camx = ww/2 - self.x - self.width/2
        local camy = wh/2 - self.y - self.height/2
        local mouseWorldX = love.mouse.getX() - camx
        local mouseWorldY = love.mouse.getY() - camy
        self.angle = math.atan2(mouseWorldY - (self.y + self.height/2), mouseWorldX - (self.x + self.width/2))
    end

    -- Shooting with weapon system
    if love.mouse.isDown(1) and self.currentWeapon:canShoot(currentTime) then
        if self.currentWeapon:shoot(currentTime) then
            self.lastShotTime = currentTime
            self.isShooting = true
            self.shootingTime = 0
            self.shootingCurrentFrame = 1
            return true  -- Signal that player shot
        end
    end
    
    -- Update shooting animation
    if self.isShooting then
        self.shootingTime = self.shootingTime + dt
        self.shootingCurrentFrame = self.shootingCurrentFrame + dt / 0.05  -- Frame rate for shooting animation
        
        if self.shootingTime >= self.shootingDuration then
            self.isShooting = false
        end
    end

    -- Keep player in bounds
    local ww, wh = love.graphics.getDimensions()
    self.x = math.max(0, math.min(ww - self.width, self.x))
    self.y = math.max(0, math.min(wh - self.height, self.y))
    
    return false
end

function Player:draw(assets, debug)
    -- Draw player with invulnerability flash
    if not self.invulnerable or math.floor(love.timer.getTime() * 10) % 2 == 0 then
        love.graphics.setColor(1, 1, 1)
        love.graphics.push()
        love.graphics.translate(self.x + self.width/2, self.y + self.height/2)
        love.graphics.rotate(self.angle + math.pi/2)
        
        -- Use shooting animation when shooting, otherwise walking animation
        if self.isShooting then
            local frame = math.floor(self.shootingCurrentFrame) % #assets.soldierShootingImages + 1
            love.graphics.draw(assets.soldierShootingImages[frame], -32, -90, 0, 0.5, 0.5)
        else
            local walkingFrameIndex = math.floor(self.walkingFrameTime / self.walkingFrameDuration) % #assets.soldierWalkingImages + 1
            love.graphics.draw(assets.soldierWalkingImages[walkingFrameIndex], -32, -90, 0, 0.5, 0.5)
        end
        
        love.graphics.pop()
    end

    -- Debug visualization
    if debug then
        love.graphics.setColor(1, 0, 0, 0.5)
        love.graphics.rectangle('line', self.x, self.y, self.width, self.height)
        
        -- Dash cooldown indicator
        if self.dashCooldown > 0 then
            love.graphics.setColor(1, 0.5, 0, 0.7)
            love.graphics.rectangle('fill', self.x, self.y - 10, self.width * (1 - self.dashCooldown/1.5), 5)
        end
        
        love.graphics.setColor(1, 1, 1)
    end
end

function Player:takeDamage(amount, enemyX, enemyY)
    if not self.invulnerable and not self.isDashing then
        -- Additional check: verify the enemy is actually close enough to hit
        if enemyX and enemyY then
            local dx = enemyX - (self.x + self.width/2)
            local dy = enemyY - (self.y + self.height/2)
            local dist = math.sqrt(dx*dx + dy*dy)
            
            -- Only take damage if enemy is within reasonable attack distance
            if dist > 100 then  -- Increased from 50 to 100 for safety margin
                return false
            end
        end
        
        self.health = math.max(0, self.health - amount)
        self.invulnerable = true
        self.invulnerableTime = 1.0
        return true
    end
    return false
end

function Player:heal(amount)
    self.health = math.min(self.maxHealth, self.health + amount)
end

function Player:switchWeapon(weaponType)
    -- Store current weapon state before switching
    if self.currentWeapon then
        self.weaponInventory[self.currentWeapon.type] = self.currentWeapon
    end
    
    -- Get the weapon from inventory or create new one
    if self.weaponInventory[weaponType] then
        self.currentWeapon = self.weaponInventory[weaponType]
    else
        self.currentWeapon = Weapons:new(weaponType)
        self.weaponInventory[weaponType] = self.currentWeapon
    end
end

function Player:addAmmo(amount, ammoType)
    if ammoType then
        -- Add specific ammo type to inventory
        self.ammoInventory[ammoType] = (self.ammoInventory[ammoType] or 0) + amount
    else
        -- Add ammo to current weapon type
        local weaponConfig = Weapons.TYPES[self.currentWeapon.type]
        local currentAmmoType = weaponConfig.ammoType
        self.ammoInventory[currentAmmoType] = (self.ammoInventory[currentAmmoType] or 0) + amount
    end
end

function Player:getCenter()
    return self.x + self.width/2, self.y + self.height/2
end

function Player:getWeaponInfo()
    local currentAmmo, maxAmmo = self.currentWeapon:getAmmoInfo()
    local weaponName = self.currentWeapon:getWeaponName()
    local weaponType = self.currentWeapon.type
    local weaponConfig = Weapons.TYPES[weaponType]
    local ammoType = weaponConfig.ammoType
    local inventoryAmmo = self.ammoInventory[ammoType] or 0
    
    return currentAmmo, maxAmmo, weaponName, inventoryAmmo, ammoType
end

function Player:getWeaponMovementRestrictions()
    local weaponType = self.currentWeapon.type
    local weaponConfig = Weapons.TYPES[weaponType]
    return weaponConfig.canMoveWhileShooting, weaponConfig.canAimWhileShooting
end

function Player:getCurrentWeapon()
    return self.currentWeapon
end

function Player:getMuzzlePosition()
    local centerX, centerY = self:getCenter()
    return self.currentWeapon:getMuzzlePosition(centerX, centerY, self.angle)
end

function Player:isReloading()
    return self.currentWeapon.isReloading
end

function Player:getReloadProgress()
    return self.currentWeapon:getReloadProgress()
end

function Player:isAlive()
    return self.health > 0
end

return Player
