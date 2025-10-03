# TopShooterTest - Components and Data Structures Documentation

## Project Overview

TopShooterTest is a top-down shooter game built with LÖVE (Love2D) framework. The game features wave-based combat, weapon inventory system, shop mechanics, and various enemy types with progressive difficulty.

## Core Architecture

### Main Game Loop (`main.lua`)
- **Purpose**: Central game coordinator and main loop
- **Key Components**:
  - Game state management
  - Module initialization and coordination
  - Input handling
  - Game restart functionality

### Configuration (`conf.lua`)
- **Purpose**: Game window and engine configuration
- **Settings**:
  - Window dimensions: 1280x720
  - Game title: "Top Down Shooter"
  - LÖVE version: 11.4

## Core Components

### 1. Game Manager (`game_manager.lua`)

**Purpose**: Manages game states, wave progression, enemy spawning, and shop interactions.

**Data Structures**:
```lua
GameManager = {
    currentState = "PLAYING",  -- PLAYING, GAME_OVER, VICTORY, PAUSED, SHOP
    wave = 1,
    enemiesPerWave = 5,
    enemiesSpawnedThisWave = 0,
    enemiesKilledThisWave = 0,
    waveTimer = 0,
    waveCooldown = 3,
    spawnTimer = 0,
    spawnInterval = 2.0,
    maxEnemies = 15,
    difficultyMultiplier = 1.0,
    pickupSpawnTimer = 0,
    pickupSpawnInterval = 10.0,
    pickups = {},  -- Array of pickup objects
    waveCleared = false,
    createEnemy = nil,  -- Callback function
    shop = Shop:new(),
    shopOpen = false,
    shopTimer = 0,
    shopDuration = 30
}
```

**Pickup Structure**:
```lua
pickup = {
    x = number,        -- X position
    y = number,        -- Y position
    type = string,     -- "health" or "ammo"
    lifetime = 15.0,   -- Seconds before disappearing
    age = 0,           -- Current age
    size = 20,         -- Collision radius
    color = table      -- RGB color values
}
```

### 2. Player System (`player.lua`)

**Purpose**: Manages player character, movement, weapons, inventory, and upgrades.

**Data Structures**:
```lua
Player = {
    -- Position and Movement
    x = 640, y = 360,
    width = 64, height = 64,
    speed = 300,
    angle = 0,
    
    -- Health and Combat
    health = 100, maxHealth = 100,
    invulnerable = false,
    invulnerableTime = 0,
    
    -- Dash System
    dashCooldown = 0,
    dashDuration = 0,
    isDashing = false,
    dashSpeed = 600,
    
    -- Animation
    walkingFrameDuration = 0.08,
    walkingFrameTime = 0,
    
    -- Weapon System
    weaponSlots = {
        [1] = Weapons:new("SEMI_AUTO_PISTOL"),
        [2] = nil,
        [3] = nil
    },
    currentWeaponSlot = 1,
    unequippedWeapons = {},
    weaponSwitchCooldown = 0,
    
    -- Shooting Animation
    lastShotTime = 0,
    isShooting = false,
    shootingTime = 0,
    shootingDuration = 0.3,
    shootingCurrentFrame = 1,
    
    -- Ammo Inventory
    ammoInventory = {
        [Weapons.AMMO_TYPES.AMMO_9MM] = 60,
        [Weapons.AMMO_TYPES.AMMO_3006] = 0
    },
    
    -- Economy
    money = 10000,
    
    -- Weapon State Persistence
    weaponInventory = {},
    
    -- Upgrade System
    upgrades = {
        damage_multiplier = 0,
        reload_speed = 0,
        movement_speed = 0,
        max_health = 0,
        dash_cooldown = 0,
        ammo_capacity = 0
    }
}
```

### 3. Enemy System (`enemy.lua`)

**Purpose**: Manages enemy types, behaviors, and combat mechanics.

