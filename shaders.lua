-- Shader effects module for post-processing
local Shaders = {}

function Shaders:new()
    local shaders = {
        activeShaders = {},
        shaderCache = {},
        canvas = nil
    }
    setmetatable(shaders, { __index = self })
    shaders:createCanvas()
    return shaders
end

-- Create a canvas for rendering the game to apply shaders
function Shaders:createCanvas()
    local w, h = love.graphics.getDimensions()
    self.canvas = love.graphics.newCanvas(w, h)
end

-- Load and compile a shader by name
function Shaders:loadShader(name, shaderCode)
    if self.shaderCache[name] then
        return self.shaderCache[name]
    end
    
    local success, shader = pcall(love.graphics.newShader, shaderCode)
    if success then
        self.shaderCache[name] = shader
        print("Loaded shader: " .. name)
        return shader
    else
        print("Failed to load shader " .. name .. ": " .. shader)
        return nil
    end
end

-- Register a shader with the system
function Shaders:registerShader(name, shaderCode)
    local shader = self:loadShader(name, shaderCode)
    return shader ~= nil
end

-- Activate a shader for a duration (0 = continuous)
function Shaders:activateShader(name, duration, intensity)
    if not self.shaderCache[name] then
        print("Shader not found: " .. name)
        return false
    end
    
    -- Remove existing instance of same shader
    for i = #self.activeShaders, 1, -1 do
        if self.activeShaders[i].name == name then
            table.remove(self.activeShaders, i)
        end
    end
    
    local shaderInstance = {
        name = name,
        shader = self.shaderCache[name],
        duration = duration or 0,
        elapsed = 0,
        intensity = intensity or 0.1,  -- Default intensity if not provided
        active = true
    }
    
    table.insert(self.activeShaders, shaderInstance)
    print("Activated shader: " .. name .. " for " .. (duration or 0) .. " seconds with intensity " .. shaderInstance.intensity)
    return true
end

-- Deactivate a shader by name
function Shaders:deactivateShader(name)
    for i = #self.activeShaders, 1, -1 do
        if self.activeShaders[i].name == name then
            table.remove(self.activeShaders, i)
            print("Deactivated shader: " .. name)
            return true
        end
    end
    return false
end

-- Update shader timers
function Shaders:update(dt)
    for i = #self.activeShaders, 1, -1 do
        local shader = self.activeShaders[i]
        if shader.duration > 0 then
            shader.elapsed = shader.elapsed + dt
            if shader.elapsed >= shader.duration then
                table.remove(self.activeShaders, i)
                print("Shader expired: " .. shader.name)
            end
        end
    end
end

-- Start capturing the game to canvas
function Shaders:beginCapture()
    love.graphics.setCanvas(self.canvas)
    love.graphics.clear()
end

-- End capture and apply shaders
function Shaders:endCapture()
    love.graphics.setCanvas()
    
    -- Apply shaders in order
    if #self.activeShaders > 0 then
        local currentCanvas = self.canvas
        
        for _, shaderInstance in ipairs(self.activeShaders) do
            local shader = shaderInstance.shader
            
            -- Set shader time uniform if it exists
            if shader:hasUniform("time") then
                shader:send("time", love.timer.getTime())
            end
            
            -- Set shader intensity uniform if it exists
            if shader:hasUniform("intensity") then
                shader:send("intensity", shaderInstance.intensity)
            end
            
            -- Set shader progress uniform if it exists (for timed shaders)
            if shader:hasUniform("progress") and shaderInstance.duration > 0 then
                shader:send("progress", shaderInstance.elapsed / shaderInstance.duration)
            end
            
            love.graphics.setShader(shader)
            love.graphics.draw(currentCanvas, 0, 0)
            love.graphics.setShader()
        end
    else
        -- No shaders, just draw the canvas
        love.graphics.draw(self.canvas, 0, 0)
    end
end

-- Check if a shader is currently active
function Shaders:isShaderActive(name)
    for _, shader in ipairs(self.activeShaders) do
        if shader.name == name then
            return true
        end
    end
    return false
end

-- Get list of active shader names
function Shaders:getActiveShaders()
    local names = {}
    for _, shader in ipairs(self.activeShaders) do
        table.insert(names, shader.name)
    end
    return names
end

-- Initialize default shaders
function Shaders:initializeDefaultShaders(debugMode)
    -- Test shaders (only in debug mode)
    if debugMode then
        -- Test shader 1: Red tint (activated with 'k')
        local redTintShader = [[
            extern number time;
            
            vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
                vec4 pixel = Texel(texture, texture_coords);
                float pulse = sin(time * 5.0) * 0.3 + 0.7;
                pixel.r *= pulse;
                pixel.g *= 0.5;
                pixel.b *= 0.5;
                return pixel;
            }
        ]]
        
        -- Test shader 2: Blue wave (activated with 't')
        local blueWaveShader = [[
            extern number time;
            extern number progress;
            
            vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
                vec4 pixel = Texel(texture, texture_coords);
                
                // Create wave effect based on progress
                float wave = sin(screen_coords.y * 0.05 + time * 10.0) * 0.1 * progress;
                float wave2 = cos(screen_coords.x * 0.03 + time * 8.0) * 0.05 * progress;
                
                // Apply blue tint that fades with progress
                float blueIntensity = 1.0 - progress * 0.5;
                pixel.b += (wave + wave2) * blueIntensity;
                pixel.r *= (1.0 - progress * 0.3);
                pixel.g *= (1.0 - progress * 0.3);
                
                return pixel;
            }
        ]]
        
        -- Register the debug shaders
        self:registerShader("red_tint", redTintShader)
        self:registerShader("blue_wave", blueWaveShader)
        
        print("Initialized debug shaders: red_tint, blue_wave")
    end
    
    -- Screen shake shader (always available)
    local screenShakeShader = [[
        extern number time;
        extern number intensity;
        extern number progress;

        vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
            // Calculate shake amount based on intensity and progress
            float shakeIntensity = intensity * 5 * (1.0 - progress);
            
            // Create random-ish shake using sine waves with different frequencies
            float shakeX = sin(time * 30.0) * shakeIntensity;
            float shakeY = cos(time * 25.0) * shakeIntensity;
            
            // Apply the shake to screen coordinates (in pixels)
            vec2 shakenCoords = screen_coords + vec2(shakeX, shakeY);
            
            // Convert back to texture coordinates
            vec2 shakenTexCoords = shakenCoords / love_ScreenSize.xy;
            
            // Clamp to avoid sampling outside texture
            shakenTexCoords = clamp(shakenTexCoords, 0.0, 1.0);
            
            return Texel(texture, shakenTexCoords);
        }
    ]]
    
    -- Register the screen shake shader
    self:registerShader("screen_shake", screenShakeShader)
    
    print("Initialized screen shake shader")
end

return Shaders
