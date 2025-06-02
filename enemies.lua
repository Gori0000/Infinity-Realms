local Enemies = {}

Enemies.list = {}
Enemies.boss = nil
Enemies.bossSpawned = false
Enemies.spawnTimer = 0

function Enemies.initialize()
    Enemies.list = {}
    Enemies.boss = nil
    Enemies.bossSpawned = false
    Enemies.spawnTimer = 0
end

-- Takes realmNumber directly
function Enemies.spawnRegularEnemy(realmNumber)
    local mult = 1 + (realmNumber - 1) * 0.25
    local x, y = math.random(800), math.random(600) -- Assuming window size from config eventually
    table.insert(Enemies.list, {
        x = x, y = y, radius = 12, speed = 60, 
        hp = 30 * mult, exp = 10 * mult, type = "regular"
    })
end

function Enemies.spawnBoss()
    Enemies.boss = {
        x = 400, y = 50, radius = 40, speed = 40, 
        hp = 1000, exp = 500, type = "boss" -- exp is already here
    }
    Enemies.bossSpawned = true
end

-- Updated signature to use provider functions
function Enemies.update(dt, playerData, realmProviderFunc, killsProviderFunc)
    Enemies.spawnTimer = Enemies.spawnTimer - dt
    if Enemies.spawnTimer <= 0 and not Enemies.bossSpawned then
        local currentRealm = realmProviderFunc() -- Get current realm via provider
        Enemies.spawnRegularEnemy(currentRealm)
        Enemies.spawnTimer = 1 
    end

    -- Use killsProviderFunc for boss spawn condition
    if killsProviderFunc() >= 100 and not Enemies.bossSpawned and not Enemies.boss then
        Enemies.spawnBoss()
    end

    -- Update positions of regular enemies
    for i = #Enemies.list, 1, -1 do
        local e = Enemies.list[i]
        if e then 
            local angle = math.atan2(playerData.y - e.y, playerData.x - e.x)
            e.x = e.x + math.cos(angle) * e.speed * dt
            e.y = e.y + math.sin(angle) * e.speed * dt
        end
    end

    -- Update boss position
    if Enemies.boss then
        local angle = math.atan2(playerData.y - Enemies.boss.y, playerData.x - Enemies.boss.x)
        Enemies.boss.x = Enemies.boss.x + math.cos(angle) * Enemies.boss.speed * dt
        Enemies.boss.y = Enemies.boss.y + math.sin(angle) * Enemies.boss.speed * dt
    end
end

function Enemies.draw()
    love.graphics.setColor(1, 0, 0) 
    for _, e in ipairs(Enemies.list) do
        love.graphics.circle("fill", e.x, e.y, e.radius)
    end

    if Enemies.boss then
        love.graphics.setColor(0.5, 0, 0) 
        love.graphics.circle("fill", Enemies.boss.x, Enemies.boss.y, Enemies.boss.radius)
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

-- Updated signature to use callbacks
function Enemies.damageEnemy(enemy, damageAmount, index, addExpCallback, incrementKillsCallback, dropLootCallback)
    if not enemy then return false end
    enemy.hp = enemy.hp - damageAmount
    if enemy.hp <= 0 then
        if addExpCallback then addExpCallback(enemy.exp or 0) end
        if incrementKillsCallback then incrementKillsCallback() end
        if dropLootCallback then dropLootCallback(enemy.x, enemy.y) end
        
        table.remove(Enemies.list, index)
        return true -- Died
    end
    return false -- Survived
end

-- Updated signature to use callbacks
function Enemies.damageBoss(damageAmount, addExpCallback, incrementKillsCallback, dropLootCallback)
    if not Enemies.boss then return false end

    Enemies.boss.hp = Enemies.boss.hp - damageAmount
    if Enemies.boss.hp <= 0 then
        if addExpCallback then addExpCallback(Enemies.boss.exp or 0) end
        if incrementKillsCallback then incrementKillsCallback() end
        if dropLootCallback then dropLootCallback(Enemies.boss.x, Enemies.boss.y) end
        
        Enemies.boss = nil
        -- Enemies.bossSpawned = false -- Consider if another boss can spawn or if this flag should persist
        return true -- Died
    end
    return false -- Survived
end

return Enemies