**Enemy Types Configuration**:
```lua
Enemy.TYPES = {
    ZOMBIE = {
        speed = 50,
        health = 30,
        damage = 10,
        score = 100,
        color = {0.3, 0.8, 0.3},
        scale = 0.5,
        attackSpeed = 1.0,
        attackRange = 80
    },
    FAST_ZOMBIE = {
        speed = 120,
        health = 20,
        damage = 5,
        score = 150,
        color = {0.8, 0.8, 0.3},
        scale = 0.45,
        attackSpeed = 1.5,
        attackRange = 70
    },
    TANK_ZOMBIE = {
        speed = 30,
        health = 100,
        damage = 20,
        score = 300,
        color = {0.8, 0.3, 0.3},
        scale = 0.7,
        attackSpeed = 0.7,
        attackRange = 90
    }
}
```

**Enemy Instance Structure**:
```lua
Enemy = {
    x = number, y = number,
    width = 64, height = 64,
    speed = number,
    angle = 0,
    currentFrame = number,
    walkingFrameTime = 0,
    zombieFrameDuration = 0.1,
    attackFrameTime = 0,
    attackFrameDuration = 0.1,
    health = number,
    maxHealth = number,
    damage = number,
    score = number,
    type = string,
    color = table,
    scale = number,
    attackCooldown = 0,
    attackRange = number,
    lastPlayerPos = {x = 0, y = 0},
    pathUpdateTimer = 0,
    isAttacking = false,
    attackTime = 0,
    attackDuration = number,
    hasDealtDamage = false,
    attackSpeed = number
}
```

### 4. Weapon System (`weapons.lua`)

**Purpose**: Defines weapon types, characteristics, and ammunition system.

**Ammo Types**:
```lua
Weapons.AMMO_TYPES = {
    AMMO_9MM = "9mm",
    AMMO_3006 = ".30-06"
}
```

**Weapon Types Configuration**:
```lua
Weapons.TYPES = {
    BOLT_ACTION = {
        name = "Bolt Action Rifle",
        damage = 50,
        fireRate = 0.8,           -- Shots per second
        ammoCapacity = 5,
        reloadTime = 2.0,
        accuracy = 0.95,          -- Higher = more accurate
        range = 500,
        maxRange = 999,
        animationSpeed = 1.0,
        muzzleOffset = {x = 5, y = -30},
        ammoType = Weapons.AMMO_TYPES.AMMO_3006,
        canMoveWhileShooting = false,
        canAimWhileShooting = false,
        collateral = 3,           -- Can hit up to 3 enemies
        collateralFalloff = 0.5   -- 50% damage reduction per enemy
    },
    -- Other weapons: SEMI_AUTO_PISTOL, SMG, HMG
}
```

**Weapon Instance Structure**:
```lua
Weapon = {
    type = string,
    name = string,
    damage = number,
    fireRate = number,
    ammoCapacity = number,
    currentAmmo = number,
    reloadTime = number,
    accuracy = number,
    range = number,
    maxRange = number,
    animationSpeed = number,
    muzzleOffset = table,
    ammoType = string,
    canMoveWhileShooting = boolean,
    canAimWhileShooting = boolean,
    lastShotTime = 0,
    isReloading = false,
    reloadProgress = 0
}
```

### 5. Shooting System (`shooting.lua`)

**Purpose**: Handles projectile calculations, hit detection, and collateral damage.

**Hit Result Structure**:
```lua
hitResult = {
    enemyIndex = number,      -- Index in enemies array
    hitDistance = number,     -- Distance from player
    damageMultiplier = number -- Collateral damage multiplier
}
```

### 6. Collision System (`collision.lua`)

**Purpose**: Manages collision detection and resolution between entities.

**Collision Types**:
- Player-Enemy collisions
- Enemy-Enemy collisions

### 7. Particle System (`particles.lua`)

**Purpose**: Manages visual effects like blood splats, muzzle flashes, and dash trails.

**Particle System Structure**:
```lua
ParticleSystem = {
    systems = {},  -- Array of particle systems
    nextId = 1
}
```

