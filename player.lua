-- Enhanced Player module with weapon system and inventory
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
        -- Inventory system
        weaponSlots = {
            [1] = Weapons:new("SEMI_AUTO_PISTOL"),  -- Start with pistol in slot 1
            [2] = Weapons:new("SHOTGUN"),  -- Empty slot 2
            [3] = Weapons:new("RAILGUN")   -- Empty slot 3
        },
        currentWeaponSlot = 1,  -- Start with slot 1 equipped
        unequippedWeapons = {},  -- Weapons not in slots
        weaponSwitchCooldown = 0,
        lastShotTime = 0,
        isShooting = false,
        shootingTime = 0,
        shootingDuration = 0.3,  -- Duration of shooting animation
        shootingCurrentFrame = 1,
        -- Railgun charging system
        isCharging = false,
        chargeStartTime = 0,
        chargeTime = 0,
        maxChargeTime = 3.0,  -- Maximum charge time in seconds
        chargeShaderActive = false,
        -- Ammo inventory
        ammoInventory = {
            [Weapons.AMMO_TYPES.AMMO_9MM] = 60,  -- Start with 60 9mm rounds
            [Weapons.AMMO_TYPES.AMMO_3006] = 10000,   -- Start with 0 .30-06 rounds (pistol only)
            [Weapons.AMMO_TYPES.AMMO_12GAUGE] = 60   -- Start with 6 12 gauge rounds (shotgun only)
        },
        money = 10000,  -- Money for shop
        -- Weapon inventory to preserve weapon states
        weaponInventory = {},
        -- Upgrade levels
        upgrades = {
            damage_multiplier = 0,
            reload_speed = 0,
            movement_speed = 0,
            max_health = 0,
            dash_cooldown = 0,
            ammo_capacity = 0,
            dash_damage = 0,
            chain_lightning = 0
        }
    }
    setmetatable(player, { __index = self })
    return player
end

function Player:update(dt, assets)
    local currentTime = love.timer.getTime()
    
    -- Update weapon reload with inventory
    local currentWeapon = self:getCurrentWeapon()
    if currentWeapon then
        currentWeapon:updateReload(dt, self.ammoInventory)
    end
    
    -- Handle weapon switching between slots
    self.weaponSwitchCooldown = math.max(0, self.weaponSwitchCooldown - dt)
    
    -- Weapon switching keys (1, 2, 3 for slots)
    if self.weaponSwitchCooldown <= 0 then
        if love.keyboard.isDown('1') then
            self:switchWeaponSlot(1)
        elseif love.keyboard.isDown('2') then
            self:switchWeaponSlot(2)
        elseif love.keyboard.isDown('3') then
            self:switchWeaponSlot(3)
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
        local currentWeapon = self:getCurrentWeapon()
        if currentWeapon then
            local weaponType = currentWeapon.type
            local weaponConfig = Weapons.TYPES[weaponType]
            canMove = weaponConfig.canMoveWhileShooting
            canAim = weaponConfig.canAimWhileShooting
        end
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
        self.dashCooldown = self:getEffectiveDashCooldown()
        self.invulnerable = true
        self.invulnerableTime = 0.2
    end

    -- Reload weapon with inventory check
    local currentWeapon = self:getCurrentWeapon()
    if love.keyboard.isDown('r') and currentWeapon and not currentWeapon.isReloading then
        currentWeapon:startReload(self.ammoInventory)
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

    -- Handle railgun charging and firing
    local currentWeapon = self:getCurrentWeapon()
    if currentWeapon and currentWeapon.type == "RAILGUN" then
        -- Railgun specific behavior
        if love.mouse.isDown(1) and currentWeapon:canShoot(currentTime) and not self.isCharging then
            -- Start charging
            self.isCharging = true
            self.chargeStartTime = currentTime
            self.chargeTime = 0
        elseif self.isCharging then
            -- Update charge time
            self.chargeTime = currentTime - self.chargeStartTime
            
            -- Cap charge time at maximum
            local weaponConfig = Weapons.TYPES.RAILGUN
            if weaponConfig and weaponConfig.specificVars then
                self.chargeTime = math.min(self.chargeTime, weaponConfig.specificVars.maxChargeTime)
            else
                self.chargeTime = math.min(self.chargeTime, self.maxChargeTime)
            end
            
            -- Check if mouse button released to fire
            if not love.mouse.isDown(1) then
                -- Fire the railgun with charge-based damage
                if currentWeapon:shoot(currentTime) then
                    self.lastShotTime = currentTime
                    self.isShooting = true
                    self.shootingTime = 0
                    self.shootingCurrentFrame = 1
                    self.isCharging = false
                    return true, self.chargeTime  -- Signal that player shot and return charge time
                end
            end
        end
    else
        -- Normal weapon behavior
        if love.mouse.isDown(1) and currentWeapon and currentWeapon:canShoot(currentTime) then
            if currentWeapon:shoot(currentTime) then
                self.lastShotTime = currentTime
                self.isShooting = true
                self.shootingTime = 0
                self.shootingCurrentFrame = 1
                return true  -- Signal that player shot
            end
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

    -- Note: Boundary collision is now handled by the collision system
    
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
        local currentWeapon = self:getCurrentWeapon()
        if currentWeapon then
            local weaponConfig = Weapons.TYPES[currentWeapon.type]
            local currentAmmoType = weaponConfig.ammoType
            self.ammoInventory[currentAmmoType] = (self.ammoInventory[currentAmmoType] or 0) + amount
        end
    end
