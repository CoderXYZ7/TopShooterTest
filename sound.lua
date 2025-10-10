-- Sound Management Module
local SoundManager = {}

function SoundManager:new()
    local manager = {
        -- Sound sources
        sounds = {},
        music = nil,
        currentMusic = nil,
        
        -- Volume levels (0.0 to 1.0)
        musicVolume = 0.5,
        soundVolume = 0.7,
        
        -- Sound categories
        categories = {
            GUNSHOT = "gunshot",
            RELOAD = "reload",
            ENEMY_HIT = "enemy_hit",
            ENEMY_DEATH = "enemy_death",
            PLAYER_HIT = "player_hit",
            PICKUP = "pickup",
            UI = "ui",
            DASH = "dash",
            WEAPON_SWITCH = "weapon_switch"
        },
        
        -- Sound pools for frequently played sounds
        soundPools = {}
    }
    setmetatable(manager, { __index = self })
    return manager
end

function SoundManager:load()
    -- Load sound effects
    -- Note: In a real implementation, you would load actual sound files
    -- For now, we'll create placeholder sound sources
    
    -- Create placeholder sounds for different categories
    self.sounds = {
        [self.categories.GUNSHOT] = {
            name = "Gunshot",
            volume = 0.8,
            pitchVariation = 0.1
        },
        [self.categories.RELOAD] = {
            name = "Reload",
            volume = 0.6,
            pitchVariation = 0.05
        },
        [self.categories.ENEMY_HIT] = {
            name = "Enemy Hit",
            volume = 0.7,
            pitchVariation = 0.15
        },
        [self.categories.ENEMY_DEATH] = {
            name = "Enemy Death",
            volume = 0.9,
            pitchVariation = 0.1
        },
        [self.categories.PLAYER_HIT] = {
            name = "Player Hit",
            volume = 0.8,
            pitchVariation = 0.1
        },
        [self.categories.PICKUP] = {
            name = "Pickup",
            volume = 0.5,
            pitchVariation = 0.05
        },
        [self.categories.UI] = {
            name = "UI",
            volume = 0.4,
            pitchVariation = 0.0
        },
        [self.categories.DASH] = {
            name = "Dash",
            volume = 0.6,
            pitchVariation = 0.1
        },
        [self.categories.WEAPON_SWITCH] = {
            name = "Weapon Switch",
            volume = 0.3,
            pitchVariation = 0.05
        }
    }
    
    -- Load actual music file
    if love.filesystem.getInfo('assets/music/space-marine-theme.ogg') then
        self.music = love.audio.newSource('assets/music/space-marine-theme.ogg', 'stream')
        self.music:setLooping(true)
        self.music:setVolume(self.musicVolume)
        print("SoundManager: Loaded music - assets/music/space-marine-theme.ogg")
    else
        print("SoundManager: Music file not found - assets/music/space-marine-theme.ogg")
    end
    
    -- Initialize sound pools
    for category, _ in pairs(self.sounds) do
        self.soundPools[category] = {}
    end
    
    print("SoundManager: Loaded sound system with " .. self:getSoundCount() .. " sound categories")
end

function SoundManager:playSound(category, x, y)
    if not self.sounds[category] then
        print("SoundManager: Unknown sound category - " .. tostring(category))
        return
    end
    
    local soundConfig = self.sounds[category]
    
    -- Calculate final volume with distance attenuation
    local finalVolume = soundConfig.volume * self.soundVolume
    
    -- Apply distance attenuation if position is provided
    if x and y then
        -- Simple distance-based volume (placeholder for spatial audio)
        local playerX, playerY = 400, 300  -- Assuming center of screen
        local distance = math.sqrt((x - playerX)^2 + (y - playerY)^2)
        local maxDistance = 800
        local attenuation = math.max(0, 1 - (distance / maxDistance))
        finalVolume = finalVolume * attenuation
    end
    
    -- Apply pitch variation for natural sound
    local pitch = 1.0
    if soundConfig.pitchVariation > 0 then
        pitch = math.random(100 - soundConfig.pitchVariation * 100, 100 + soundConfig.pitchVariation * 100) / 100
    end
    
    -- In a real implementation, you would play the actual sound here
    -- For now, we'll just print the sound being played
    local positionInfo = x and y and string.format(" at (%d, %d)", math.floor(x), math.floor(y)) or ""
    print(string.format("SoundManager: Playing %s (vol: %.1f, pitch: %.2f)%s", 
          soundConfig.name, finalVolume, pitch, positionInfo))
    
    return true
end

function SoundManager:playMusic(trackName, loop)
    if self.currentMusic == trackName then
        return  -- Already playing this track
    end
    
    self.currentMusic = trackName
    
    -- Actually play the music file
    if self.music then
        self.music:setLooping(loop or true)
        self.music:setVolume(self.musicVolume)
        love.audio.play(self.music)
        local loopInfo = loop and " (looping)" or ""
        print(string.format("SoundManager: Playing music - %s (vol: %.1f)%s", 
              trackName, self.musicVolume, loopInfo))
    else
        print("SoundManager: No music loaded to play")
    end
    
    return true
end

function SoundManager:stopMusic()
    if self.music then
        love.audio.stop(self.music)
        print("SoundManager: Stopping music")
    end
    self.currentMusic = nil
end

function SoundManager:setMusicVolume(volume)
    self.musicVolume = math.max(0, math.min(1, volume))
    
    -- Update the actual music source volume
    if self.music then
        self.music:setVolume(self.musicVolume)
    end
    
    print("SoundManager: Music volume set to " .. string.format("%.0f%%", self.musicVolume * 100))
end

function SoundManager:setSoundVolume(volume)
    self.soundVolume = math.max(0, math.min(1, volume))
    
    -- In a real implementation, you would update all sound sources
    print("SoundManager: Sound volume set to " .. string.format("%.0f%%", self.soundVolume * 100))
end

function SoundManager:getMusicVolume()
    return self.musicVolume
end

function SoundManager:getSoundVolume()
    return self.soundVolume
end

function SoundManager:getSoundCount()
    local count = 0
    for _ in pairs(self.sounds) do
        count = count + 1
    end
    return count
end

function SoundManager:getCategories()
    return self.categories
end

function SoundManager:pauseAll()
    -- In a real implementation, you would pause all playing sounds
    print("SoundManager: All sounds paused")
end

function SoundManager:resumeAll()
    -- In a real implementation, you would resume all paused sounds
    print("SoundManager: All sounds resumed")
end

function SoundManager:update(dt)
    -- Update sound pools and clean up finished sounds
    -- In a real implementation, you would manage sound instances here
end

-- Convenience methods for common game sounds
function SoundManager:playGunshot(x, y)
    return self:playSound(self.categories.GUNSHOT, x, y)
end

function SoundManager:playReload()
    return self:playSound(self.categories.RELOAD)
end

function SoundManager:playEnemyHit(x, y)
    return self:playSound(self.categories.ENEMY_HIT, x, y)
end

function SoundManager:playEnemyDeath(x, y)
    return self:playSound(self.categories.ENEMY_DEATH, x, y)
end

function SoundManager:playPlayerHit()
    return self:playSound(self.categories.PLAYER_HIT)
end

function SoundManager:playPickup(x, y)
    return self:playSound(self.categories.PICKUP, x, y)
end

function SoundManager:playUISound()
    return self:playSound(self.categories.UI)
end

function SoundManager:playDash()
    return self:playSound(self.categories.DASH)
end

function SoundManager:playWeaponSwitch()
    return self:playSound(self.categories.WEAPON_SWITCH)
end

return SoundManager