**Individual Particle System**:
```lua
particleSystem = {
    id = number,
    x = number, y = number,
    particles = {},  -- Array of individual particles
    lifetime = number,
    age = 0,
    active = true
}
```

**Individual Particle**:
```lua
particle = {
    x = number, y = number,
    vx = number, vy = number,  -- Velocity
    size = number,
    color = table,             -- RGB values
    lifetime = number,
    age = 0
}
```

### 8. UI System (`ui.lua`)

**Purpose**: Manages user interface, HUD, shop display, and loadout management.

**UI State Structure**:
```lua
UI = {
    score = 0,
    health = 100,
    maxHealth = 100,
    wave = 1,
    enemiesRemaining = 0,
    timeSurvived = 0,
    highScore = 0,
    showTutorial = true,
    tutorialTime = 0,
    gameOver = false,
    victory = false,
    money = 0,
    shopMessage = "",
    shopMessageTimer = 0,
    loadoutMode = false,
    selectedLoadoutSlot = 1,
    selectedInventoryWeapon = 1
}
```

### 9. Shop System (`shop.lua`)

**Purpose**: Manages shop items, pricing, and player purchases.

**Shop State Structure**:
```lua
Shop = {
    isOpen = false,
    availableWeapons = {"SEMI_AUTO_PISTOL"},
    selectedCategory = "WEAPONS",
    selectedItem = 1
}
```

**Item Type Definitions**:
```lua
Shop.ITEM_TYPES = {
    WEAPON = "weapon",
    AMMO = "ammo",
    HEALTH = "health",
    UPGRADE = "upgrade"
}
```

**Shop Item Structures**:
```lua
-- Weapon Item
weaponItem = {
    type = "weapon",
    weaponType = string,
    cost = number,
    name = string,
    description = string
}

-- Ammo Item
ammoItem = {
    type = "ammo",
    ammoType = string,
    cost = number,
    name = string,
    description = string,
    amount = number
}

-- Health Item
healthItem = {
    type = "health",
    healthType = string,
    cost = number,
    name = string,
    description = string,
    amount = number
}

-- Upgrade Item
upgradeItem = {
    type = "upgrade",
    upgradeType = string,
    cost = number,
    name = string,
    description = string,
    maxLevel = number,
    effect = string
}
```

### 10. Asset Manager (`assets.lua`)

**Purpose**: Loads and manages game assets including images and audio.

**Asset Structure**:
```lua
Assets = {
    soldierWalkingImages = {},      -- Array of 17 frames
    soldierShootingImages = {},     -- Array of 17 frames
    zombieWalkingImages = {},       -- Array of 11 frames
    zombieAttackingImages = {},     -- Array of 17 frames
    floorTile = nil,                -- Floor texture
    music = nil                     -- Background music
}
```

## Key Data Flow Patterns

### Game State Flow
1. **PLAYING** → **SHOP** (between waves)
2. **PLAYING** → **GAME_OVER** (player death)
3. **PLAYING** → **VICTORY** (wave 10 completed)
4. **SHOP** → **PLAYING** (shop timer expires or player continues)

### Weapon Inventory Flow
1. Weapons can be in 3 equipped slots or unequipped inventory
2. Players can swap weapons between slots and inventory
3. Each weapon maintains its own ammo state

### Upgrade System Flow
1. Upgrades are purchased in the shop
2. Each upgrade has multiple levels with increasing costs
3. Upgrade effects are applied to player stats and weapon performance

### Enemy Spawning Flow
1. Enemies spawn based on wave progression
2. Different enemy types have weighted probabilities
3. Enemy difficulty scales with wave number

## Component Interactions

- **Main** coordinates all modules and manages the game loop
- **GameManager** controls game states and wave progression
- **Player** interacts with Weapons, Collision, and Shop systems
- **Enemy** entities are managed by GameManager and interact with Player
- **UI** displays information from Player, GameManager, and Shop
- **Shop** provides items that modify Player state
- **Assets** provides resources to all rendering components

This modular architecture allows for easy extension and maintenance of game features while maintaining clear separation of concerns.
