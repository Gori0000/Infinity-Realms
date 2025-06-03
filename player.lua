local Player = {}

Player.data = {
    x = 400, y = 300,
    baseSpeed = 200,      -- Base speed
    speed = 200,          -- Actual speed, will be calculated
    radius = 15,          -- This might still be used for collision detection
    baseMaxHp = 100,      -- Base Max HP
    maxHp = 100,          -- Actual Max HP, will be calculated
    hp = 100,
    exp = 0, level = 1, kills = 0,
    gold = 0, essence = {tier1 = 0, tier2 = 0},
    calculatedBonuses = {} -- This will be populated by Upgrades.recalculatePlayerBonuses
}

function Player.applyCalculatedBonuses()
    local bonuses = Player.data.calculatedBonuses
    if not bonuses then return end

    local oldMaxHp = Player.data.maxHp
    Player.data.maxHp = Player.data.baseMaxHp + (bonuses.HP_MAX or 0)
    local diffMaxHp = Player.data.maxHp - oldMaxHp
    if diffMaxHp > 0 then
        Player.data.hp = Player.data.hp + diffMaxHp
    end
    Player.data.hp = math.min(Player.data.hp, Player.data.maxHp)
    if Player.data.hp <=0 and Player.data.maxHp > 0 then
        Player.data.hp = 1
    end

    Player.data.speed = Player.data.baseSpeed * (1 + (bonuses.MOVE_SPEED or 0) / 100)
end

function Player.update(dt)
    if love.keyboard.isDown("w") then Player.data.y = Player.data.y - Player.data.speed * dt end
    if love.keyboard.isDown("s") then Player.data.y = Player.data.y + Player.data.speed * dt end
    if love.keyboard.isDown("a") then Player.data.x = Player.data.x - Player.data.speed * dt end
    if love.keyboard.isDown("d") then Player.data.x = Player.data.x + Player.data.speed * dt end
end

function Player.draw()
    if Assets and Assets.player_spritesheet and Config then -- Ensure Config is available
        local playerImage = Assets.player_spritesheet
        local width = playerImage:getWidth()
        local height = playerImage:getHeight()

        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(
            playerImage,
            Player.data.x,
            Player.data.y,
            0, -- rotation
            Config.spriteScale, -- Use global scale
            Config.spriteScale, -- Use global scale
            width / 2, -- origin offset x based on original image width
            height / 2  -- origin offset y based on original image height
        )
    else
        if not Config then print("Warning: Config not available in Player.draw") end
        love.graphics.setColor(0, 1, 1)
        love.graphics.circle("fill", Player.data.x, Player.data.y, Player.data.radius)
        if not (Assets and Assets.player_spritesheet) then
            print("Warning: Player sprite not found in Assets. Drawing fallback circle.")
        end
    end
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
