local UI = {}

UI.state = {
    showInventory = false,
    showUpgradeTree = true,
    showRealmList = false,
    showStatsMenu = false,
    showPauseMenu = false,
    showDebugMenu = false, -- Added for Debug Menu
    currentUpgradeTreeView = "player", -- "player" or "spell"
    currentSpellSlotView = 1 -- 1 to 5, relevant if currentUpgradeTreeView is "spell"
}

UI.pauseMenuButtons = {} -- To store button data for click detection
UI.upgradeTreeViewSwitchButtons = {} -- For "Player", "Spell 1-5" buttons
UI.spellSlotRegions = {} -- For HUD spell slot hover detection (tooltips)
UI.debugMenuControls = {} -- For clickable regions in the debug menu

UI.treeOffset = { x = 0, y = 0 } -- This offset itself is not scaled by uiScaleFactor, it's a camera pan.
UI.treeZoom = 1.0
UI.MIN_ZOOM = 0.5
UI.MAX_ZOOM = 3.0

function UI.toggleInventory()
    UI.state.showInventory = not UI.state.showInventory
end

function UI.toggleUpgradeTree()
    UI.state.showUpgradeTree = not UI.state.showUpgradeTree
end

function UI.toggleRealmList()
    UI.state.showRealmList = not UI.state.showRealmList
end

function UI.moveUpgradeTreeCamera(dx, dy)
    -- The camera movement step could be scaled if desired, but for now, keeping it as is.
    -- Example if scaling movement: local moveStep = 20 * ((Config and Config.uiScaleFactor) or 1)
    UI.treeOffset.x = UI.treeOffset.x + dx
    UI.treeOffset.y = UI.treeOffset.y + dy
end

function UI.drawHUD(playerData, currentRealm)
    local uiScale = (DebugSettings and DebugSettings.uiScaleFactor) or 1
    local xPos = 10 * uiScale
    local yPos = 10 * uiScale
    local lineStep = (DebugSettings and DebugSettings.baseFontSize or 14) * 1.5 * uiScale -- Base line height on font size

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP: " .. playerData.hp .. "/" .. playerData.maxHp, xPos, yPos)
    yPos = yPos + lineStep
    love.graphics.print("Level: " .. playerData.level .. " EXP: " .. playerData.exp, xPos, yPos)
    yPos = yPos + lineStep
    love.graphics.print("Kills: " .. playerData.kills, xPos, yPos)
    yPos = yPos + lineStep
    love.graphics.print("Gold: " .. playerData.gold, xPos, yPos)
    yPos = yPos + lineStep
    -- love.graphics.print("Essence T1: " .. playerData.essence.tier1 .. " T2: " .. playerData.essence.tier2, xPos, yPos) -- REMOVED
    -- yPos = yPos + lineStep -- REMOVED (this was for essence line spacing)
    love.graphics.print("Realm: " .. currentRealm, xPos, yPos)
end

function UI.drawInventory(playerGold, playerEssenceT1, playerEssenceT2)
    if not UI.state.showInventory then return end
    local uiScale = (DebugSettings and DebugSettings.uiScaleFactor) or 1

    local rectX = 200 * uiScale
    local rectY = 150 * uiScale
    local rectW = 400 * uiScale
    local rectH = 300 * uiScale
    local titleX = rectX + (rectW / 2) - (love.graphics.getFont():getWidth("Inventory") / 2) -- Centered title
    local titleY = rectY + (10 * uiScale)


    love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
    love.graphics.rectangle("fill", rectX, rectY, rectW, rectH)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Inventory", titleX, titleY)
    -- Add scaled text for gold/essence here if needed
end

