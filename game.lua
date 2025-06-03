local Game = {}

Game.bullets = {}
Game.shootCooldown = 0
Game.currentRealm = 1
Game.realms = {}
Game.loot = {}

-- Base game mechanics values
local BASE_PROJECTILE_DAMAGE = 25
local BASE_SHOOT_COOLDOWN = 0.25
local MIN_SHOOT_COOLDOWN = 0.05 -- Minimum possible cooldown

function Game.initializeRealms()
    Game.realms = {}
    for i = 1, 10 do
        table.insert(Game.realms, "Realm " .. i)
    end
end

function Game.getPlayerRealm()
    return Game.currentRealm
end

function Game.getLootTable()
    return Game.loot
end

function Game.getBulletsTable()
    return Game.bullets
end

function Game.getRealmsTable()
    return Game.realms
end

function Game.dropLoot(x, y, playerData)
    if math.random() < 0.5 then
        playerData.gold = playerData.gold + 1
        table.insert(Game.loot, {x=x,y=y, type="coin", radius=8})
    end
    if math.random() < 0.05 then
        playerData.essence.tier1 = playerData.essence.tier1 + 1
        table.insert(Game.loot, {x=x,y=y, type="essence_t1", radius=8})
    end
    if math.random() < 0.02 then
        playerData.essence.tier2 = playerData.essence.tier2 + 1
        table.insert(Game.loot, {x=x,y=y, type="essence_t2", radius=8})
    end
end

local function calculateBulletDamage(bullet, playerData)
    local damageBonusPercent = (playerData.calculatedBonuses and playerData.calculatedBonuses.DMG) or 0
    return BASE_PROJECTILE_DAMAGE * (1 + damageBonusPercent / 100)
end

function Game.update(dt, Player, Enemies, config, utils)
    Game.shootCooldown = Game.shootCooldown - dt

    local cooldownReductionPercent = (Player.data.calculatedBonuses and Player.data.calculatedBonuses.CDR) or 0
    local actualCooldown = BASE_SHOOT_COOLDOWN * (1 - cooldownReductionPercent / 100)
    actualCooldown = math.max(actualCooldown, MIN_SHOOT_COOLDOWN)

    if love.mouse.isDown(1) and Game.shootCooldown <= 0 then
        local mx, my = love.mouse.getPosition()
        local angle = math.atan2(my - Player.data.y, mx - Player.data.x)
        table.insert(Game.bullets, {
            x = Player.data.x, y = Player.data.y,
            dx = math.cos(angle) * 400,
            dy = math.sin(angle) * 400,
            radius = 5,
            type = "normal"
        })
        Game.shootCooldown = actualCooldown
    end

    for i = #Game.bullets, 1, -1 do
        local b = Game.bullets[i]
        if b then
            b.x, b.y = b.x + b.dx * dt, b.y + b.dy * dt
            if b.x < 0 or b.x > config.windowWidth or b.y < 0 or b.y > config.windowHeight then
                table.remove(Game.bullets, i)
            end
        end
    end

    for i = #Game.bullets, 1, -1 do
        local b = Game.bullets[i]
        if not b then goto next_bullet_enemy_collision end

        local currentEnemies = Enemies.getList()
        for j = #currentEnemies, 1, -1 do
            local e = currentEnemies[j]
            if e and utils.distance(b.x, b.y, e.x, e.y) < b.radius + e.radius then
                local damage = calculateBulletDamage(b, Player.data)
                local enemyDied = Enemies.damageEnemy(e, damage, j,
                    function(exp) Player.data.exp = Player.data.exp + exp end,
                    function() Player.data.kills = Player.data.kills + 1 end,
                    function(lx, ly) Game.dropLoot(lx, ly, Player.data) end)

                table.remove(Game.bullets, i)
                goto next_bullet_enemy_collision
            end
        end
        ::next_bullet_enemy_collision::
    end

    local currentBoss = Enemies.getBoss()
    if currentBoss then
        for i = #Game.bullets, 1, -1 do
            local b = Game.bullets[i]
            if not b then goto next_bullet_boss_collision end

            if utils.distance(b.x, b.y, currentBoss.x, currentBoss.y) < b.radius + currentBoss.radius then
                local damage = calculateBulletDamage(b, Player.data)
                local bossDied = Enemies.damageBoss(damage,
                    function(exp) Player.data.exp = Player.data.exp + exp end,
                    function() Player.data.kills = Player.data.kills + 1 end,
                    function(lx, ly) Game.dropLoot(lx, ly, Player.data) end)

                table.remove(Game.bullets, i)
            end
            ::next_bullet_boss_collision::
        end
    end

    if Player.data.exp >= Player.data.level * 100 then
        Player.data.exp = Player.data.exp - Player.data.level * 100
        Player.data.level = Player.data.level + 1
        Player.data.maxHp = Player.data.maxHp + 10
        Player.data.hp = Player.data.maxHp
    end
end

function Game.draw()
    if Assets and Assets.projectile_blue then
        local projectileImage = Assets.projectile_blue
        local pWidth = projectileImage:getWidth()
        local pHeight = projectileImage:getHeight()
        love.graphics.setColor(1, 1, 1)
        for _, b in ipairs(Game.bullets) do
            love.graphics.draw(projectileImage, b.x, b.y, 0, 1, 1, pWidth / 2, pHeight / 2)
        end
    else
        if Assets then -- Check if Assets table itself exists, even if projectile_blue doesn't
            print("Warning: Assets.projectile_blue is missing. Drawing circles for bullets.")
        end
        love.graphics.setColor(1, 1, 0)
        for _, b in ipairs(Game.bullets) do
            love.graphics.circle("fill", b.x, b.y, b.radius or 5)
        end
    end
    love.graphics.setColor(1, 1, 1)

    for _, l in ipairs(Game.loot) do
        local lootImage = Assets.loot and Assets.loot[l.type] -- Check Assets.loot exists

        if lootImage then
            love.graphics.setColor(1, 1, 1)
            local lWidth = lootImage:getWidth()
            local lHeight = lootImage:getHeight()
            love.graphics.draw(lootImage, l.x, l.y, 0, 1, 1, lWidth / 2, lHeight / 2)
        else
            if Assets and Assets.loot then -- Only print warning if Assets.loot table itself was expected
                 print("Info: No sprite for loot type: " .. (l.type or "unknown") .. ". Drawing fallback circle.")
            end
            if l.type == "coin" then
                love.graphics.setColor(1, 0.84, 0) -- Gold/Yellow for coin fallback
            elseif l.type == "essence_t1" then
                love.graphics.setColor(0, 1, 0) -- Green for Tier 1 essence fallback
            elseif l.type == "essence_t2" then
                love.graphics.setColor(0.2, 0.5, 1) -- Blue for Tier 2 essence (current design)
            else
                love.graphics.setColor(1, 0, 1) -- Magenta for other unknown loot types
            end
            love.graphics.circle("fill", l.x, l.y, l.radius or 5)
        end
    end
    love.graphics.setColor(1, 1, 1)
end

function Game.resetForNewRealm(Player, Enemies)
    Enemies.reset()
    Game.bullets = {}
    if Player and Player.data then
        Player.data.kills = 0
    end
    Game.loot = {}
end

function Game.changeRealm(delta, Player, Enemies)
    Game.currentRealm = math.max(1, Game.currentRealm + delta)
    Game.resetForNewRealm(Player, Enemies)
end

return Game