end

function Player:getCenter()
    return self.x + self.width/2, self.y + self.height/2
end

function Player:getWeaponInfo()
    local currentWeapon = self:getCurrentWeapon()
    if currentWeapon then
        local currentAmmo, maxAmmo = currentWeapon:getAmmoInfo()
        local weaponName = currentWeapon:getWeaponName()
        local weaponType = currentWeapon.type
        local weaponConfig = Weapons.TYPES[weaponType]
        local ammoType = weaponConfig.ammoType
        local inventoryAmmo = self.ammoInventory[ammoType] or 0
        
        return currentAmmo, maxAmmo, weaponName, inventoryAmmo, ammoType
    end
    return 0, 0, "No Weapon", 0, "NONE"
end

function Player:getWeaponMovementRestrictions()
    local currentWeapon = self:getCurrentWeapon()
    if currentWeapon then
        local weaponType = currentWeapon.type
        local weaponConfig = Weapons.TYPES[weaponType]
        return weaponConfig.canMoveWhileShooting, weaponConfig.canAimWhileShooting
    end
    return true, true  -- Default to no restrictions if no weapon
end

function Player:getCurrentWeapon()
    return self.weaponSlots[self.currentWeaponSlot]
end

function Player:getMuzzlePosition()
    local centerX, centerY = self:getCenter()
    local currentWeapon = self:getCurrentWeapon()
    if currentWeapon then
        return currentWeapon:getMuzzlePosition(centerX, centerY, self.angle)
    end
    return centerX, centerY
end

function Player:isReloading()
    local currentWeapon = self:getCurrentWeapon()
    return currentWeapon and currentWeapon.isReloading or false
end

function Player:getReloadProgress()
    local currentWeapon = self:getCurrentWeapon()
    return currentWeapon and currentWeapon:getReloadProgress() or 1.0
end

function Player:isAlive()
    return self.health > 0
end

-- Railgun specific methods
function Player:isChargingRailgun()
    local currentWeapon = self:getCurrentWeapon()
    return currentWeapon and currentWeapon.type == "RAILGUN" and self.isCharging
end

function Player:getChargeProgress()
    if not self.isCharging then
        return 0
    end
    
    local weaponConfig = Weapons.TYPES.RAILGUN
    local maxChargeTime = self.maxChargeTime
    if weaponConfig and weaponConfig.specificVars then
        maxChargeTime = weaponConfig.specificVars.maxChargeTime
    end
    
    return math.min(self.chargeTime / maxChargeTime, 1.0)
end

function Player:getChargeDamageMultiplier()
    if not self.isCharging then
        return 1.0
    end
    
    local weaponConfig = Weapons.TYPES.RAILGUN
    if not weaponConfig or not weaponConfig.specificVars then
        return 1.0
    end
    
    local minMultiplier = weaponConfig.specificVars.minDamageMultiplier or 0.5
    local maxMultiplier = weaponConfig.specificVars.maxDamageMultiplier or 3.0
    
    local progress = self:getChargeProgress()
    return minMultiplier + (maxMultiplier - minMultiplier) * progress
end

