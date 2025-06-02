local Player = {}

Player.data = {
    x = 400, y = 300, speed = 200, radius = 15,
    hp = 100, maxHp = 100, exp = 0, level = 1, kills = 0,
    gold = 0, essence = {tier1 = 0, tier2 = 0},
    bonusDamage = 0, bonusCooldown = 0
}

function Player.update(dt)
    -- Player movement logic
    if love.keyboard.isDown("w") then Player.data.y = Player.data.y - Player.data.speed * dt end
    if love.keyboard.isDown("s") then Player.data.y = Player.data.y + Player.data.speed * dt end
    if love.keyboard.isDown("a") then Player.data.x = Player.data.x - Player.data.speed * dt end
    if love.keyboard.isDown("d") then Player.data.x = Player.data.x + Player.data.speed * dt end
end

function Player.draw()
    -- Player drawing logic
    love.graphics.setColor(0, 1, 1) -- Player color
    love.graphics.circle("fill", Player.data.x, Player.data.y, Player.data.radius)
end

function Player.craftTier2Essence()
    if Player.data.essence.tier1 >= 5 then
        Player.data.essence.tier1 = Player.data.essence.tier1 - 5
        Player.data.essence.tier2 = Player.data.essence.tier2 + 1
        print("Successfully crafted 1x Tier 2 Essence. Current T1: " .. Player.data.essence.tier1 .. ", T2: " .. Player.data.essence.tier2)
        return true
    else
        print("Not enough Tier 1 Essences to craft. Need 5. Current T1: " .. Player.data.essence.tier1)
        return false
    end
end

return Player
