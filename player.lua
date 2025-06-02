local Player = {}

Player.data = {
    x = 400, y = 300, 
    baseSpeed = 200,      -- Base speed
    speed = 200,          -- Actual speed, will be calculated
    radius = 15,
    baseMaxHp = 100,      -- Base Max HP
    maxHp = 100,          -- Actual Max HP, will be calculated
    hp = 100, 
    exp = 0, level = 1, kills = 0,
    gold = 0, essence = {tier1 = 0, tier2 = 0},
    calculatedBonuses = {} -- This will be populated by Upgrades.recalculatePlayerBonuses
    -- Removed old bonusDamage, bonusCooldown as they are now derived
}

function Player.applyCalculatedBonuses()
    local bonuses = Player.data.calculatedBonuses
    if not bonuses then return end -- Should not happen if called after recalculate

    -- Store old maxHp to calculate difference for current hp adjustment
    local oldMaxHp = Player.data.maxHp

    -- Max HP
    Player.data.maxHp = Player.data.baseMaxHp + (bonuses.HP_MAX or 0)

    -- Adjust current HP based on maxHP change
    local diffMaxHp = Player.data.maxHp - oldMaxHp
    if diffMaxHp > 0 then
        Player.data.hp = Player.data.hp + diffMaxHp -- Increase current HP by the amount max HP increased
    end
    Player.data.hp = math.min(Player.data.hp, Player.data.maxHp) -- Ensure current HP doesn't exceed new max HP
    if Player.data.hp <=0 and Player.data.maxHp > 0 then -- Edge case: if player was dead and maxHP increased
        Player.data.hp = 1 -- Give 1 hp to prevent staying dead with positive maxHP
    end


    -- Speed
    Player.data.speed = Player.data.baseSpeed * (1 + (bonuses.MOVE_SPEED or 0) / 100)

    -- Other stats like damage and cooldown are used directly from calculatedBonuses in game.lua
    -- So no need to set specific Player.data.bonusDamage or Player.data.bonusCooldown here.
    -- print(string.format("Applied Bonuses: New MaxHP=%.2f, New Speed=%.2f", Player.data.maxHp, Player.data.speed))
end

function Player.update(dt)
    -- Player movement logic uses Player.data.speed which is now updated by applyCalculatedBonuses
    if love.keyboard.isDown("w") then Player.data.y = Player.data.y - Player.data.speed * dt end
    if love.keyboard.isDown("s") then Player.data.y = Player.data.y + Player.data.speed * dt end
    if love.keyboard.isDown("a") then Player.data.x = Player.data.x - Player.data.speed * dt end
    if love.keyboard.isDown("d") then Player.data.x = Player.data.x + Player.data.speed * dt end
end

function Player.draw()
    love.graphics.setColor(0, 1, 1) 
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