-- Inventory management methods

function Player:switchWeaponSlot(slot)
    if slot >= 1 and slot <= 3 and self.weaponSlots[slot] then
        -- Cancel charging if switching from railgun
        if self.isCharging then
            self.isCharging = false
        end
        
        self.currentWeaponSlot = slot
        self.weaponSwitchCooldown = 0.5
        return true
    end
    return false
end

function Player:addWeapon(weaponType)
    -- Check if we already have this weapon type
    for slot = 1, 3 do
        if self.weaponSlots[slot] and self.weaponSlots[slot].type == weaponType then
            return false  -- Already have this weapon
        end
    end
    
    -- Try to add to empty slot first
    for slot = 1, 3 do
        if not self.weaponSlots[slot] then
            self.weaponSlots[slot] = Weapons:new(weaponType)
            return true
        end
    end
    
    -- No empty slots, add to unequipped
    table.insert(self.unequippedWeapons, Weapons:new(weaponType))
    return true
end

function Player:moveWeapon(fromSlot, toSlot)
    if fromSlot == toSlot then return false end
    
    if fromSlot >= 1 and fromSlot <= 3 and toSlot >= 1 and toSlot <= 3 then
        local temp = self.weaponSlots[toSlot]
        self.weaponSlots[toSlot] = self.weaponSlots[fromSlot]
        self.weaponSlots[fromSlot] = temp
        
        -- Update current weapon slot if needed
        if self.currentWeaponSlot == fromSlot then
            self.currentWeaponSlot = toSlot
        elseif self.currentWeaponSlot == toSlot then
            self.currentWeaponSlot = fromSlot
        end
        
        return true
    end
    return false
end

function Player:swapWeaponWithInventory(slot, inventoryIndex)
    if slot >= 1 and slot <= 3 and inventoryIndex >= 1 and inventoryIndex <= #self.unequippedWeapons then
        local temp = self.weaponSlots[slot]
        self.weaponSlots[slot] = self.unequippedWeapons[inventoryIndex]
        self.unequippedWeapons[inventoryIndex] = temp
        
        -- Update current weapon slot if needed
        if self.currentWeaponSlot == slot then
            -- Weapon was swapped out, switch to new weapon
            self.currentWeaponSlot = slot
        end
        
        return true
    end
    return false
end

-- New methods for loadout manager
function Player:unequipWeapon(slot)
    if slot >= 1 and slot <= 3 then
        local weapon = self.weaponSlots[slot]
        self.weaponSlots[slot] = nil
        -- Update current weapon slot if needed
        if self.currentWeaponSlot == slot then
            -- Find another equipped weapon to switch to
            for i = 1, 3 do
                if i ~= slot and self.weaponSlots[i] then
                    self.currentWeaponSlot = i
                    break
                end
            end
            -- If no other weapons equipped, stay on empty slot
        end
        return weapon
    end
    return nil
end

function Player:removeWeaponFromInventory(index)
    if index >= 1 and index <= #self.unequippedWeapons then
        local weapon = self.unequippedWeapons[index]
        table.remove(self.unequippedWeapons, index)
        return weapon
    end
    return nil
end

function Player:equipWeapon(slot, weapon)
    if slot >= 1 and slot <= 3 then
        self.weaponSlots[slot] = weapon
        return true
    end
    return false
end

function Player:addWeaponToInventory(weapon)
    table.insert(self.unequippedWeapons, weapon)
    return true
end

function Player:getWeaponSlots()
    return self.weaponSlots
end

function Player:getUnequippedWeapons()
    return self.unequippedWeapons
end

function Player:getCurrentWeaponSlot()
    return self.currentWeaponSlot
end

function Player:getMoney()
    return self.money
end

function Player:addMoney(amount)
    self.money = self.money + amount
end

function Player:spendMoney(amount)
    if self.money >= amount then
        self.money = self.money - amount
        return true
    end
    return false
end

function Player:hasWeapon(weaponType)
    -- Check equipped slots
    for slot = 1, 3 do
        if self.weaponSlots[slot] and self.weaponSlots[slot].type == weaponType then
            return true
        end
    end
    
    -- Check unequipped weapons
    for _, weapon in ipairs(self.unequippedWeapons) do
        if weapon.type == weaponType then
            return true
        end
    end
    
    return false
end

