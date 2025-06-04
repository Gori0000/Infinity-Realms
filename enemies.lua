local Enemies = {}

Enemies.list = {}
Enemies.boss = nil
Enemies.bossSpawned = false
Enemies.spawnTimer = 0

-- These should match the keys in Assets.enemies table
local availableEnemySpriteKeys = {"slime", "skeleton", "bird", "zombie", "treant"}

-- Internal function to handle common death processing
local function _handleEnemyDeathProcess(enemy, addExpCb, incrementKillsCb, dropLootCb)
    if addExpCb then addExpCb(enemy.exp or 0) end
    if incrementKillsCb then incrementKillsCb() end
    if dropLootCb then dropLootCb(enemy.x, enemy.y) end
end

function Enemies.initialize()
    Enemies.list = {}
    Enemies.boss = nil
    Enemies.bossSpawned = false
    Enemies.spawnTimer = 0
end

function Enemies.flash(enemyRef, color, duration)
    if not enemyRef then return end
    enemyRef.isFlashing = true
    enemyRef.flashColor = color
    enemyRef.flashDuration = duration
    enemyRef.flashTimer = duration -- Use a separate timer to count down
end

function Enemies.spawnRegularEnemy(realmNumber)
    local mult = 1 + (realmNumber - 1) * 0.25
    local x = math.random((Config and Config.windowWidth) or 800)
    local y = math.random((Config and Config.windowHeight) or 600)

    local enemySpriteKey = availableEnemySpriteKeys[math.random(#availableEnemySpriteKeys)]
    local initialHp = 30 * mult
    local baseSpeed = 60 -- Default base speed
    local enemyBaseRadius = 24 -- Default base radius for regular enemies
    table.insert(Enemies.list, {
        x = x, y = y,
        baseRadius = enemyBaseRadius, -- Store baseRadius
        radius = enemyBaseRadius,     -- Initial radius, will be updated
        speed = baseSpeed,
        originalSpeed = baseSpeed,
        hp = initialHp,
        maxHp = initialHp,
        exp = 10 * mult,
        spriteKey = enemySpriteKey,
        statusEffects = {} -- Initialize status effects table
    })
end

function Enemies.spawnBoss()
    local initialBossHp = 1000
    local baseSpeed = 40 -- Default boss base speed
    local bossBaseRadius = 60 -- Default base radius for boss
    Enemies.boss = {
        x = 400, y = 50,
        baseRadius = bossBaseRadius, -- Store baseRadius
        radius = bossBaseRadius,     -- Initial radius, will be updated
        speed = baseSpeed,
        originalSpeed = baseSpeed,
        hp = initialBossHp,
        maxHp = initialBossHp,
        exp = 500,
        spriteKey = nil,
        statusEffects = {} -- Initialize status effects table
    }
    Enemies.bossSpawned = true
end

function Enemies.applyStatusEffect(enemyRef, effectName, duration, magnitude, relatedData)
    if not enemyRef or not enemyRef.statusEffects then
        print("Warning: Attempted to apply status effect to invalid enemyRef.")
        return
    end
    -- print("Applying effect: " .. effectName .. " to enemy. Duration: " .. duration .. ", Mag: " .. magnitude)
    enemyRef.statusEffects[effectName] = {
        timer = duration,
        magnitude = magnitude,
        data = relatedData or {}
    }
end

function Enemies.update(dt, playerData, realmProviderFunc, killsProviderFunc, playerRefForCallbacks, gameRefForCallbacks)
    Enemies.spawnTimer = Enemies.spawnTimer - dt
    if Enemies.spawnTimer <= 0 and not Enemies.bossSpawned then
        local currentRealm = realmProviderFunc()
        Enemies.spawnRegularEnemy(currentRealm)
        Enemies.spawnTimer = 1
    end

    if killsProviderFunc() >= 100 and not Enemies.bossSpawned and not Enemies.boss then
        Enemies.spawnBoss()
    end

    local enemiesToRemoveIndices = {} -- Store indices of enemies to remove

    -- Update regular enemies
    for i = #Enemies.list, 1, -1 do
        local e = Enemies.list[i]
        if not e then goto next_enemy_loop end

        -- Update dynamic radius based on DebugSettings
        e.radius = (e.baseRadius or 24) * (DebugSettings and DebugSettings.hitboxScale or 1.0)

        local currentSpeedModifier = 0
        local effectsToRemove = {}
        local accumulatedBurnDamage = 0
        local accumulatedDotDamage = 0 -- For DOT effects

        if e.statusEffects then
            for effectName, effectData in pairs(e.statusEffects) do
                effectData.timer = effectData.timer - dt
                if effectData.timer <= 0 then
                    table.insert(effectsToRemove, effectName)
                else
                    if effectName == "slow" then
                        currentSpeedModifier = math.max(currentSpeedModifier, effectData.magnitude)
                    elseif effectName == "burn" then
                        accumulatedBurnDamage = accumulatedBurnDamage + (effectData.magnitude * dt)
                    elseif effectName == "dot" then -- Handle DOT
                        accumulatedDotDamage = accumulatedDotDamage + (effectData.magnitude * dt)
                    end
                end
            end
            for _, effectName in ipairs(effectsToRemove) do
                e.statusEffects[effectName] = nil
            end
        end

        e.speed = e.originalSpeed * (1 - currentSpeedModifier)

        if accumulatedBurnDamage > 0 then
            e.hp = e.hp - accumulatedBurnDamage
        end
        if accumulatedDotDamage > 0 then -- Apply DOT damage
            e.hp = e.hp - accumulatedDotDamage
        end

        if e.hp <= 0 then -- Check for death after all damage sources for the frame
            if playerRefForCallbacks and gameRefForCallbacks then
                local addExperienceCb = function(exp) playerRefForCallbacks.exp = playerRefForCallbacks.exp + exp end
                local incrementPlayerKillsCb = function() playerRefForCallbacks.kills = playerRefForCallbacks.kills + 1 end
                local dropLootAtPositionCb = function(lx, ly) gameRefForCallbacks.dropLoot(lx, ly, playerRefForCallbacks) end
                _handleEnemyDeathProcess(e, addExperienceCb, incrementPlayerKillsCb, dropLootAtPositionCb)
            else
                print("Warning: Callbacks not available for DoT death processing for enemy.")
            end
            table.insert(enemiesToRemoveIndices, i)
            goto next_enemy_loop -- Skip movement if dead
        end

        local angle = math.atan2(playerData.y - e.y, playerData.x - e.x)
        e.x = e.x + math.cos(angle) * e.speed * dt
        e.y = e.y + math.sin(angle) * e.speed * dt

        -- Update flash effect
        if e.isFlashing then
            e.flashTimer = e.flashTimer - dt
            if e.flashTimer <= 0 then
                e.isFlashing = false
                e.flashColor = nil
                e.flashDuration = nil
                e.flashTimer = nil
            end
        end
        ::next_enemy_loop::
    end

    -- Remove dead enemies (from burn)
    -- Sort indices in descending order to remove correctly
    table.sort(enemiesToRemoveIndices, function(a,b) return a > b end)
    for _, index in ipairs(enemiesToRemoveIndices) do
        table.remove(Enemies.list, index)
    end

    -- Update Boss
    if Enemies.boss then
        local boss = Enemies.boss
        -- Update dynamic radius for boss
        boss.radius = (boss.baseRadius or 60) * (DebugSettings and DebugSettings.hitboxScale or 1.0)

        local currentSpeedModifier = 0
        local effectsToRemove = {}
        local accumulatedBurnDamage = 0
        local accumulatedDotDamage = 0 -- For DOT effects

        if boss.statusEffects then
            for effectName, effectData in pairs(boss.statusEffects) do
                effectData.timer = effectData.timer - dt
                if effectData.timer <= 0 then
                    table.insert(effectsToRemove, effectName)
                else
                    if effectName == "slow" then
                        currentSpeedModifier = math.max(currentSpeedModifier, effectData.magnitude)
                    elseif effectName == "burn" then
                        accumulatedBurnDamage = accumulatedBurnDamage + (effectData.magnitude * dt)
                    elseif effectName == "dot" then -- Handle DOT for boss
                        accumulatedDotDamage = accumulatedDotDamage + (effectData.magnitude * dt)
                    end
                end
            end
            for _, effectName in ipairs(effectsToRemove) do
                boss.statusEffects[effectName] = nil
            end
        end

        boss.speed = boss.originalSpeed * (1 - currentSpeedModifier)

        if accumulatedBurnDamage > 0 then
            boss.hp = boss.hp - accumulatedBurnDamage
        end
        if accumulatedDotDamage > 0 then -- Apply DOT damage to boss
            boss.hp = boss.hp - accumulatedDotDamage
        end

        if boss.hp <= 0 then
            if playerRefForCallbacks and gameRefForCallbacks then
                local addExperienceCb = function(exp) playerRefForCallbacks.exp = playerRefForCallbacks.exp + exp end
                local incrementPlayerKillsCb = function() playerRefForCallbacks.kills = playerRefForCallbacks.kills + 1 end
                local dropLootAtPositionCb = function(lx, ly) gameRefForCallbacks.dropLoot(lx, ly, playerRefForCallbacks) end
                _handleEnemyDeathProcess(boss, addExperienceCb, incrementPlayerKillsCb, dropLootAtPositionCb)
            else
                print("Warning: Callbacks not available for DoT death processing for boss.")
            end
            Enemies.boss = nil -- Boss is defeated
        end

        if Enemies.boss then -- Check if boss still exists after all damage
            local angle = math.atan2(playerData.y - boss.y, playerData.x - boss.x)
            boss.x = boss.x + math.cos(angle) * boss.speed * dt
            boss.y = boss.y + math.sin(angle) * boss.speed * dt
        end

        -- Update boss flash effect
        if Enemies.boss and Enemies.boss.isFlashing then
            Enemies.boss.flashTimer = Enemies.boss.flashTimer - dt
            if Enemies.boss.flashTimer <= 0 then
                Enemies.boss.isFlashing = false
                Enemies.boss.flashColor = nil
                Enemies.boss.flashDuration = nil
                Enemies.boss.flashTimer = nil
            end
        end
    end
end

function Enemies.draw()
    love.graphics.setColor(1, 1, 1)

    -- Use DebugSettings for enemyScale
    local currentEnemyScale = (DebugSettings and DebugSettings.enemyScale) or 1
    if not DebugSettings then
        print("Warning: DebugSettings not available in Enemies.draw(), using default scale 1.")
    end

    -- Health Bar properties
    local healthBarHeight = 5
    local healthBarYOffset = 7 -- Adjusted offset
    local healthBarBgColor = {0.3, 0.1, 0.1, 0.8} -- Darker Red
    local healthBarFgColor = {0.8, 0.2, 0.2, 0.9} -- Brighter Red
    local healthBarBorderColor = {0.1, 0.1, 0.1, 1} -- Black border
    local healthBarBorderSize = 0.5 -- pixels for border

    for _, enemy in ipairs(Enemies.list) do
        local originalColor = {love.graphics.getColor()} -- Store current color

        if enemy.isFlashing and enemy.flashColor then
            love.graphics.setColor(unpack(enemy.flashColor))
        end

        if Assets and Assets.enemies and Assets.enemies[enemy.spriteKey] then
            local enemyImage = Assets.enemies[enemy.spriteKey]
            local width = enemyImage:getWidth()
            local height = enemyImage:getHeight()
            love.graphics.draw(enemyImage, enemy.x, enemy.y, 0, currentEnemyScale, currentEnemyScale, width / 2, height / 2)
        else
            if Assets and Assets.enemies then
                print("Warning: Missing sprite for enemy type: " .. (enemy.spriteKey or "unknown") .. ". Drawing circle.")
            end
            -- If not flashing, use default red for fallback circle, else flashColor is already set
            if not (enemy.isFlashing and enemy.flashColor) then love.graphics.setColor(1,0,0) end
            love.graphics.circle("fill", enemy.x, enemy.y, enemy.radius or 12)
            -- love.graphics.setColor(1, 1, 1) -- Reset color after drawing fallback (handled by originalColor restore)
        end

        if enemy.isFlashing then -- Reset color to original after drawing
            love.graphics.setColor(unpack(originalColor))
        end

        -- After drawing sprite:
        if enemy.hp and enemy.maxHp and enemy.maxHp > 0 then
            local hpPercent = math.max(0, math.min(1, enemy.hp / enemy.maxHp))

            local spriteOriginalHeight = 0
            if Assets and Assets.enemies and Assets.enemies[enemy.spriteKey] then
                 spriteOriginalHeight = Assets.enemies[enemy.spriteKey]:getHeight()
            else
                 spriteOriginalHeight = (enemy.baseRadius or 12) * 2 -- Fallback if no sprite, use baseRadius for consistency
            end
            local scaledSpriteHalfHeight = (spriteOriginalHeight * currentEnemyScale) / 2

            local barWidth = (enemy.radius or enemy.baseRadius or 12) * 2.0 -- Bar width based on dynamic enemy radius
            local barX = enemy.x - barWidth / 2
            local barY = enemy.y - scaledSpriteHalfHeight - healthBarYOffset

            love.graphics.setColor(unpack(healthBarBorderColor))
            love.graphics.rectangle("fill", barX - healthBarBorderSize, barY - healthBarBorderSize, barWidth + 2*healthBarBorderSize, healthBarHeight + 2*healthBarBorderSize)

            love.graphics.setColor(unpack(healthBarBgColor))
            love.graphics.rectangle("fill", barX, barY, barWidth, healthBarHeight)

            love.graphics.setColor(unpack(healthBarFgColor))
            love.graphics.rectangle("fill", barX, barY, barWidth * hpPercent, healthBarHeight)

            love.graphics.setColor(1, 1, 1) -- Reset color after drawing this health bar
        end

        -- Draw hitbox for regular enemy
        if enemy and enemy.radius then
            love.graphics.setColor(1, 1, 0, 0.5) -- Yellow, semi-transparent
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", enemy.x, enemy.y, enemy.radius)
            love.graphics.setColor(1, 1, 1) -- Reset color
        end
    end
    -- love.graphics.setColor(1, 1, 1) -- This reset is now inside the loop or after boss

    if Enemies.boss then
        local originalBossColor = {love.graphics.getColor()} -- Store current color
        if Enemies.boss.isFlashing and Enemies.boss.flashColor then
            love.graphics.setColor(unpack(Enemies.boss.flashColor))
        end

        local bossScaleToUse = (DebugSettings and DebugSettings.defaultSpriteScale) or 1 -- Use DebugSettings
        if Enemies.boss.spriteKey and Assets and Assets.enemies and Assets.enemies[Enemies.boss.spriteKey] then
            local bossImage = Assets.enemies[Enemies.boss.spriteKey]
            local width = bossImage:getWidth()
            local height = bossImage:getHeight()
            love.graphics.draw(bossImage, Enemies.boss.x, Enemies.boss.y, 0, bossScaleToUse, bossScaleToUse, width/2, height/2)
        else
            -- If not flashing, use default dark red for fallback circle, else flashColor is already set
            if not (Enemies.boss.isFlashing and Enemies.boss.flashColor) then love.graphics.setColor(0.5, 0, 0) end
            love.graphics.circle("fill", Enemies.boss.x, Enemies.boss.y, Enemies.boss.radius or 40)
            -- love.graphics.setColor(1, 1, 1) -- Reset color after drawing fallback (handled by originalBossColor restore)
        end

        if Enemies.boss.isFlashing then -- Reset color to original after drawing
            love.graphics.setColor(unpack(originalBossColor))
        end

        -- After drawing boss sprite:
        if Enemies.boss.hp and Enemies.boss.maxHp and Enemies.boss.maxHp > 0 then
            local bossHpPercent = math.max(0, math.min(1, Enemies.boss.hp / Enemies.boss.maxHp))
            local bossScaledRadius = (Enemies.boss.radius or 40)

            local bossBarWidth = bossScaledRadius * 2.0
            local bossBarX = Enemies.boss.x - bossBarWidth / 2

            local bossSpriteOriginalHeight = 0
            if Enemies.boss.spriteKey and Assets and Assets.enemies and Assets.enemies[Enemies.boss.spriteKey] then
                 bossSpriteOriginalHeight = Assets.enemies[Enemies.boss.spriteKey]:getHeight()
            else
                 bossSpriteOriginalHeight = (Enemies.boss.baseRadius or 40) * 2 -- Fallback, use baseRadius
            end
            local bossScaledSpriteHalfHeight = (bossSpriteOriginalHeight * bossScaleToUse) / 2

            local bossBarY = Enemies.boss.y - bossScaledSpriteHalfHeight - (healthBarYOffset + 5) -- Slightly larger offset for boss
            local bossHealthBarHeight = healthBarHeight + 2 -- Slightly thicker bar for boss

            love.graphics.setColor(unpack(healthBarBorderColor))
            love.graphics.rectangle("fill", bossBarX - healthBarBorderSize, bossBarY - healthBarBorderSize, bossBarWidth + 2*healthBarBorderSize, bossHealthBarHeight + 2*healthBarBorderSize)

            love.graphics.setColor(unpack(healthBarBgColor))
            love.graphics.rectangle("fill", bossBarX, bossBarY, bossBarWidth, bossHealthBarHeight)

            love.graphics.setColor(unpack(healthBarFgColor))
            love.graphics.rectangle("fill", bossBarX, bossBarY, bossBarWidth * bossHpPercent, bossHealthBarHeight)

            love.graphics.setColor(1, 1, 1) -- Reset color after drawing boss health bar
        end

        -- Draw hitbox for boss
        if Enemies.boss.radius then
            love.graphics.setColor(1, 1, 0, 0.5) -- Yellow, semi-transparent
            love.graphics.setLineWidth(1)
            love.graphics.circle("line", Enemies.boss.x, Enemies.boss.y, Enemies.boss.radius)
            love.graphics.setColor(1, 1, 1) -- Reset color
        end
    end
    love.graphics.setColor(1, 1, 1) -- Final safety reset
end

function Enemies.reset()
    Enemies.list = {}
    Enemies.boss = nil
    Enemies.bossSpawned = false
    Enemies.spawnTimer = 0
end

function Enemies.getList()
    return Enemies.list
end

function Enemies.getBoss()
    return Enemies.boss
end

function Enemies.damageEnemy(enemy, damageAmount, index, addExpCallback, incrementKillsCallback, dropLootCallback)
    if not enemy then return false end
    enemy.hp = enemy.hp - damageAmount
    if enemy.hp <= 0 then
        _handleEnemyDeathProcess(enemy, addExpCallback, incrementKillsCallback, dropLootCallback)
        table.remove(Enemies.list, index)
        return true
    end
    return false
end

function Enemies.damageBoss(damageAmount, addExpCallback, incrementKillsCallback, dropLootCallback)
    if not Enemies.boss then return false end

    Enemies.boss.hp = Enemies.boss.hp - damageAmount
    if Enemies.boss.hp <= 0 then
        _handleEnemyDeathProcess(Enemies.boss, addExpCallback, incrementKillsCallback, dropLootCallback)
        Enemies.boss = nil
        return true
    end
    return false
end

return Enemies
