local Enemies = {}

Enemies.list = {}
Enemies.boss = nil
Enemies.bossSpawned = false
Enemies.spawnTimer = 0

-- These should match the keys in Assets.enemies table
local availableEnemySpriteKeys = {"slime", "skeleton", "bird", "zombie", "treant"}

function Enemies.initialize()
    Enemies.list = {}
    Enemies.boss = nil
    Enemies.bossSpawned = false
    Enemies.spawnTimer = 0
end

function Enemies.spawnRegularEnemy(realmNumber)
    local mult = 1 + (realmNumber - 1) * 0.25
    local x = math.random((Config and Config.windowWidth) or 800)
    local y = math.random((Config and Config.windowHeight) or 600)

    local enemySpriteKey = availableEnemySpriteKeys[math.random(#availableEnemySpriteKeys)]
    local initialHp = 30 * mult
    table.insert(Enemies.list, {
        x = x, y = y,
        radius = 12,
        speed = 60,
        hp = initialHp,
        maxHp = initialHp, -- Add this line
        exp = 10 * mult,
        spriteKey = enemySpriteKey,
    })
end

function Enemies.spawnBoss()
    local initialBossHp = 1000
    Enemies.boss = {
        x = 400, y = 50, radius = 40, speed = 40,
        hp = initialBossHp,
        maxHp = initialBossHp, -- Add this line
        exp = 500,
        spriteKey = nil
    }
    Enemies.bossSpawned = true
end

function Enemies.update(dt, playerData, realmProviderFunc, killsProviderFunc)
    Enemies.spawnTimer = Enemies.spawnTimer - dt
    if Enemies.spawnTimer <= 0 and not Enemies.bossSpawned then
        local currentRealm = realmProviderFunc()
        Enemies.spawnRegularEnemy(currentRealm)
        Enemies.spawnTimer = 1
    end

    if killsProviderFunc() >= 100 and not Enemies.bossSpawned and not Enemies.boss then
        Enemies.spawnBoss()
    end

    for i = #Enemies.list, 1, -1 do
        local e = Enemies.list[i]
        if e then
            local angle = math.atan2(playerData.y - e.y, playerData.x - e.x)
            e.x = e.x + math.cos(angle) * e.speed * dt
            e.y = e.y + math.sin(angle) * e.speed * dt
        end
    end

    if Enemies.boss then
        local angle = math.atan2(playerData.y - Enemies.boss.y, playerData.x - Enemies.boss.x)
        Enemies.boss.x = Enemies.boss.x + math.cos(angle) * Enemies.boss.speed * dt
        Enemies.boss.y = Enemies.boss.y + math.sin(angle) * Enemies.boss.speed * dt
    end
end

function Enemies.draw()
    love.graphics.setColor(1, 1, 1)

    local currentEnemyScale = (Config and Config.enemyScale) or 1
    if not Config then
        print("Warning: Config not available in Enemies.draw(), using default scale 1.")
    end

    -- Health Bar properties
    local healthBarHeight = 5
    local healthBarYOffset = 7 -- Adjusted offset
    local healthBarBgColor = {0.3, 0.1, 0.1, 0.8} -- Darker Red
    local healthBarFgColor = {0.8, 0.2, 0.2, 0.9} -- Brighter Red
    local healthBarBorderColor = {0.1, 0.1, 0.1, 1} -- Black border
    local healthBarBorderSize = 0.5 -- pixels for border

    for _, enemy in ipairs(Enemies.list) do
        if Assets and Assets.enemies and Assets.enemies[enemy.spriteKey] then
            local enemyImage = Assets.enemies[enemy.spriteKey]
            local width = enemyImage:getWidth()
            local height = enemyImage:getHeight()
            love.graphics.draw(enemyImage, enemy.x, enemy.y, 0, currentEnemyScale, currentEnemyScale, width / 2, height / 2)
        else
            if Assets and Assets.enemies then
                print("Warning: Missing sprite for enemy type: " .. (enemy.spriteKey or "unknown") .. ". Drawing circle.")
            end
            love.graphics.setColor(1, 0, 0)
            love.graphics.circle("fill", enemy.x, enemy.y, enemy.radius or 12)
            love.graphics.setColor(1, 1, 1) -- Reset color after drawing fallback
        end

        -- After drawing sprite:
        if enemy.hp and enemy.maxHp and enemy.maxHp > 0 then
            local hpPercent = math.max(0, math.min(1, enemy.hp / enemy.maxHp))

            local spriteOriginalHeight = 0
            if Assets and Assets.enemies and Assets.enemies[enemy.spriteKey] then
                 spriteOriginalHeight = Assets.enemies[enemy.spriteKey]:getHeight()
            else
                 spriteOriginalHeight = (enemy.radius or 12) * 2 -- Fallback if no sprite
            end
            local scaledSpriteHalfHeight = (spriteOriginalHeight * currentEnemyScale) / 2

            local barWidth = (enemy.radius or 12) * 2.0 -- Bar width based on enemy radius
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
    end
    -- love.graphics.setColor(1, 1, 1) -- This reset is now inside the loop or after boss

    if Enemies.boss then
        local bossScaleToUse = (Config and Config.defaultSpriteScale) or 1
        if Enemies.boss.spriteKey and Assets and Assets.enemies and Assets.enemies[Enemies.boss.spriteKey] then
            local bossImage = Assets.enemies[Enemies.boss.spriteKey]
            local width = bossImage:getWidth()
            local height = bossImage:getHeight()
            love.graphics.draw(bossImage, Enemies.boss.x, Enemies.boss.y, 0, bossScaleToUse, bossScaleToUse, width/2, height/2)
        else
            love.graphics.setColor(0.5, 0, 0)
            love.graphics.circle("fill", Enemies.boss.x, Enemies.boss.y, Enemies.boss.radius or 40)
            love.graphics.setColor(1, 1, 1) -- Reset color after drawing fallback
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
                 bossSpriteOriginalHeight = (Enemies.boss.radius or 40) * 2 -- Fallback
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
        if addExpCallback then addExpCallback(enemy.exp or 0) end
        if incrementKillsCallback then incrementKillsCallback() end
        if dropLootCallback then dropLootCallback(enemy.x, enemy.y) end

        table.remove(Enemies.list, index)
        return true
    end
    return false
end

function Enemies.damageBoss(damageAmount, addExpCallback, incrementKillsCallback, dropLootCallback)
    if not Enemies.boss then return false end

    Enemies.boss.hp = Enemies.boss.hp - damageAmount
    if Enemies.boss.hp <= 0 then
        if addExpCallback then addExpCallback(Enemies.boss.exp or 0) end
        if incrementKillsCallback then incrementKillsCallback() end
        if dropLootCallback then dropLootCallback(Enemies.boss.x, Enemies.boss.y) end

        Enemies.boss = nil
        return true
    end
    return false
end

return Enemies
