local Effects = {}

Effects.activeEffects = {}

--[[
effectData might include:
{
    type = "particle_burst", -- or "line", "expanding_circle", etc.
    x = 0, y = 0,
    duration = 1, -- seconds
    particles = { -- if type is particle_burst
        {
            x = 0, y = 0, -- relative to effect x,y or absolute
            dx = 0, dy = 0, -- velocity
            size = 5,
            color = {1,0,0,1},
            life = 1,
            shape = "circle" -- or "rectangle"
        },
        -- ... more particles
    },
    -- other type-specific data:
    -- radius, endRadius (for expanding_circle)
    -- x2, y2 (for line)
    -- color, size (for single particle effects)
}
--]]

function Effects.add(effectData)
    if not effectData.duration then effectData.duration = 1 end -- Default duration
    effectData.life = effectData.duration
    table.insert(Effects.activeEffects, effectData)
end

function Effects.update(dt)
    for i = #Effects.activeEffects, 1, -1 do
        local effect = Effects.activeEffects[i]
        effect.life = effect.life - dt

        if effect.type == "particle_burst" and effect.particles then
            for _, p in ipairs(effect.particles) do
                if p.life > 0 then
                    p.x = p.x + (p.dx or 0) * dt
                    p.y = p.y + (p.dy or 0) * dt
                    p.life = p.life - dt
                    if p.size_decay then
                        p.size = math.max(0, p.size - p.size_decay * dt)
                    end
                end
            end
        elseif effect.type == "expanding_circle" then
            if effect.currentRadius and effect.targetRadius and effect.expandRate then
                effect.currentRadius = effect.currentRadius + effect.expandRate * dt
                if effect.currentRadius > effect.targetRadius then
                    effect.currentRadius = effect.targetRadius
                end
            end
        elseif effect.type == "line_fade" then
            -- Line itself doesn't move, just fades via its main life property
        end


        if effect.life <= 0 then
            table.remove(Effects.activeEffects, i)
        end
    end
end

function Effects.draw()
    for _, effect in ipairs(Effects.activeEffects) do
        local alpha_multiplier = math.max(0, effect.life / (effect.duration or 1))

        if effect.type == "particle_burst" and effect.particles then
            for _, p in ipairs(effect.particles) do
                if p.life > 0 then
                    local r,g,b,a = unpack(p.color)
                    love.graphics.setColor(r, g, b, a * alpha_multiplier * (p.life / (p.initial_life or 1)))
                    if p.shape == "circle" then
                        love.graphics.circle("fill", effect.x + p.x, effect.y + p.y, p.size)
                    elseif p.shape == "rectangle" then
                        love.graphics.rectangle("fill", effect.x + p.x - p.size/2, effect.y + p.y - p.size/2, p.size, p.size)
                    end
                end
            end
        elseif effect.type == "expanding_circle" then
            if effect.currentRadius and effect.color then
                local r,g,b,a = unpack(effect.color)
                love.graphics.setColor(r,g,b,a * alpha_multiplier)
                love.graphics.circle("line", effect.x, effect.y, effect.currentRadius)
            end
        elseif effect.type == "line_fade" then
            if effect.x1 and effect.y1 and effect.x2 and effect.y2 and effect.color and effect.width then
                local r,g,b,a = unpack(effect.color)
                love.graphics.setColor(r,g,b,a * alpha_multiplier)
                love.graphics.setLineWidth(effect.width)
                love.graphics.line(effect.x1, effect.y1, effect.x2, effect.y2)
                love.graphics.setLineWidth(1) -- Reset
            end
        end
    end
    love.graphics.setColor(1,1,1,1) -- Reset color
end

-- Screen Shake related properties
Effects.screenShakeDuration = 0
Effects.screenShakeIntensity = 0

function Effects.startScreenShake(intensity, duration)
    Effects.screenShakeIntensity = intensity
    Effects.screenShakeDuration = duration
    print("Screen shake started: intensity " .. intensity .. ", duration " .. duration)
end

-- Spell-specific effect creation functions

