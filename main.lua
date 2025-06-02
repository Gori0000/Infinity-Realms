function love.load()
    love.window.setTitle("Infinity Realms - FINAL VERSION")
    love.window.setMode(800, 600)
    font = love.graphics.newFont(14)
    love.graphics.setFont(font)

    player = {
        x = 400, y = 300, speed = 200, radius = 15,
        hp = 100, maxHp = 100, exp = 0, level = 1, kills = 0,
        gold = 0, essence = {tier1 = 0, tier2 = 0},
        bonusDamage = 0, bonusCooldown = 0
    }

    bullets, enemies, loot = {}, {}, {}
    upgradeNodes = {}
    spawnTimer, shootCooldown = 0, 0
    boss, bossSpawned = nil, false
    showInventory, showUpgradeTree, showRealmList = false, true, false
    treeOffsetX, treeOffsetY = 0, 0
    currentRealm = 1

    initializeTree()
    initializeRealms()
end

function initializeTree()
    local root = {id = 1, x = 400, y = 300, level = 0, maxLevel = 10, effect = "+10% DMG", children = {}}
    categorizeNode(root)
    table.insert(upgradeNodes, root)
end

function categorizeNode(node)
    if node.id % 3 == 1 then node.category = "Offense"
    elseif node.id % 3 == 2 then node.category = "Defense"
    else node.category = "Support" end
end

function expandTree(node)
    if #node.children == 0 then
        local angleStep = math.pi / 4
        for i = 1, 2 do
            local angle = angleStep * i
            local newNode = {
                id = #upgradeNodes + 1,
                x = node.x + math.cos(angle) * 100,
                y = node.y + math.sin(angle) * 100,
                level = 0, maxLevel = 10,
                effect = "New Effect " .. (#upgradeNodes + 1),
                children = {}
            }
            categorizeNode(newNode)
            table.insert(node.children, newNode)
            table.insert(upgradeNodes, newNode)
        end
    end
end

function initializeRealms()
    realms = {}
    for i = 1, 10 do table.insert(realms, "Realm " .. i) end
end

function love.update(dt)
    if love.keyboard.isDown("w") then player.y = player.y - player.speed * dt end
    if love.keyboard.isDown("s") then player.y = player.y + player.speed * dt end
    if love.keyboard.isDown("a") then player.x = player.x - player.speed * dt end
    if love.keyboard.isDown("d") then player.x = player.x + player.speed * dt end

    shootCooldown = shootCooldown - dt
    local actualCooldown = 0.25 - (player.bonusCooldown or 0)
    if love.mouse.isDown(1) and shootCooldown <= 0 then
        local mx, my = love.mouse.getPosition()
        local angle = math.atan2(my - player.y, mx - player.x)
        table.insert(bullets, {
            x = player.x, y = player.y,
            dx = math.cos(angle) * 400,
            dy = math.sin(angle) * 400, radius = 5
        })
        shootCooldown = actualCooldown
    end

    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.x, b.y = b.x + b.dx * dt, b.y + b.dy * dt
        if b.x < 0 or b.x > 800 or b.y < 0 or b.y > 600 then table.remove(bullets, i) end
    end

    spawnTimer = spawnTimer - dt
    if spawnTimer <= 0 and not bossSpawned then spawnEnemy() spawnTimer = 1 end

    for i, e in ipairs(enemies) do
        local angle = math.atan2(player.y - e.y, player.x - e.x)
        e.x = e.x + math.cos(angle) * e.speed * dt
        e.y = e.y + math.sin(angle) * e.speed * dt
    end

    for i = #bullets, 1, -1 do
        local b = bullets[i]
        for j = #enemies, 1, -1 do
            local e = enemies[j]
            if distance(b.x, b.y, e.x, e.y) < b.radius + e.radius then
                table.remove(bullets, i)
                e.hp = e.hp - (25 + player.bonusDamage * 25)
                if e.hp <= 0 then
                    player.exp = player.exp + e.exp
                    player.kills = player.kills + 1
                    dropLoot(e.x, e.y)
                    table.remove(enemies, j)
                    if player.kills >= 100 and not bossSpawned then spawnBoss() bossSpawned = true end
                end
                break
            end
        end
    end

    if player.exp >= player.level * 100 then
        player.exp = player.exp - player.level * 100
        player.level = player.level + 1
        player.maxHp = player.maxHp + 10
        player.hp = player.maxHp
    end
end

function love.draw()
    love.graphics.setColor(0, 1, 1)
    love.graphics.circle("fill", player.x, player.y, player.radius)

    for _, e in ipairs(enemies) do love.graphics.setColor(1, 0, 0) love.graphics.circle("fill", e.x, e.y, e.radius) end
    for _, b in ipairs(bullets) do love.graphics.setColor(1, 1, 0) love.graphics.circle("fill", b.x, b.y, b.radius) end
    for _, l in ipairs(loot) do
        if l.type == "gold" then love.graphics.setColor(1, 1, 0)
        elseif l.type == "essence1" then love.graphics.setColor(0, 1, 0)
        elseif l.type == "essence2" then love.graphics.setColor(0, 0.5, 1) end
        love.graphics.circle("fill", l.x, l.y, 5)
    end

    drawHUD()
    if showInventory then drawInventory() end
    if showRealmList then drawRealmList() end
    if showUpgradeTree then drawUpgradeTree() end
end

function drawHUD()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP: " .. player.hp .. "/" .. player.maxHp, 10, 10)
    love.graphics.print("Level: " .. player.level .. " EXP: " .. player.exp, 10, 30)
    love.graphics.print("Kills: " .. player.kills, 10, 50)
    love.graphics.print("Gold: " .. player.gold, 10, 70)
    love.graphics.print("Essence T1: " .. player.essence.tier1 .. " T2: " .. player.essence.tier2, 10, 90)
    love.graphics.print("Realm: " .. currentRealm, 10, 110)
end

function drawInventory()
    love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
    love.graphics.rectangle("fill", 200, 150, 400, 300)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Inventory", 350, 160)
end

function drawRealmList()
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 600, 50, 180, 300)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Realms Unlocked:", 610, 60)
    for i, realm in ipairs(realms) do love.graphics.print(realm, 610, 60 + i * 20) end