function UI.drawRealmList(realmsTable, currentRealm)
    if not UI.state.showRealmList then return end
    local uiScale = (DebugSettings and DebugSettings.uiScaleFactor) or 1
    local windowWidth = (DebugSettings and DebugSettings.windowWidth) or love.graphics.getWidth() -- Prefer current width

    local rectW = 180 * uiScale
    local rectH = 300 * uiScale
    local rectX = windowWidth - rectW - (10 * uiScale) -- Positioned 10 (scaled) from right edge
    local rectY = 50 * uiScale

    local textXOffset = 10 * uiScale
    local titleYOffset = 10 * uiScale
    local lineStep = (DebugSettings and DebugSettings.baseFontSize or 14) * 1.5 * uiScale

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", rectX, rectY, rectW, rectH)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Realms Unlocked:", rectX + textXOffset, rectY + titleYOffset)

    local currentY = rectY + titleYOffset + lineStep
    for i, realmName in ipairs(realmsTable) do
        local displayStr = realmName
        if i == currentRealm then
            displayStr = displayStr .. " (Current)"
        end
        love.graphics.print(displayStr, rectX + textXOffset, currentY)
        currentY = currentY + lineStep
    end
end

-- Modified to accept nodesToDraw, effectParams, the source of upgrades (Player.data.upgrades or spell.upgrades), and a treeIdentifier
function UI.drawUpgradeTree(nodesToDraw, currentEffectParams, upgradesSource, treeIdentifier)
    if not UI.state.showUpgradeTree then return end

    local uiScale = (DebugSettings and DebugSettings.uiScaleFactor) or 1 -- Ensure uiScale is available at the top

    -- First, draw tree switching UI elements (outside the zoom/pan push/pop)
    UI.upgradeTreeViewSwitchButtons = {} -- Clear previous buttons
    love.graphics.setColor(0.8, 0.8, 0.8, 1) -- Light grey for text buttons
    local switchButtonHeight = 20 * uiScale
    local switchButtonY = 10 * uiScale
    local switchButtonXStart = 10 * uiScale
    local buttonPadding = 10 * uiScale

    local viewOptions = {"Player Tree"}
    for i=1,5 do table.insert(viewOptions, "Spell " .. i) end

    local currentX = switchButtonXStart
    for i, viewName in ipairs(viewOptions) do
        local textWidth = love.graphics.getFont():getWidth(viewName)
        local btnW = textWidth + buttonPadding

        -- Highlight active view
        local isActive = false
        if viewName == "Player Tree" and UI.state.currentUpgradeTreeView == "player" then
            isActive = true
        elseif string.sub(viewName, 1, 5) == "Spell" then
            local slotNum = tonumber(string.sub(viewName, 7))
            if UI.state.currentUpgradeTreeView == "spell" and UI.state.currentSpellSlotView == slotNum then
                isActive = true
            end
        end

        if isActive then
            love.graphics.setColor(1,1,0,1) -- Yellow for active
        else
            love.graphics.setColor(0.7,0.7,0.7,1) -- Grey for inactive
        end
        love.graphics.print(viewName, currentX, switchButtonY)

        table.insert(UI.upgradeTreeViewSwitchButtons, {
            id = viewName, -- e.g., "Player Tree" or "Spell 1"
            x = currentX, y = switchButtonY, w = btnW, h = switchButtonHeight
        })
        currentX = currentX + btnW + buttonPadding
    end
    love.graphics.setColor(1,1,1) -- Reset color

    -- Display current tree path for clarity (below switch buttons)
    local treePathDisplayY = switchButtonY + switchButtonHeight + (5 * uiScale)
    local currentTreeName = "Unknown Tree"
    if treeIdentifier == "player" then
        currentTreeName = "Player Attributes Tree"
    elseif treeIdentifier then -- Should be a spell ID if not player
        currentTreeName = "Spell Tree: " .. treeIdentifier
    end
    if nodesToDraw == nil or #nodesToDraw == 0 then
        currentTreeName = currentTreeName .. " (No data or spell not equipped)"
    end
    love.graphics.print("Viewing: " .. currentTreeName, switchButtonXStart, treePathDisplayY)
    love.graphics.print("Spell Points: " .. (Player and Player.data and Player.data.spellUpgradePoints or 0), switchButtonXStart, treePathDisplayY + (15 * uiScale))
    love.graphics.print("Skill Points: " .. (Player and Player.data and Player.data.skillPoints or 0), switchButtonXStart, treePathDisplayY + (30 * uiScale))


    love.graphics.push()
    -- Ensure upgradeNodesTable and effectParams are the passed arguments nodesToDraw and currentEffectParams
    if not nodesToDraw or not currentEffectParams then
        -- print("UI.drawUpgradeTree: nodesToDraw or currentEffectParams are nil. TreeIdentifier: " .. tostring(treeIdentifier))
        love.graphics.print("No upgrade data for current selection.", love.graphics.getWidth()/3, love.graphics.getHeight()/2)
        love.graphics.pop()
        return
    end

    local centerX = love.graphics.getWidth() / 2
    local centerY = love.graphics.getHeight() / 2

    -- Translate so the zoom is centered around the screen's center, then apply offset
    love.graphics.translate(centerX, centerY)
    love.graphics.scale(UI.treeZoom, UI.treeZoom)
    love.graphics.translate(-centerX + UI.treeOffset.x, -centerY + UI.treeOffset.y)

    -- nodeRadius is now the base model radius; visual size comes from graphics transform
    local nodeDrawRadius = 15
    -- Text offsets and line widths will also be affected by the scale transform.
    -- If fixed screen-space size is desired for some elements, they'd need to be divided by UI.treeZoom.
    -- For now, let them scale.

    local defaultFillR, defaultFillG, defaultFillB = 0.7, 0.7, 0.7
    local offenseColorR, offenseColorG, offenseColorB = 1, 0.2, 0.2
    local defenseColorR, defenseColorG, defenseColorB = 0.2, 0.2, 1
    local supportColorR, supportColorG, supportColorB = 0.2, 1, 0.2
    local maxedBorderR, maxedBorderG, maxedBorderB = 1, 0.84, 0
    local textColorR, textColorG, textColorB = 1, 1, 1
    local lineColorR, lineColorG, lineColorB = 0.5, 0.5, 0.5
    local scaledLineWidth = math.max(1, (1 * uiScale) / UI.treeZoom ) -- Attempt to keep line width somewhat consistent
    local scaledBorderWidth = math.max(1, (2 * uiScale) / UI.treeZoom ) -- Attempt to keep border width somewhat consistent

    for _, node in ipairs(nodesToDraw) do
        local r, g, b = defaultFillR, defaultFillG, defaultFillB
        if node.category == "Offense" then r, g, b = offenseColorR, offenseColorG, offenseColorB
        elseif node.category == "Defense" then r, g, b = defenseColorR, defenseColorG, defenseColorB
        elseif node.category == "Support" then r, g, b = supportColorR, supportColorG, supportColorB
        end

        love.graphics.setColor(r, g, b)
        love.graphics.circle("fill", node.x, node.y, nodeDrawRadius) -- Use node.x, node.y directly (world coords)

        if node.maxed then
            love.graphics.setLineWidth(scaledBorderWidth)
            love.graphics.setColor(maxedBorderR, maxedBorderG, maxedBorderB)
            love.graphics.circle("line", node.x, node.y, nodeDrawRadius)
        end

        -- love.graphics.print doesn't use line width. Text will scale with the main transform.
        love.graphics.setColor(textColorR, textColorG, textColorB)

        local currentLevel
        if treeIdentifier == "player" then
            currentLevel = node.level -- Player tree nodes store their own level
        else
            currentLevel = upgradesSource[node.id] or 0 -- Spell tree levels from playerSpellInstance.upgrades
        end
        local levelStr = currentLevel .. "/" .. node.maxLevel

        -- Maxed display for player tree specifically (spell tree maxed logic might differ or not be needed here)
        if treeIdentifier == "player" and node.maxed then
            levelStr = levelStr .. " (MAXED +3)"
        elseif treeIdentifier ~= "player" and currentLevel == node.maxLevel then
             levelStr = levelStr .. " (MAXED)" -- Simple max display for spell nodes
        end

        -- Scaled text offsets - these are in world units relative to node.x, node.y
        -- The uiScale here makes them consistent with other UI elements if zoom is 1.
        -- They will naturally scale with UI.treeZoom.
        local textOffsetX = 10 * uiScale
        local textOffsetYLevel = 5 * uiScale
        local textOffsetYEffect = 20 * uiScale
        local textOffsetXEffect = 30 * uiScale

        love.graphics.print(levelStr, node.x - textOffsetX, node.y - textOffsetYLevel)

        local effectKey = node.effect
        local effectDisplayName = effectKey
        if currentEffectParams and currentEffectParams[effectKey] and currentEffectParams[effectKey].name then
            effectDisplayName = currentEffectParams[effectKey].name
        end

        local nodeName = node.name or effectDisplayName -- Use node.name if available (for spell tree nodes)
        local categoryDisplayName = node.category or "N/A"
        love.graphics.print(nodeName .. " [" .. categoryDisplayName .. "]", node.x - textOffsetXEffect, node.y + textOffsetYEffect)

        love.graphics.setColor(lineColorR, lineColorG, lineColorB)
        love.graphics.setLineWidth(scaledLineWidth)
        if node.children then
            for _, childNodeRef in ipairs(node.children) do
                local childNode = childNodeRef
                if childNode and childNode.x and childNode.y then
                    love.graphics.line(node.x, node.y, childNode.x, childNode.y) -- Use world coords
                end
            end
        end
    end

    love.graphics.pop() -- Restore previous transform state
    love.graphics.setLineWidth(1) -- Reset line width globally after finishing with tree
    love.graphics.setColor(1,1,1) -- Reset color globally
