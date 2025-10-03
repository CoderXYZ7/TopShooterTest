-- Weapon system with multiple firearm types
local Weapons = {}

-- Ammo types
Weapons.AMMO_TYPES = {
    AMMO_9MM = "9mm",
    AMMO_3006 = ".30-06"
}

-- Weapon types with different characteristics
Weapons.TYPES = {
    BOLT_ACTION = {
        name = "Bolt Action Rifle",
        damage = 50,
        fireRate = 0.8,  -- Shots per second
        ammoCapacity = 5,
        reloadTime = 2.0,
        accuracy = 0.95,  -- Higher = more accurate
        range = 500,
        maxRange = 999,  -- Maximum effective range with falloff
        animationSpeed = 1.0,
        muzzleOffset = {x = 5, y = -30},
        ammoType = Weapons.AMMO_TYPES.AMMO_3006,
        canMoveWhileShooting = false,
        canAimWhileShooting = false,
        collateral = 3,  -- Can hit up to 3 enemies in line
        collateralFalloff = 0.5  -- 50% damage reduction per enemy
    },
    SEMI_AUTO_PISTOL = {
        name = "Semi-Auto Pistol",
        damage = 25,
        fireRate = 3.0,  -- Faster firing
        ammoCapacity = 12,
        reloadTime = 1.5,
        accuracy = 0.85,
        range = 300,
        maxRange = 999,  -- Maximum effective range with falloff
        animationSpeed = 1.5,
        muzzleOffset = {x = 3, y = -25},
        ammoType = Weapons.AMMO_TYPES.AMMO_9MM,
        canMoveWhileShooting = true,
        canAimWhileShooting = true,
        collateral = 1,  -- Can only hit 1 enemy
        collateralFalloff = 1.0  -- No falloff (only hits one enemy)
    },
    SMG = {
        name = "Submachine Gun",
        damage = 15,
        fireRate = 8.0,  -- Very fast firing
        ammoCapacity = 30,
        reloadTime = 2.5,
        accuracy = 0.75,
        range = 200,
        maxRange = 999,  -- Maximum effective range with falloff
        animationSpeed = 2.0,
        muzzleOffset = {x = 4, y = -28},
        ammoType = Weapons.AMMO_TYPES.AMMO_9MM,
        canMoveWhileShooting = false,
        canAimWhileShooting = true,
        collateral = 2,  -- Can hit up to 2 enemies in line
        collateralFalloff = 0.7  -- 30% damage reduction per enemy
    },
    HMG = {
        name = "Heavy Machine Gun",
        damage = 20,
        fireRate = 6.0,  -- Very fast firing
        ammoCapacity = 60,
        reloadTime = 3.5,
        accuracy = 0.75,
        range = 400,
        maxRange = 999,  -- Maximum effective range with falloff
        animationSpeed = 2.0,
        muzzleOffset = {x = 4, y = -28},
        ammoType = Weapons.AMMO_TYPES.AMMO_9MM,
        canMoveWhileShooting = false,
        canAimWhileShooting = true,
        collateral = 4,  -- Can hit up to 4 enemies in line
        collateralFalloff = 0.4  -- 60% damage reduction per enemy
    }
}

function Weapons:new(weaponType)
    local type = weaponType or "BOLT_ACTION"
    local config = Weapons.TYPES[type]
    
    local weapon = {
        type = type,
        name = config.name,
        damage = config.damage,
        fireRate = config.fireRate,
        ammoCapacity = config.ammoCapacity,
        currentAmmo = config.ammoCapacity,
        reloadTime = config.reloadTime,
        accuracy = config.accuracy,
        range = config.range,
        maxRange = config.maxRange,
        animationSpeed = config.animationSpeed,
        muzzleOffset = config.muzzleOffset,
        ammoType = config.ammoType,
        canMoveWhileShooting = config.canMoveWhileShooting,
        canAimWhileShooting = config.canAimWhileShooting,
        lastShotTime = 0,
        isReloading = false,
        reloadProgress = 0
    }
    setmetatable(weapon, { __index = self })
    return weapon
end

function Weapons:canShoot(currentTime)
    if self.isReloading then
        return false
    end
    
    if self.currentAmmo <= 0 then
        return false
    end
    
    local timeSinceLastShot = currentTime - self.lastShotTime
    local shotCooldown = 1.0 / self.fireRate
    
    return timeSinceLastShot >= shotCooldown
end

function Weapons:shoot(currentTime)
    if not self:canShoot(currentTime) then
        return false
    end
    
    self.currentAmmo = self.currentAmmo - 1
    self.lastShotTime = currentTime
    
    return true
end

function Weapons:startReload(playerAmmoInventory)
    if self.isReloading or self.currentAmmo >= self.ammoCapacity then
        return false
    end
    
    -- Check if we have ammo in inventory for this weapon type
    local inventoryAmmo = playerAmmoInventory[self.ammoType] or 0
    if inventoryAmmo <= 0 then
        return false  -- No ammo to reload with
    end
    
    self.isReloading = true
    self.reloadProgress = 0
    return true
end

function Weapons:updateReload(dt, playerAmmoInventory)
    if not self.isReloading then
        return false
    end
    
    self.reloadProgress = self.reloadProgress + dt
    
    if self.reloadProgress >= self.reloadTime then
        -- Calculate how much ammo we need to fill the weapon
        local ammoNeeded = self.ammoCapacity - self.currentAmmo
        local inventoryAmmo = playerAmmoInventory[self.ammoType] or 0
        
        -- Take ammo from inventory, but not more than available
        local ammoToTake = math.min(ammoNeeded, inventoryAmmo)
        
        -- Update weapon ammo and inventory
        self.currentAmmo = self.currentAmmo + ammoToTake
        playerAmmoInventory[self.ammoType] = inventoryAmmo - ammoToTake
        
        self.isReloading = false
        return true  -- Reload complete
    end
    
    return false  -- Still reloading
end

function Weapons:getMuzzlePosition(playerX, playerY, playerAngle)
    local offsetX = self.muzzleOffset.x
    local offsetY = self.muzzleOffset.y
    
    -- Rotate offset based on player angle
    local rotatedX = math.cos(playerAngle) * offsetX - math.sin(playerAngle) * offsetY
    local rotatedY = math.sin(playerAngle) * offsetX + math.cos(playerAngle) * offsetY
    
    return playerX + rotatedX, playerY + rotatedY
end

function Weapons:getReloadProgress()
    if not self.isReloading then
        return 1.0
    end
    return self.reloadProgress / self.reloadTime
end

function Weapons:getAmmoInfo()
    return self.currentAmmo, self.ammoCapacity
end

function Weapons:getWeaponType()
    return self.type
end

function Weapons:getWeaponName()
    return self.name
end

-- Utility function to get all weapon types
function Weapons.getAllTypes()
    local types = {}
    for key, _ in pairs(Weapons.TYPES) do
        table.insert(types, key)
    end
    return types
end

return Weapons