end

function drawUpgradeTree()
    for _, node in ipairs(upgradeNodes) do
        love.graphics.setColor(0.7, 0.7, 1)
        love.graphics.circle("fill", node.x + treeOffsetX, node.y + treeOffsetY, 15)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(node.level .. "/" .. node.maxLevel, node.x - 10 + treeOffsetX, node.y - 5 + treeOffsetY)
        love.graphics.print(node.effect .. " [" .. (node.category or "N/A") .. "]", node.x - 30 + treeOffsetX, node.y + 20 + treeOffsetY)
        for _, child in ipairs(node.children) do
            love.graphics.line(node.x + treeOffsetX, node.y + treeOffsetY, child.x + treeOffsetX, child.y + treeOffsetY)
        end
    end
end

function love.keypressed(key)
    if key == "m" then showUpgradeTree = not showUpgradeTree end
    if key == "tab" then showInventory = not showInventory end
    if key == "r" then showRealmList = not showRealmList end
    if key == "t" then currentRealm = math.max(1, currentRealm - 1) resetEnemies() end
    if key == "y" then currentRealm = currentRealm + 1 resetEnemies() end
    if key == "left" then treeOffsetX = treeOffsetX + 20 end
    if key == "right" then treeOffsetX = treeOffsetX - 20 end
    if key == "up" then treeOffsetY = treeOffsetY + 20 end
    if key == "down" then treeOffsetY = treeOffsetY - 20 end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        for id, node in ipairs(upgradeNodes) do
            if distance(x, y, node.x + treeOffsetX, node.y + treeOffsetY) <= 15 then
                upgradeNode(id)
            end
        end
    end
end

function upgradeNode(id)
    local node = upgradeNodes[id]
    if node and node.level < node.maxLevel then
        node.level = node.level + 1
        if node.level == node.maxLevel then expandTree(node) end
    end
end

function resetEnemies()
    enemies, bullets = {}, {}
    boss, bossSpawned = nil, false
    spawnTimer = 0
    player.kills = 0
end

function spawnEnemy()
    local mult = 1 + (currentRealm - 1) * 0.25
    local x, y = math.random(800), math.random(600)
    table.insert(enemies, {x = x, y = y, radius = 12, speed = 60, hp = 30 * mult, exp = 10 * mult})
end

function spawnBoss()
    boss = {x = 400, y = 50, radius = 40, speed = 40, hp = 1000}
end

function dropLoot(x, y)
    if math.random() < 0.5 then player.gold = player.gold + 1 end
    if math.random() < 0.05 then player.essence.tier1 = player.essence.tier1 + 1 end
    if math.random() < 0.02 then player.essence.tier2 = player.essence.tier2 + 1 end
end

function distance(x1, y1, x2, y2)
    return ((x2 - x1)^2 + (y2 - y1)^2)^0.5
end