-- Shop configuration with weapon costs and item pricing
local Shop = {}

-- Shop item types
Shop.ITEM_TYPES = {
    WEAPON = "weapon",
    AMMO = "ammo",
    HEALTH = "health",
    UPGRADE = "upgrade"
}

-- Weapon costs
Shop.WEAPON_COSTS = {
    SEMI_AUTO_PISTOL = {
        cost = 0,  -- Starting weapon, free
        name = "Semi-Auto Pistol",
        description = "Standard sidearm with good accuracy"
    },
    BOLT_ACTION = {
        cost = 500,
        name = "Bolt Action Rifle",
        description = "High damage, slow firing sniper rifle"
    },
    SMG = {
        cost = 300,
        name = "Submachine Gun",
        description = "Fast firing close-range weapon"
    },
    HMG = {
        cost = 800,
        name = "Heavy Machine Gun",
        description = "High capacity, rapid fire support weapon"
    },
    SHOTGUN = {
        cost = 600,
        name = "Shotgun",
        description = "Close-range pellet weapon with high spread"
    }
}

-- Ammo types (defined locally to avoid circular dependency)
Shop.AMMO_TYPES = {
    AMMO_9MM = "9mm",
    AMMO_3006 = ".30-06",
    AMMO_12GAUGE = "12 gauge"
}

-- Ammo costs
Shop.AMMO_COSTS = {
    ["9mm"] = {
        cost = 50,
        amount = 30,
        name = "9mm Ammo Pack",
        description = "30 rounds of 9mm ammunition"
    },
    [".30-06"] = {
        cost = 100,
        amount = 10,
        name = ".30-06 Ammo Pack",
        description = "10 rounds of .30-06 ammunition"
    },
    ["12 gauge"] = {
        cost = 75,
        amount = 8,
        name = "12 Gauge Shells",
        description = "8 shotgun shells"
    }
}

-- Health costs
Shop.HEALTH_COSTS = {
    SMALL = {
        cost = 100,
        amount = 25,
        name = "Small Medkit",
        description = "Restores 25 health"
    },
    LARGE = {
        cost = 250,
        amount = 50,
        name = "Large Medkit",
        description = "Restores 50 health"
    }
}

-- Upgrade costs
Shop.UPGRADE_COSTS = {
    DAMAGE_BOOST = {
        cost = 400,
        name = "Damage Boost",
        description = "+10% weapon damage",
        maxLevel = 5,
        effect = "damage_multiplier"
    },
    RELOAD_SPEED = {
        cost = 300,
        name = "Reload Speed",
        description = "+15% faster reload speed",
        maxLevel = 5,
        effect = "reload_speed"
    },
    MOVEMENT_SPEED = {
        cost = 350,
        name = "Movement Speed",
        description = "+10% movement speed",
        maxLevel = 5,
        effect = "movement_speed"
    },
    HEALTH_BOOST = {
        cost = 500,
        name = "Health Boost",
        description = "+25 max health",
        maxLevel = 4,
        effect = "max_health"
    },
    DASH_COOLDOWN = {
        cost = 250,
        name = "Dash Cooldown",
        description = "-20% dash cooldown",
        maxLevel = 3,
        effect = "dash_cooldown"
    },
    AMMO_CAPACITY = {
        cost = 450,
        name = "Ammo Capacity",
        description = "+25% ammo capacity",
        maxLevel = 4,
        effect = "ammo_capacity"
    }
}

-- Shop state
function Shop:new()
    local shop = {
        isOpen = false,
        availableWeapons = {"SEMI_AUTO_PISTOL", "SMG", "BOLT_ACTION", "SHOTGUN", "HMG"},  -- Start with pistol available
        selectedCategory = "WEAPONS",
        selectedItem = 1
    }
    setmetatable(shop, { __index = self })
    return shop
end

