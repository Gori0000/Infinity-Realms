local Player = {}
local utils = require("utils") -- Added for deepCopy

Player.data = {
    x = 400, y = 300,
    baseSpeed = 200,
    speed = 200,
    baseRadius = 15, -- Changed from radius
    radius = 15,     -- Will be updated dynamically
    baseMaxHp = 100,
    maxHp = 100,
    hp = 100,
    exp = 0, level = 1, kills = 0,
    gold = 0, essence = {tier1 = 0, tier2 = 0},
    calculatedBonuses = {},
    facingDirection = "S",
    skillPoints = 10000,
    spells = {},
    spellUpgradePoints = 0,
    gear = {
        wand = nil,
        robe = nil,
        hat = nil,
        boots = nil,
        charm = nil
    },
    inventory = {
        items = (function()
            local t = {}
            for i = 1, 16 do t[i] = nil end
            return t
        end)(), -- Creates a table with 16 nil values
        width = 4,
        height = 4,
        maxSlots = 16
    }
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

function Player.recalculateBonuses()
    -- Preserve existing player upgrade tree bonuses (from skill tree, etc.)
    local baseBonuses = {}
    if Player.data.calculatedBonuses then
        for k, v in pairs(Player.data.calculatedBonuses) do
            baseBonuses[k] = v
        end
    end

    -- Initialize Player.data.calculatedBonuses for gear and other runtime effects
    Player.data.calculatedBonuses = {}
    for k,v in pairs(baseBonuses) do
        Player.data.calculatedBonuses[k] = v
    end

    -- Iterate Through Gear
    if Player.data.gear then
        for slot, item in pairs(Player.data.gear) do
            if item and item.effects then
                for effectName, value in pairs(item.effects) do
                    Player.data.calculatedBonuses[effectName] = (Player.data.calculatedBonuses[effectName] or 0) + value
                end
            end
        end
    end

    -- After summing all bonuses, apply them
    Player.applyCalculatedBonuses()
end

function Player.applyCalculatedBonuses()
    local bonuses = Player.data.calculatedBonuses
    if not bonuses then return end

    -- Apply HP_MAX
    local oldMaxHp = Player.data.maxHp
    Player.data.maxHp = Player.data.baseMaxHp + (bonuses.HP_MAX or 0) -- Ensuring consistency with HP_MAX
    local diffMaxHp = Player.data.maxHp - oldMaxHp
    if diffMaxHp > 0 then
        Player.data.hp = Player.data.hp + diffMaxHp
    end
    Player.data.hp = math.min(Player.data.hp, Player.data.maxHp)
    if Player.data.hp <=0 and Player.data.maxHp > 0 then -- Ensure HP is at least 1 if maxHp > 0
        Player.data.hp = 1
    end

    -- Apply MOVE_SPEED
    Player.data.speed = Player.data.baseSpeed * (1 + ((bonuses.MOVE_SPEED or 0) / 100))

    -- Other bonuses like SPELL_DAMAGE, CRIT_CHANCE, COOLDOWN_REDUCTION, LOOT_MULTIPLIER
    -- are stored in Player.data.calculatedBonuses by recalculateBonuses().
    -- They will be used by other systems directly from Player.data.calculatedBonuses.
    -- For example, COOLDOWN_REDUCTION is already used in Game.lua for the basic attack.
    -- SPELL_DAMAGE and CRIT_CHANCE will be used in damage calculation logic.
    -- LOOT_MULTIPLIER will be used in Game.dropLoot.

    -- Example of how COOLDOWN_REDUCTION might be applied to spells if not already handled globally:
    -- (This part is illustrative, actual application might be in spell casting or update logic)
    -- if Player.data.spells then
    --     for _, spell in ipairs(Player.data.spells) do
    --         local reduction = (bonuses.COOLDOWN_REDUCTION or 0)
    --         spell.calculatedCooldown = spell.baseCooldown * (1 - reduction)
    --     end
    -- end
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

    -- Update dynamic radius based on DebugSettings
    Player.data.radius = (Player.data.baseRadius or 15) * (DebugSettings and DebugSettings.hitboxScale or 1.0)

    -- Update spell cooldowns
    if Player.data.spells then
        for i, spell in ipairs(Player.data.spells) do
            if spell and spell.currentCooldown > 0 then
                spell.currentCooldown = math.max(0, spell.currentCooldown - dt)
            end
        end
    end
end

function Player.castSpell(slotIndex, targetX, targetY)
    if not Player.data.spells or not Player.data.spells[slotIndex] then
        -- print("Player.castSpell: No spell in slot " .. slotIndex)
        return false
    end

    local spell = Player.data.spells[slotIndex]

    if spell.currentCooldown > 0 then
        -- print("Player.castSpell: Spell " .. spell.name .. " on cooldown: " .. string.format("%.2f", spell.currentCooldown))
        return false
    end

    -- print("Player.castSpell: Casting " .. spell.name)
    -- Apply player-wide Cooldown Reduction (CDR) from gear/buffs
    local finalCooldown = spell.calculatedCooldown
    if Player.data.calculatedBonuses and Player.data.calculatedBonuses.CDR then
        local playerGlobalCDR_Percent = Player.data.calculatedBonuses.CDR -- This is a percentage, e.g., 5 for 5%
        finalCooldown = finalCooldown * (1 - (playerGlobalCDR_Percent / 100))
    end
    spell.currentCooldown = finalCooldown

    -- Game.triggerSpellEffect will be responsible for creating the actual spell effect in the game world
    if Game and Game.triggerSpellEffect then
        Game.triggerSpellEffect(Player.data, spell, targetX, targetY)
        return true
    else
        print("Player.castSpell: Error - Game.triggerSpellEffect not found!")
        -- Reset cooldown if Game module isn't available, to prevent locking out player
        spell.currentCooldown = 0
        return false
    end
end

function Player.draw()
    -- Use DebugSettings instead of Config for playerScale
    if not (Assets and Assets.player_spritesheet and DebugSettings and Player.quads) then
        if not DebugSettings then print("Warning (Player.draw): DebugSettings not available for scaling.")
        else
            if not Config then print("Warning (Player.draw): Config not available for scaling (should be DebugSettings).") end
        end
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
        (DebugSettings and DebugSettings.playerScale) or 0.5, -- Use DebugSettings
        (DebugSettings and DebugSettings.playerScale) or 0.5, -- Use DebugSettings
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

function Player.initializeSpells(spellsDataDefinitions)
    Player.data.spells = {} -- Clear and initialize
    -- Player.data.spellUpgradePoints = 0 -- This is set to 0 in Player.data initial definition

    local spellIds = {} -- Get spell IDs in a defined order
    if spellsDataDefinitions then
        for id, _ in pairs(spellsDataDefinitions) do
            table.insert(spellIds, id)
        end
        -- Sort IDs alphabetically for some consistency if pairs() order varies
        table.sort(spellIds)
    end

    local numSlots = 5
    for i = 1, numSlots do
        local spellId = spellIds[i] -- Get the i-th spell ID from the sorted list
        if spellId and spellsDataDefinitions and spellsDataDefinitions[spellId] then
            local baseSpellData = spellsDataDefinitions[spellId]

            local newEffects = {}
            if baseSpellData.effects then
                newEffects = utils.deepCopy(baseSpellData.effects) -- Use deepCopy for structured effects table
            end

            Player.data.spells[i] = {
                id = spellId,
                name = baseSpellData.name,
                icon = baseSpellData.icon,
                type = baseSpellData.type,
                effects = newEffects,

                currentCooldown = 0,
                level = 0,
                upgrades = {}, -- For specific upgrade node levels of this spell

                -- Base stats (also store them for reference if needed for upgrades)
                baseDamage = baseSpellData.baseDamage,
                baseCooldown = baseSpellData.cooldown,
                baseRange = baseSpellData.range,
                baseAoeRadius = baseSpellData.aoeRadius,
                basePierce = baseSpellData.pierce,

                -- Calculated stats (initially same as base)
                calculatedDamage = baseSpellData.baseDamage,
                calculatedCooldown = baseSpellData.cooldown,
                calculatedRange = baseSpellData.range,
                calculatedAoeRadius = baseSpellData.aoeRadius,
                calculatedPierce = baseSpellData.pierce
            }
        else
            Player.data.spells[i] = nil -- No spell for this slot
        end
    end
end

function Player.addItemToInventory(itemData)
    if not Player.data.inventory or not Player.data.inventory.items then
        print("Error: Player inventory not initialized.")
        return false
    end

    local inv = Player.data.inventory
    local itemName = itemData.name or itemData.id -- Use name for print, id for comparison

    -- Try to stack if stackable
    if itemData.stackable then
        for i = 1, inv.maxSlots do
            local slotItem = inv.items[i]
            if slotItem and slotItem.id == itemData.id then
                local currentQuantity = slotItem.quantity or 0
                local maxStack = itemData.maxStack or 99 -- Use itemData's maxStack definition
                if currentQuantity < maxStack then
                    slotItem.quantity = currentQuantity + 1
                    -- print("Stacked " .. itemName .. " in slot " .. i .. ". New quantity: " .. slotItem.quantity)
                    return true -- Item stacked
                end
            end
        end
    end

    -- Try to find an empty slot for non-stackable or if existing stacks are full
    for i = 1, inv.maxSlots do
        if inv.items[i] == nil then
            inv.items[i] = utils.deepCopy(itemData) -- Store a copy
            if inv.items[i].stackable then -- Initialize quantity if it's stackable, even for a new stack
                inv.items[i].quantity = 1
            else
                inv.items[i].quantity = nil -- Ensure non-stackable items don't have quantity field or set to 1 if appropriate
            end
            -- print("Added " .. itemName .. " to empty slot " .. i)
            return true -- Item added to empty slot
        end
    end

    -- print("Inventory full. Could not add " .. itemName)
    return false -- Inventory is full
end

function Player.equipItem(itemData)
    if not itemData or itemData.type ~= "gear" then
        print("Player.equipItem: Invalid item or item is not gear.")
        return false
    end

    local slotName = itemData.slot
    if not Player.data.gear[slotName] then -- Check if slot exists
        print("Player.equipItem: Invalid gear slot: " .. tostring(slotName))
        return false
    end

    if Player.data.gear[slotName] == nil then
        Player.data.gear[slotName] = utils.deepCopy(itemData) -- Store a copy
        print("Player.equipItem: Equipped " .. itemData.name .. " to " .. slotName .. ".")
        if Player.recalculateBonuses then Player.recalculateBonuses() end
        return true
    else
        -- For now, just print a message if the slot is occupied.
        -- Later, this could be extended to swap with inventory.
        print("Player.equipItem: Slot " .. slotName .. " is already occupied by " .. Player.data.gear[slotName].name .. ".")
        return false
    end
end

function Player.unequipItem(slotName)
    if not slotName or not Player.data.gear[slotName] then
        print("Player.unequipItem: Invalid slot or no item in slot: " .. tostring(slotName))
        return false
    end

    local itemToUnequip = Player.data.gear[slotName]

    -- Attempt to add to inventory
    if Player.addItemToInventory(itemToUnequip) then
        Player.data.gear[slotName] = nil
        print("Player.unequipItem: Unequipped " .. itemToUnequip.name .. " from " .. slotName .. " and added to inventory.")
        if Player.recalculateBonuses then Player.recalculateBonuses() end
        return true
    else
        print("Player.unequipItem: Failed to unequip " .. itemToUnequip.name .. ". Inventory might be full.")
        return false
    end
end

return Player
