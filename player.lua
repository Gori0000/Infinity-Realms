local Player = {}

Player.data = {
    x = 400, y = 300,
    baseSpeed = 200,
    speed = 200,
    radius = 15,
    baseMaxHp = 100,
    maxHp = 100,
    hp = 100,
    exp = 0, level = 1, kills = 0,
    gold = 0, essence = {tier1 = 0, tier2 = 0},
    calculatedBonuses = {},
    facingDirection = "S" -- Default facing direction
}

Player.quads = {} -- To store animation frames

function Player.initializeAnimation(playerSheetAsset)
    Player.quads = {} -- Clear previous quads
    if not playerSheetAsset then
        print("Warning: Player spritesheet asset is missing for Player.initializeAnimation.")
        return
    end

    local sheetWidth = playerSheetAsset:getWidth()
    local sheetHeight = playerSheetAsset:getHeight()

    -- Assuming a 3x3 grid for 8 directions + idle (center often idle/down)
    -- If wizard_spritesheet.png is 256x256, then frameWidth/Height is ~85.33
    local frameWidth = sheetWidth / 3
    local frameHeight = sheetHeight / 3

    -- (x, y, width, height, sourceWidth, sourceHeight)
    -- Row 1 (Upward movements)
    Player.quads["NW"] = love.graphics.newQuad(0, 0, frameWidth, frameHeight, sheetWidth, sheetHeight)
    Player.quads["N"]  = love.graphics.newQuad(frameWidth, 0, frameWidth, frameHeight, sheetWidth, sheetHeight)
    Player.quads["NE"] = love.graphics.newQuad(frameWidth * 2, 0, frameWidth, frameHeight, sheetWidth, sheetHeight)

    -- Row 2 (Sideways movements and often Idle/South)
    Player.quads["W"]  = love.graphics.newQuad(0, frameHeight, frameWidth, frameHeight, sheetWidth, sheetHeight)
    Player.quads["S"]  = love.graphics.newQuad(frameWidth, frameHeight, frameWidth, frameHeight, sheetWidth, sheetHeight) -- Default/Idle to South
    Player.quads["E"]  = love.graphics.newQuad(frameWidth * 2, frameHeight, frameWidth, frameHeight, sheetWidth, sheetHeight)

    -- Row 3 (Downward movements)
    Player.quads["SW"] = love.graphics.newQuad(0, frameHeight * 2, frameWidth, frameHeight, sheetWidth, sheetHeight)
    -- Assuming the center-bottom quad is also a valid "S" or an alternative S. If it's part of an animation, that's for later.
    -- Player.quads["S_ALT"] = love.graphics.newQuad(frameWidth, frameHeight * 2, frameWidth, frameHeight, sheetWidth, sheetHeight)
    Player.quads["SE"] = love.graphics.newQuad(frameWidth * 2, frameHeight * 2, frameWidth, frameHeight, sheetWidth, sheetHeight)

    Player.quads["DEFAULT"] = Player.quads["S"] -- Fallback quad
    print("Player animation quads initialized. Frame W/H:", frameWidth, frameHeight)
end

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
    local dx, dy = 0, 0
    if love.keyboard.isDown("w") then dy = dy - 1 end
    if love.keyboard.isDown("s") then dy = dy + 1 end
    if love.keyboard.isDown("a") then dx = dx - 1 end
    if love.keyboard.isDown("d") then dx = dx + 1 end

    if dx ~= 0 or dy ~= 0 then
        local moveSpeed = Player.data.speed * dt
        -- Normalize diagonal movement (optional, but good practice)
        if dx ~= 0 and dy ~= 0 then
            moveSpeed = moveSpeed * 0.70710678118 -- approx 1/sqrt(2)
        end
        Player.data.x = Player.data.x + dx * moveSpeed
        Player.data.y = Player.data.y + dy * moveSpeed

        -- Update facing direction based on movement vector
        if dx == 0 and dy == -1 then Player.data.facingDirection = "N"
        elseif dx == 1 and dy == -1 then Player.data.facingDirection = "NE"
        elseif dx == 1 and dy == 0 then Player.data.facingDirection = "E"
        elseif dx == 1 and dy == 1 then Player.data.facingDirection = "SE"
        elseif dx == 0 and dy == 1 then Player.data.facingDirection = "S"
        elseif dx == -1 and dy == 1 then Player.data.facingDirection = "SW"
        elseif dx == -1 and dy == 0 then Player.data.facingDirection = "W"
        elseif dx == -1 and dy == -1 then Player.data.facingDirection = "NW"
        end
    end
    -- If no movement (dx==0 and dy==0), facingDirection remains as it was.
end

function Player.draw()
    if Assets and Assets.player_spritesheet and Config and Player.quads then
        local playerImage = Assets.player_spritesheet
        local currentQuad = Player.quads[Player.data.facingDirection] or Player.quads["DEFAULT"]

        if not currentQuad then
             print("Warning: Player quad not found for direction: " .. Player.data.facingDirection .. ". Using default.")
             currentQuad = Player.quads["DEFAULT"]
        end

        if currentQuad then
            local frameWidth = currentQuad:getViewport():getWidth()
            local frameHeight = currentQuad:getViewport():getHeight()

            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(
                playerImage,
                currentQuad,
                Player.data.x,
                Player.data.y,
                0, -- rotation
                Config.playerScale,
                Config.playerScale,
                frameWidth / 2,    -- origin from frame dimensions
                frameHeight / 2     -- origin from frame dimensions
            )
        else
            -- This specific 'else' might be redundant if Player.quads["DEFAULT"] is always valid after init
            print("Error: Default player quad is missing.")
            love.graphics.setColor(0, 1, 1)
            love.graphics.circle("fill", Player.data.x, Player.data.y, Player.data.radius)
        end
    else
        if not Config then print("Warning: Config not available in Player.draw for scaling.") end
        if not (Assets and Assets.player_spritesheet) then print("Warning: Player sprite not found in Assets.") end
        if not Player.quads then print("Warning: Player.quads not initialized.") end

        love.graphics.setColor(0, 1, 1)
        love.graphics.circle("fill", Player.data.x, Player.data.y, Player.data.radius)
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
