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
    facingDirection = "S"
}

Player.quads = {}

function Player.initializeAnimation(playerSheetAsset)
    Player.quads = {} -- Clear existing quads
    if not playerSheetAsset then
        print("Error in Player.initializeAnimation: playerSheetAsset is nil. Cannot create quads.")
        Player.quads["DEFAULT"] = nil
        return
    end

    local sheetWidth = playerSheetAsset:getWidth()
    local sheetHeight = playerSheetAsset:getHeight()

    if sheetWidth == 0 or sheetHeight == 0 then
        print("Error in Player.initializeAnimation: playerSheetAsset dimensions are zero. Spritesheet W/H:", sheetWidth, sheetHeight)
        Player.quads["DEFAULT"] = nil
        return
    end

    local frameWidth = sheetWidth / 3
    local frameHeight = sheetHeight / 3 -- Assuming 3 rows effectively, even if row 3 of sprites is ignored for definitions

    if frameWidth <= 0 or frameHeight <= 0 then
        print("Error in Player.initializeAnimation: Calculated frameWidth or frameHeight is zero or negative. frameW:", frameWidth, "frameH:", frameHeight)
        Player.quads["DEFAULT"] = nil
        return
    end

    -- Row 1: N, S, W
    Player.quads["N"] = love.graphics.newQuad(frameWidth * 0, 0, frameWidth, frameHeight, sheetWidth, sheetHeight)
    Player.quads["S"] = love.graphics.newQuad(frameWidth * 1, 0, frameWidth, frameHeight, sheetWidth, sheetHeight)
    Player.quads["W"] = love.graphics.newQuad(frameWidth * 2, 0, frameWidth, frameHeight, sheetWidth, sheetHeight)

    -- Row 2: E, SE, E (second E from issue description)
    Player.quads["E"] = love.graphics.newQuad(frameWidth * 0, frameHeight, frameWidth, frameHeight, sheetWidth, sheetHeight)
    Player.quads["SE"] = love.graphics.newQuad(frameWidth * 1, frameHeight, frameWidth, frameHeight, sheetWidth, sheetHeight)
    Player.quads["E_ALT"] = love.graphics.newQuad(frameWidth * 2, frameHeight, frameWidth, frameHeight, sheetWidth, sheetHeight) -- This is the 3rd frame of row 2

    -- Define fallbacks for diagonal directions not explicitly in the new layout
    Player.quads["NE"] = Player.quads["E"] -- Fallback for North-East
    Player.quads["SW"] = Player.quads["W"] -- Fallback for South-West
    Player.quads["NW"] = Player.quads["W"] -- Fallback for North-West

    Player.quads["DEFAULT"] = Player.quads["S"]
    print("Player animation quads initialized according to new layout. Frame W/H:", frameWidth, frameHeight)
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
        if dx ~= 0 and dy ~= 0 then
            moveSpeed = moveSpeed * 0.70710678118
        end
        Player.data.x = Player.data.x + dx * moveSpeed
        Player.data.y = Player.data.y + dy * moveSpeed

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
end

function Player.draw()
    if not (Assets and Assets.player_spritesheet and Config and Player.quads) then
        if not Config then print("Warning (Player.draw): Config not available for scaling.") end
        if not (Assets and Assets.player_spritesheet) then print("Warning (Player.draw): Player sprite not found in Assets.") end
        if not Player.quads then print("Warning (Player.draw): Player.quads not initialized.") end

        love.graphics.setColor(0, 1, 1)
        love.graphics.circle("fill", Player.data.x, Player.data.y, Player.data.radius or 15)
        love.graphics.setColor(1, 1, 1)
        return
    end

    local playerImage = Assets.player_spritesheet
    local currentDirection = Player.data.facingDirection
    local quadCandidate = Player.quads[currentDirection]

    if type(quadCandidate) ~= "userdata" then
        print("Warning (Player.draw): Quad for direction '" .. tostring(currentDirection) .. "' is not a valid Quad object. Type: " .. type(quadCandidate) .. ". Attempting DEFAULT.")
        quadCandidate = Player.quads["DEFAULT"]
    end

    if type(quadCandidate) ~= "userdata" then
        print("Error (Player.draw): DEFAULT quad is also not a valid Quad object. Type: " .. type(quadCandidate) .. ". Drawing fallback circle.")
        love.graphics.setColor(0, 1, 1)
        love.graphics.circle("fill", Player.data.x, Player.data.y, Player.data.radius or 15)
        love.graphics.setColor(1, 1, 1)
        return
    end

    local currentQuad = quadCandidate
    local frameWidth = 0
    local frameHeight = 0

    local vp_status, vp_w_or_err, vp_h = pcall(function()
        local x,y,w,h = currentQuad:getViewport()
        return w,h
    end)

    if not vp_status then
        print("Error (Player.draw): Failed to get viewport dimensions from currentQuad. Quad may be invalid. Error: " .. tostring(vp_w_or_err))
        love.graphics.setColor(0, 1, 1)
        love.graphics.circle("fill", Player.data.x, Player.data.y, Player.data.radius or 15)
        love.graphics.setColor(1, 1, 1)
        return
    end
    frameWidth = vp_w_or_err
    frameHeight = vp_h

    if frameWidth == 0 or frameHeight == 0 then
         print("Error (Player.draw): currentQuad has zero width or height. Quad Viewport: ", currentQuad:getViewport())
        love.graphics.setColor(0, 1, 1)
        love.graphics.circle("fill", Player.data.x, Player.data.y, Player.data.radius or 15)
        love.graphics.setColor(1, 1, 1)
        return
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(
        playerImage,
        currentQuad,
        Player.data.x,
        Player.data.y,
        0,
        (Config and Config.playerScale) or 0.5,
        (Config and Config.playerScale) or 0.5,
        frameWidth / 2,
        frameHeight / 2
    )
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
