-- Shop configuration with weapon costs and item pricing
local Shop = {}

-- Shop item types
Shop.ITEM_TYPES = {
    WEAPON = "weapon",
    AMMO = "ammo",
    HEALTH = "health"
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
    }
}

-- Ammo types (defined locally to avoid circular dependency)
Shop.AMMO_TYPES = {
    AMMO_9MM = "9mm",
    AMMO_3006 = ".30-06"
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

-- Shop state
function Shop:new()
    local shop = {
        isOpen = false,
        availableWeapons = {"SEMI_AUTO_PISTOL"},  -- Start with pistol available
        selectedCategory = "WEAPONS",
        selectedItem = 1
    }
    setmetatable(shop, { __index = self })
    return shop
end

-- Unlock new weapons based on wave progression
function Shop:unlockWeapons(wave)
    if wave >= 2 and not self:isWeaponUnlocked("SMG") then
        table.insert(self.availableWeapons, "SMG")
    end
    if wave >= 3 and not self:isWeaponUnlocked("BOLT_ACTION") then
        table.insert(self.availableWeapons, "BOLT_ACTION")
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
    end
    return {}
end

return Shop