end

function UI.toggleStatsMenu()
    UI.state.showStatsMenu = not UI.state.showStatsMenu
    -- Optional: make it mutually exclusive with other UIs if needed
    -- if UI.state.showStatsMenu then
    --     UI.state.showUpgradeTree = false
    --     UI.state.showInventory = false
    --     UI.state.showRealmList = false
    -- end
end

function UI.drawStatsMenu(playerData)
    if not UI.state.showStatsMenu then return end

    local uiScale = (DebugSettings and DebugSettings.uiScaleFactor) or 1
    local xPadding = 15 * uiScale -- Was 20
    local yPadding = 15 * uiScale -- Was 20
    local lineStep = (DebugSettings and DebugSettings.baseFontSize or 14) * 1.8 * uiScale -- Slightly larger line step for readability
    local startX = 150 * uiScale
    local startY = 100 * uiScale
    local menuWidth = 280 * uiScale -- Was 400
    local menuHeight = 315 * uiScale -- Was 450

    -- Draw menu background
    love.graphics.setColor(0.1, 0.1, 0.15, 0.9) -- Dark blueish background
    love.graphics.rectangle("fill", startX, startY, menuWidth, menuHeight)
    love.graphics.setColor(0.8, 0.8, 0.8, 1) -- Border color
    love.graphics.setLineWidth(2 * uiScale)
    love.graphics.rectangle("line", startX, startY, menuWidth, menuHeight)
    love.graphics.setLineWidth(1) -- Reset line width

    -- Title
    love.graphics.setColor(1, 1, 1, 1)
    local titleText = "Player Statistics"
    -- Ensure font is available for getWidth, love.graphics.getFont() should be valid if set in love.load
    local currentFont = love.graphics.getFont()
    local titleWidth = currentFont:getWidth(titleText)
    love.graphics.print(titleText, startX + (menuWidth - titleWidth) / 2, startY + yPadding)

    -- Stats content
    local currentY = startY + yPadding + lineStep * 1.5 -- Extra space after title
    local textX = startX + xPadding

    if not playerData then
        love.graphics.print("Player data not available.", textX, currentY)
        love.graphics.setColor(1,1,1) -- Reset color
        return
    end

    love.graphics.print("Skill Points: " .. (playerData.skillPoints or 0), textX, currentY)
    currentY = currentY + lineStep

    love.graphics.print("Essence T1: " .. (playerData.essence and playerData.essence.tier1 or 0), textX, currentY)
    currentY = currentY + lineStep
    love.graphics.print("Essence T2: " .. (playerData.essence and playerData.essence.tier2 or 0), textX, currentY)
    currentY = currentY + lineStep
    currentY = currentY + lineStep -- Extra space

    -- Basic stats
    love.graphics.print("Level: " .. (playerData.level or 0), textX, currentY)
    currentY = currentY + lineStep
    love.graphics.print("Experience: " .. (playerData.exp or 0) .. "/" .. ((playerData.level or 0) * 100), textX, currentY)
    currentY = currentY + lineStep
    love.graphics.print("HP: " .. string.format("%.0f", playerData.hp or 0) .. "/" .. string.format("%.0f", playerData.maxHp or 0), textX, currentY)
    currentY = currentY + lineStep
    love.graphics.print("Movement Speed: " .. string.format("%.0f", playerData.speed or 0), textX, currentY)
    currentY = currentY + lineStep
    love.graphics.print("Kills: " .. (playerData.kills or 0), textX, currentY)
    currentY = currentY + lineStep
    love.graphics.print("Gold: " .. (playerData.gold or 0), textX, currentY)
    currentY = currentY + lineStep

    -- Calculated bonuses
    currentY = currentY + lineStep -- Extra space before bonuses
    love.graphics.print("Bonuses:", textX, currentY)
    currentY = currentY + lineStep
    if playerData.calculatedBonuses then
        love.graphics.print(string.format("  Damage: +%.1f%%", playerData.calculatedBonuses.DMG or 0), textX, currentY)
        currentY = currentY + lineStep
        love.graphics.print(string.format("  Cooldown Reduction: +%.1f%%", playerData.calculatedBonuses.CDR or 0), textX, currentY)
        currentY = currentY + lineStep
        love.graphics.print(string.format("  Max HP Bonus: +%.0f", playerData.calculatedBonuses.HP_MAX or 0), textX, currentY)
        currentY = currentY + lineStep
        love.graphics.print(string.format("  Move Speed Bonus: +%.1f%%", playerData.calculatedBonuses.MOVE_SPEED or 0), textX, currentY)
        currentY = currentY + lineStep
    else
        love.graphics.print("  No bonuses calculated.", textX, currentY)
        currentY = currentY + lineStep
    end
    love.graphics.setColor(1,1,1) -- Reset color
