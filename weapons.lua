-- Weapon system with multiple firearm types
local Weapons = {}

-- Ammo types
Weapons.AMMO_TYPES = {
    AMMO_9MM = "9mm",
    AMMO_3006 = ".30-06",
    AMMO_12GAUGE = "12 gauge"
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
        collateralFalloff = 0.5,  -- 50% damage reduction per enemy
        screenShakeIntensity = 0.5  -- Medium shake for rifles
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
        muzzleOffset = {x = 0, y = 0},
        ammoType = Weapons.AMMO_TYPES.AMMO_9MM,
        canMoveWhileShooting = true,
        canAimWhileShooting = true,
        collateral = 1,  -- Can only hit 1 enemy
        collateralFalloff = 1.0,  -- No falloff (only hits one enemy)
        screenShakeIntensity = 0.08  -- Light shake for pistols
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
        collateralFalloff = 0.7,  -- 30% damage reduction per enemy
        screenShakeIntensity = 0.12
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
        collateralFalloff = 0.4,  -- 60% damage reduction per enemy
        screenShakeIntensity = 0.2
    },
    SHOTGUN = {
        name = "Shotgun",
        damage = 3.5,      -- Damage per pellet (total up to 8 pellets)
        fireRate = 1.2,   -- Slower fire rate for shotgun
        ammoCapacity = 6, -- Fewer shells
        reloadTime = 2.5,
        accuracy = 0.8,   -- Base accuracy (individual pellets spread)
        range = 200,      -- Medium-short range
        maxRange = 999,   -- Limited effective range
        animationSpeed = 1.0,
        muzzleOffset = {x = 0, y = 00},  -- Slightly different muzzle position
        ammoType = Weapons.AMMO_TYPES.AMMO_12GAUGE,  -- Using 12 gauge shells
        canMoveWhileShooting = false,
        canAimWhileShooting = true,
        collateral = 8,   -- Up to 8 enemies can be hit (one per pellet)
        collateralFalloff = 1.0,  -- Full damage per pellet
        screenShakeIntensity = 0.4,
        specificVars = {   -- Weapon-specific variables
            pelletSpread = math.pi/16,  -- Total spread angle in radians (30-degree cone, 60-degree total)
            pellets = 8,  -- Number of pellets per shot
            incrementalReload = true  -- Enables bullet-by-bullet loading animation
        }
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
        reloadProgress = 0,
        -- Incremental reload tracking
        incrementalReload = (config.specificVars and config.specificVars.incrementalReload) or false,
        shellsLoaded = 0,  -- For incremental loading
        nextShellTime = nil  -- Time when next shell should be loaded
    }
    setmetatable(weapon, { __index = self })
    return weapon
end

function Weapons:canShoot(currentTime)
    -- Allow shooting during incremental reload to interrupt it
    if self.isReloading and not self.incrementalReload then
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

    -- Cancel incremental reload if shooting during it
    if self.isReloading and self.incrementalReload then
        self.isReloading = false
        self.shellsLoaded = 0
        self.nextShellTime = nil
        -- Keep the ammo that was already loaded, discard the rest
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

    -- Handle incremental reloading (shell by shell)
    if self.incrementalReload then
        -- Set next loading time if not set
        if not self.nextShellTime then
            self.nextShellTime = (self.ammoCapacity - self.currentAmmo) > 0 and (self.reloadTime / self.ammoCapacity) or self.reloadTime
        end

        self.reloadProgress = self.reloadProgress + dt

        -- Check if it's time to load the next shell
        if self.reloadProgress >= self.nextShellTime then
            -- Try to load a shell
            local inventoryAmmo = playerAmmoInventory[self.ammoType] or 0
            if inventoryAmmo > 0 and self.currentAmmo < self.ammoCapacity then
                -- Load one shell
                self.currentAmmo = self.currentAmmo + 1
                self.shellsLoaded = self.shellsLoaded + 1
                playerAmmoInventory[self.ammoType] = inventoryAmmo - 1

                -- Set time for next shell (or remaining time if this was the last)
                if self.currentAmmo < self.ammoCapacity then
                    self.nextShellTime = self.nextShellTime + (self.reloadTime / self.ammoCapacity)
                end
            else
                -- No more ammo available or space to load - complete reload
                self.isReloading = false
                self.shellsLoaded = 0
                self.nextShellTime = nil
                return true
            end
        end

        -- Reload complete when time expired or all capacity filled
        if self.reloadProgress >= self.reloadTime or self.currentAmmo >= self.ammoCapacity then
            self.isReloading = false
            self.shellsLoaded = 0
            self.nextShellTime = nil
            return true
        end
    else
        -- Standard reload (load all ammo at once)
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