function Shop:getUpgradeCost(upgradeType, player)
    local upgradeData = Shop.UPGRADE_COSTS[upgradeType]
    if not upgradeData then
        return 0
    end
    
    -- Calculate cost based on current level (cost increases by 50% per level)
    local currentLevel = player:getUpgradeLevel(upgradeData.effect)
    local baseCost = upgradeData.cost
    local actualCost = baseCost * (1 + currentLevel * 0.5)  -- 50% increase per level
    
    return math.floor(actualCost)
end

function Shop:getUpgradeLevel(upgradeType, player)
    local upgradeData = Shop.UPGRADE_COSTS[upgradeType]
    if not upgradeData then
        return 0
    end
    
    return player:getUpgradeLevel(upgradeData.effect)
end

-- Unlock new weapons based on wave progression
function Shop:unlockWeapons(wave)
    if wave >= 2 and not self:isWeaponUnlocked("SMG") then
        table.insert(self.availableWeapons, "SMG")
    end
    if wave >= 3 and not self:isWeaponUnlocked("BOLT_ACTION") then
        table.insert(self.availableWeapons, "BOLT_ACTION")
    end
    if wave >= 4 and not self:isWeaponUnlocked("SHOTGUN") then
        table.insert(self.availableWeapons, "SHOTGUN")
    end
    if wave >= 5 and not self:isWeaponUnlocked("HMG") then
        table.insert(self.availableWeapons, "HMG")
    end
end

function Shop:isWeaponUnlocked(weaponType)
    for _, weapon in ipairs(self.availableWeapons) do
        if weapon == weaponType then
            return true
        end
    end
    return false
end

function Shop:getWeaponCost(weaponType)
    return Shop.WEAPON_COSTS[weaponType].cost
end

function Shop:getAmmoCost(ammoType)
    return Shop.AMMO_COSTS[ammoType].cost
end

function Shop:getHealthCost(healthType)
    return Shop.HEALTH_COSTS[healthType].cost
end

function Shop:open()
    self.isOpen = true
    self.selectedCategory = "WEAPONS"
    self.selectedItem = 1
end

function Shop:close()
    self.isOpen = false
end

function Shop:isOpen()
    return self.isOpen
end

-- Get available items for current category
function Shop:getAvailableItems()
    if self.selectedCategory == "WEAPONS" then
        local items = {}
        for _, weaponType in ipairs(self.availableWeapons) do
            table.insert(items, {
                type = Shop.ITEM_TYPES.WEAPON,
                weaponType = weaponType,
                cost = Shop.WEAPON_COSTS[weaponType].cost,
                name = Shop.WEAPON_COSTS[weaponType].name,
                description = Shop.WEAPON_COSTS[weaponType].description
            })
        end
        return items
    elseif self.selectedCategory == "AMMO" then
        local items = {}
        for ammoType, data in pairs(Shop.AMMO_COSTS) do
            table.insert(items, {
                type = Shop.ITEM_TYPES.AMMO,
                ammoType = ammoType,
                cost = data.cost,
                name = data.name,
                description = data.description,
                amount = data.amount
            })
        end
        return items
    elseif self.selectedCategory == "HEALTH" then
        local items = {}
        for healthType, data in pairs(Shop.HEALTH_COSTS) do
            table.insert(items, {
                type = Shop.ITEM_TYPES.HEALTH,
                healthType = healthType,
                cost = data.cost,
                name = data.name,
                description = data.description,
                amount = data.amount
            })
        end
        return items
    elseif self.selectedCategory == "UPGRADES" then
        local items = {}
        for upgradeType, data in pairs(Shop.UPGRADE_COSTS) do
            table.insert(items, {
                type = Shop.ITEM_TYPES.UPGRADE,
                upgradeType = upgradeType,
                cost = data.cost,
                name = data.name,
                description = data.description,
                maxLevel = data.maxLevel,
                effect = data.effect
            })
        end
        return items
    end
    return {}
end

return Shop