end

function UI.togglePauseMenu()
    UI.state.showPauseMenu = not UI.state.showPauseMenu
    -- If opening pause menu, consider closing other major UI elements
    if UI.state.showPauseMenu then
        UI.state.showUpgradeTree = false
        UI.state.showInventory = false
        UI.state.showRealmList = false
        UI.state.showStatsMenu = false
    end
end

function UI.drawPauseMenu()
    if not UI.state.showPauseMenu then return end

    local uiScale = (DebugSettings and DebugSettings.uiScaleFactor) or 1
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()

    -- Draw semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Button properties
    love.graphics.setColor(1, 1, 1) -- Text and button outline color
    local buttonW = 200 * uiScale
    local buttonH = 50 * uiScale
    local spacing = 20 * uiScale
    local numButtons = 4
    local totalButtonHeight = (numButtons * buttonH) + ((numButtons - 1) * spacing)
    local startY = (screenH - totalButtonHeight) / 2

    UI.pauseMenuButtons = {} -- Clear and rebuild button data each time it's drawn

    local options = {"Continue", "Settings", "Credits", "Quit"}
    local currentFont = love.graphics.getFont() -- Get current font for text centering

    for i, option in ipairs(options) do
        local btnX = (screenW - buttonW) / 2
        local btnY = startY + (i - 1) * (buttonH + spacing)

        -- Draw button rectangle (outline)
        love.graphics.setLineWidth(2 * uiScale)
        love.graphics.rectangle("line", btnX, btnY, buttonW, buttonH)
        love.graphics.setLineWidth(1) -- Reset line width

        -- Draw button text (centered)
        -- love.graphics.printf can center, but need to adjust y for vertical centering.
        -- A common way for vertical centering with printf is to print at y + (buttonH - fontHeight)/2
        -- For simplicity here, a slight offset from top of button.
        local textWidth = currentFont:getWidth(option)
        local textHeight = currentFont:getHeight() -- Approximate height
        love.graphics.print(option, btnX + (buttonW - textWidth) / 2, btnY + (buttonH - textHeight) / 2)


        table.insert(UI.pauseMenuButtons, {
            label = option,
            x = btnX, y = btnY, w = buttonW, h = buttonH
        })
    end
    love.graphics.setColor(1,1,1) -- Reset color