-- Fireball
function Effects.createFireballTrail(x, y)
    local numParticles = 3 -- Number of particles per trail segment
    local trailEffect = {
        type = "particle_burst",
        x = x, y = y,
        duration = 0.3, -- Short duration, trail fades quickly
        particles = {}
    }
    for i = 1, numParticles do
        table.insert(trailEffect.particles, {
            x = (math.random() - 0.5) * 10, -- Scatter around origin
            y = (math.random() - 0.5) * 10,
            dx = (math.random() - 0.5) * 20, -- Slow drift
            dy = (math.random() - 0.5) * 20,
            size = math.random(2, 4),
            size_decay = math.random(3,6), -- Make them shrink
            color = {1, math.random(0, 100)/255, 0, 0.8}, -- Red to Orange-Red
            life = 0.3,
            initial_life = 0.3,
            shape = "circle"
        })
    end
    Effects.add(trailEffect)
end

function Effects.createFireballExplosion(x, y)
    local explosionEffect = {
        type = "particle_burst",
        x = x, y = y,
        duration = 0.5,
        particles = {}
    }
    for i = 1, 20 do -- More particles for explosion
        local angle = math.random() * 2 * math.pi
        local speed = math.random(50, 150)
        table.insert(explosionEffect.particles, {
            x = 0, y = 0, -- Start at explosion center
            dx = math.cos(angle) * speed,
            dy = math.sin(angle) * speed,
            size = math.random(5, 10),
            size_decay = math.random(10,20),
            color = {1, math.random(100, 200)/255, 0, 0.9}, -- Orange to Yellow
            life = 0.5,
            initial_life = 0.5,
            shape = "circle"
        })
    end
    Effects.add(explosionEffect)
    Effects.startScreenShake(5, 0.2)
end

-- Ice Lance
function Effects.createIceLanceTrail(x, y)
    local numParticles = 2
    local trailEffect = {
        type = "particle_burst",
        x = x, y = y,
        duration = 0.25,
        particles = {}
    }
    for i = 1, numParticles do
        table.insert(trailEffect.particles, {
            x = (math.random() - 0.5) * 6, y = (math.random() - 0.5) * 6,
            dx = (math.random() - 0.5) * 15, dy = (math.random() - 0.5) * 15,
            size = math.random(2, 3),
            size_decay = math.random(4,8),
            color = {0.5, 0.8, 1, 0.7}, -- Light Blue
            life = 0.25,
            initial_life = 0.25,
            shape = "rectangle"
        })
    end
    Effects.add(trailEffect)
end

function Effects.createIcePuff(x, y)
    local puffEffect = {
        type = "particle_burst",
        x = x, y = y,
        duration = 0.4,
        particles = {}
    }
    for i = 1, 15 do
        local angle = math.random() * 2 * math.pi
        local speed = math.random(20, 80)
        table.insert(puffEffect.particles, {
            x = 0, y = 0,
            dx = math.cos(angle) * speed,
            dy = math.sin(angle) * speed,
            size = math.random(4, 8),
            size_decay = math.random(8,16),
            color = {0.8, 0.9, 1, 0.8}, -- White / Very Light Blue
            life = 0.4,
            initial_life = 0.4,
            shape = "circle"
        })
    end
    Effects.add(puffEffect)
end

-- Chain Bolt
function Effects.createChainBoltVisual(x1, y1, x2, y2)
    local boltEffect = {
        type = "line_fade",
        x1 = x1, y1 = y1,
        x2 = x2, y2 = y2,
        width = 3,
        color = {1, 1, 0.5, 0.9}, -- Yellow-white
        duration = 0.2, -- Fades quickly
    }
    Effects.add(boltEffect)
end

-- Arcane Wave
function Effects.createArcaneWavePulse(x, y, targetRadius)
    local pulseEffect = {
        type = "expanding_circle",
        x = x, y = y,
        currentRadius = targetRadius * 0.1, -- Start small
        targetRadius = targetRadius,
        expandRate = targetRadius * 2.5, -- Expand over 0.4 seconds (duration)
        color = {0.7, 0.5, 1, 0.8}, -- Arcane purple/pink
        duration = 0.4,
    }
    Effects.add(pulseEffect)
end

-- Void Beam
function Effects.createVoidBeamVisual(x1, y1, x2, y2, width, duration)
    local beamEffect = {
        type = "line_fade", -- Use line_fade for a beam that persists then fades
        x1 = x1, y1 = y1,
        x2 = x2, y2 = y2,
        width = width,
        color = {0.2, 0, 0.2, 0.6}, -- Dark Purple/Black
        duration = duration, -- Match spell's visual duration
    }
    Effects.add(beamEffect)
end


return Effects