-- Upgrade methods
function Player:getUpgradeLevel(upgradeType)
    return self.upgrades[upgradeType] or 0
end

function Player:canUpgrade(upgradeType)
    local Shop = require('shop')
    local upgradeData = Shop.UPGRADE_COSTS[upgradeType]
    if not upgradeData then
        return false
    end
    
    local currentLevel = self:getUpgradeLevel(upgradeData.effect)
    return currentLevel < upgradeData.maxLevel
end

    function Player:purchaseUpgrade(upgradeType)
        local Shop = require('shop')
        local upgradeData = Shop.UPGRADE_COSTS[upgradeType]
        if not upgradeData then
            print("DEBUG: Invalid upgrade type: " .. tostring(upgradeType))
            return false, "Invalid upgrade type"
        end
        
        local currentLevel = self:getUpgradeLevel(upgradeData.effect)
        print(string.format("DEBUG: Upgrade %s current level: %d, max level: %d", upgradeType, currentLevel, upgradeData.maxLevel))
        
        if currentLevel >= upgradeData.maxLevel then
            print("DEBUG: Max level reached for upgrade: " .. upgradeType)
            return false, "Max level reached"
        end
        
        local cost = upgradeData.cost
        print(string.format("DEBUG: Upgrade cost: %d, player money: %d", cost, self.money))
        
        if not self:spendMoney(cost) then
            print("DEBUG: Not enough money for upgrade: " .. upgradeType)
            return false, "Not enough money"
        end
        
        -- Apply the upgrade
        self.upgrades[upgradeData.effect] = currentLevel + 1
        print(string.format("DEBUG: Applied upgrade %s, new level: %d", upgradeData.effect, self.upgrades[upgradeData.effect]))
        self:applyUpgradeEffects()
        
        return true, "Upgrade purchased: " .. upgradeData.name .. " (Level " .. (currentLevel + 1) .. ")"
    end

function Player:applyUpgradeEffects()
    -- Apply damage multiplier
    local damageLevel = self.upgrades.damage_multiplier or 0
    local damageMultiplier = 1.0 + (damageLevel * 0.10)  -- +10% per level
    
    -- Apply movement speed
    local speedLevel = self.upgrades.movement_speed or 0
    local speedMultiplier = 1.0 + (speedLevel * 0.10)  -- +10% per level
    self.speed = 300 * speedMultiplier
    self.dashSpeed = 600 * speedMultiplier
    
    -- Apply max health
    local healthLevel = self.upgrades.max_health or 0
    local healthBonus = healthLevel * 25  -- +25 health per level
    self.maxHealth = 100 + healthBonus
    
    -- Apply dash cooldown reduction
    local dashLevel = self.upgrades.dash_cooldown or 0
    local dashCooldownMultiplier = 1.0 - (dashLevel * 0.20)  -- -20% per level
    -- Note: Dash cooldown is applied when checking cooldown
    
    -- Apply ammo capacity
    local ammoLevel = self.upgrades.ammo_capacity or 0
    local ammoMultiplier = 1.0 + (ammoLevel * 0.25)  -- +25% per level
    -- Note: Ammo capacity is applied when creating weapons
end

function Player:getEffectiveDashCooldown()
    local dashLevel = self.upgrades.dash_cooldown or 0
    local dashCooldownMultiplier = 1.0 - (dashLevel * 0.20)  -- -20% per level
    return 1.5 * dashCooldownMultiplier
end

function Player:getEffectiveDamage(weapon)
    local damageLevel = self.upgrades.damage_multiplier or 0
    local damageMultiplier = 1.0 + (damageLevel * 0.10)  -- +10% per level
    return weapon.damage * damageMultiplier
end

function Player:getEffectiveReloadTime(weapon)
    local reloadLevel = self.upgrades.reload_speed or 0
    local reloadMultiplier = 1.0 - (reloadLevel * 0.15)  -- -15% per level
    return weapon.reloadTime * reloadMultiplier
end

function Player:getEffectiveAmmoCapacity(weapon)
    local ammoLevel = self.upgrades.ammo_capacity or 0
    local ammoMultiplier = 1.0 + (ammoLevel * 0.25)  -- +25% per level
    return math.floor(weapon.ammoCapacity * ammoMultiplier)
end

function Player:getUpgradeInfo()
    return self.upgrades
end

return Player