end

function UI.drawSpellSlots(playerSpells)
    if not playerSpells then return end

    local uiScale = (DebugSettings and DebugSettings.uiScaleFactor) or 1
    local slotSize = 48 * uiScale
    local slotSpacing = 10 * uiScale
    local numSlots = 5

    local totalWidth = (numSlots * slotSize) + ((numSlots - 1) * slotSpacing)
    local startX = (love.graphics.getWidth() - totalWidth) / 2
    local startY = love.graphics.getHeight() - (slotSize + (10 * uiScale))

    UI.spellSlotRegions = {} -- Clear for current frame

    for i = 1, numSlots do
        local slotX = startX + (i - 1) * (slotSize + slotSpacing)
        local slotY = startY
        local playerSpell = playerSpells[i]

        -- Store region for tooltips/interaction
        table.insert(UI.spellSlotRegions, {
            slotIndex = i,
            x = slotX, y = slotY, w = slotSize, h = slotSize
        })

        -- Draw slot background
        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", slotX, slotY, slotSize, slotSize)
        love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
        love.graphics.rectangle("line", slotX, slotY, slotSize, slotSize)

        if playerSpell then
            -- Draw Icon
            if playerSpell.icon then
                local iconFileName = playerSpell.icon:match("([^/]+)%.png$") -- e.g., "spell_fireball"
                if iconFileName and Assets and Assets[iconFileName] then
                    local iconImage = Assets[iconFileName]
                    local scaleX = slotSize / iconImage:getWidth()
                    local scaleY = slotSize / iconImage:getHeight()
                    love.graphics.setColor(1,1,1)
                    love.graphics.draw(iconImage, slotX, slotY, 0, scaleX, scaleY)
                else
                    love.graphics.setColor(0.4, 0.4, 0.4, 0.8) -- Placeholder for missing icon
                    love.graphics.rectangle("fill", slotX + slotSize*0.1, slotY + slotSize*0.1, slotSize*0.8, slotSize*0.8)
                    love.graphics.setColor(1,1,1)
                    love.graphics.print("?", slotX + slotSize/2 - love.graphics.getFont():getWidth("?")/2, slotY + slotSize/2 - love.graphics.getFont():getHeight()/2)
                end
            end

            -- Draw Keybind Text (e.g., "1")
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(tostring(i), slotX + 3 * uiScale, slotY + 3 * uiScale)

            -- Draw Cooldown Overlay
            if playerSpell.currentCooldown > 0 and playerSpell.calculatedCooldown > 0 then
                local cooldownPercent = playerSpell.currentCooldown / playerSpell.calculatedCooldown
                local overlayHeight = slotSize * cooldownPercent
                love.graphics.setColor(0, 0, 0, 0.7)
                love.graphics.rectangle("fill", slotX, slotY + (slotSize - overlayHeight), slotSize, overlayHeight)
            end
        else
            -- Empty slot
            love.graphics.setColor(0.8, 0.8, 0.8, 1)
            love.graphics.print(tostring(i), slotX + 3 * uiScale, slotY + 3 * uiScale)
            -- Optional: Draw an "Empty" text or different background
        end
    end
    love.graphics.setColor(1,1,1) -- Reset color
