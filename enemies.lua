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

    table.insert(Enemies.list, {
        x = x, y = y,
        radius = 12,
        speed = 60,
        hp = 30 * mult,
        exp = 10 * mult,
        spriteKey = enemySpriteKey,
    })
end

function Enemies.spawnBoss()
    Enemies.boss = {
        x = 400, y = 50, radius = 40, speed = 40,
        hp = 1000, exp = 500,
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
            love.graphics.setColor(1, 1, 1)
        end
    end

    if Enemies.boss then
        -- Assuming boss might use defaultSpriteScale or its own specific scale if defined
        local bossScale = (Config and Config.defaultSpriteScale) or 1
        if Enemies.boss.spriteKey and Assets and Assets.enemies and Assets.enemies[Enemies.boss.spriteKey] then
            local bossImage = Assets.enemies[Enemies.boss.spriteKey]
            local width = bossImage:getWidth()
            local height = bossImage:getHeight()
            love.graphics.draw(bossImage, Enemies.boss.x, Enemies.boss.y, 0, bossScale, bossScale, width/2, height/2)
        else
            love.graphics.setColor(0.5, 0, 0)
            love.graphics.circle("fill", Enemies.boss.x, Enemies.boss.y, Enemies.boss.radius)
        end
        love.graphics.setColor(1, 1, 1)
    end
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