end

function UI.drawDebugMenu()
    if not UI.state.showDebugMenu then return end

    local uiScale = (DebugSettings and DebugSettings.uiScaleFactor) or 1
    local baseFontSize = (DebugSettings and DebugSettings.baseFontSize or 14) -- Ensure baseFontSize is available
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    local panelX = screenW * 0.15
    local panelY = screenH * 0.15
    local panelW = screenW * 0.7
    local panelH = screenH * 0.7
    local padding = 20 * uiScale
    local lineHeight = baseFontSize * 1.8 * uiScale
    local buttonSize = 20 * uiScale -- For +/- buttons

    UI.debugMenuControls = {} -- Clear controls for this frame

    -- Draw background panel
    love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(1, 1, 1, 1)
    local titleText = "Debug Menu"
    local currentFont = love.graphics.getFont() -- Get current font
    local titleWidth = currentFont:getWidth(titleText)
    love.graphics.print(titleText, panelX + (panelW - titleWidth) / 2, panelY + padding)

    local currentY = panelY + padding + lineHeight * 1.5
    local currentX = panelX + padding
    local valueDisplayWidth = 80 * uiScale
    local labelWidth = 200 * uiScale

    local tunableParams = {
        {label="Player Scale", key="playerScale", step=0.05, min=0.1, max=3.0},
        {label="Enemy Scale", key="enemyScale", step=0.05, min=0.1, max=3.0},
        {label="Projectile Scale", key="projectileScale", step=0.05, min=0.05, max=2.0},
        {label="Loot Scale", key="coinScale", step=0.05, min=0.1, max=2.0},
        {label="Hitbox Scale", key="hitboxScale", step=0.1, min=0.1, max=5.0},
        {label="UI Scale Factor", key="uiScaleFactor", step=0.1, min=0.5, max=5.0}
    }

    for _, param in ipairs(tunableParams) do
        love.graphics.setColor(1,1,1)
        love.graphics.print(param.label .. ":", currentX, currentY)

        local currentValue = (DebugSettings and DebugSettings[param.key]) or "N/A"
        local valueText = type(currentValue) == "number" and string.format("%.2f", currentValue) or tostring(currentValue)
        love.graphics.print(valueText, currentX + labelWidth, currentY)

        -- [-] button
        local minusButtonX = currentX + labelWidth + valueDisplayWidth
        love.graphics.rectangle("line", minusButtonX, currentY, buttonSize, buttonSize)
        love.graphics.print("-", minusButtonX + buttonSize/2 - currentFont:getWidth("-")/2, currentY + buttonSize/2 - currentFont:getHeight()/2)
        table.insert(UI.debugMenuControls, {
            action = "dec", paramKey = param.key, step = param.step, min = param.min,
            x = minusButtonX, y = currentY, w = buttonSize, h = buttonSize
        })

        -- [+] button
        local plusButtonX = minusButtonX + buttonSize + (5 * uiScale)
        love.graphics.rectangle("line", plusButtonX, currentY, buttonSize, buttonSize)
        love.graphics.print("+", plusButtonX + buttonSize/2 - currentFont:getWidth("+")/2, currentY + buttonSize/2 - currentFont:getHeight()/2)
        table.insert(UI.debugMenuControls, {
            action = "inc", paramKey = param.key, step = param.step, max = param.max,
            x = plusButtonX, y = currentY, w = buttonSize, h = buttonSize
        })

        currentY = currentY + lineHeight
    end -- closes: for _, param in ipairs(tunableParams)

    -- Reset to Defaults button
    currentY = currentY + lineHeight
    local resetText = "Reset to Defaults"
    local resetBtnW = currentFont:getWidth(resetText) + 2 * padding
    local resetBtnX = panelX + (panelW - resetBtnW) / 2
    local resetBtnH = buttonSize * 1.5
    love.graphics.rectangle("line", resetBtnX, currentY, resetBtnW, resetBtnH)
    love.graphics.print(resetText, resetBtnX + padding, currentY + (resetBtnH - currentFont:getHeight())/2)
    table.insert(UI.debugMenuControls, {
        action = "reset_debug",
        x = resetBtnX, y = currentY, w = resetBtnW, h = resetBtnH
    })
    currentY = currentY + resetBtnH + padding

    -- Back button (to close debug menu, typically returning to pause menu)
    local backText = "Back to Pause Menu"
    local backBtnW = currentFont:getWidth(backText) + 2 * padding
    local backBtnX = panelX + (panelW - backBtnW) / 2
    local backBtnH = buttonSize * 1.5
    currentY = panelY + panelH - backBtnH - padding -- Position at bottom
    love.graphics.rectangle("line", backBtnX, currentY, backBtnW, backBtnH)
    love.graphics.print(backText, backBtnX + padding, currentY + (backBtnH - currentFont:getHeight())/2)
    table.insert(UI.debugMenuControls, {
        action = "close_debug",
        x = backBtnX, y = currentY, w = backBtnW, h = backBtnH
    })

    love.graphics.setColor(1,1,1) -- Reset color
end -- closes: function UI.drawDebugMenu()

return UI
