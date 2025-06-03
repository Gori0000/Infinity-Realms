local UI = {}

UI.state = {
    showInventory = false,
    showUpgradeTree = true,
    showRealmList = false
}

UI.treeOffset = { x = 0, y = 0 } -- This offset itself is not scaled by uiScaleFactor, it's a camera pan.

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
    local uiScale = (Config and Config.uiScaleFactor) or 1
    local xPos = 10 * uiScale
    local yPos = 10 * uiScale
    local lineStep = (Config and Config.baseFontSize or 14) * 1.5 * uiScale -- Base line height on font size

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP: " .. playerData.hp .. "/" .. playerData.maxHp, xPos, yPos)
    yPos = yPos + lineStep
    love.graphics.print("Level: " .. playerData.level .. " EXP: " .. playerData.exp, xPos, yPos)
    yPos = yPos + lineStep
    love.graphics.print("Kills: " .. playerData.kills, xPos, yPos)
    yPos = yPos + lineStep
    love.graphics.print("Gold: " .. playerData.gold, xPos, yPos)
    yPos = yPos + lineStep
    love.graphics.print("Essence T1: " .. playerData.essence.tier1 .. " T2: " .. playerData.essence.tier2, xPos, yPos)
    yPos = yPos + lineStep
    love.graphics.print("Realm: " .. currentRealm, xPos, yPos)
end

function UI.drawInventory(playerGold, playerEssenceT1, playerEssenceT2)
    if not UI.state.showInventory then return end
    local uiScale = (Config and Config.uiScaleFactor) or 1

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
    local uiScale = (Config and Config.uiScaleFactor) or 1

    local rectW = 180 * uiScale
    local rectH = 300 * uiScale
    local rectX = (Config and Config.windowWidth or 1920) - rectW - (10 * uiScale) -- Positioned 10 (scaled) from right edge
    local rectY = 50 * uiScale

    local textXOffset = 10 * uiScale
    local titleYOffset = 10 * uiScale
    local lineStep = (Config and Config.baseFontSize or 14) * 1.5 * uiScale

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

function UI.drawUpgradeTree(upgradeNodesTable, effectParams)
    if not UI.state.showUpgradeTree then return end
    local uiScale = (Config and Config.uiScaleFactor) or 1

    local nodeRadius = 15 * uiScale
    local defaultFillR, defaultFillG, defaultFillB = 0.7, 0.7, 0.7
    local offenseColorR, offenseColorG, offenseColorB = 1, 0.2, 0.2
    local defenseColorR, defenseColorG, defenseColorB = 0.2, 0.2, 1
    local supportColorR, supportColorG, supportColorB = 0.2, 1, 0.2
    local maxedBorderR, maxedBorderG, maxedBorderB = 1, 0.84, 0
    local textColorR, textColorG, textColorB = 1, 1, 1
    local lineColorR, lineColorG, lineColorB = 0.5, 0.5, 0.5
    local scaledLineWidth = math.max(1, 1 * uiScale) -- Ensure line width is at least 1
    local scaledBorderWidth = math.max(1, 2 * uiScale)


    for _, node in ipairs(upgradeNodesTable) do
        local r, g, b = defaultFillR, defaultFillG, defaultFillB
        if node.category == "Offense" then r, g, b = offenseColorR, offenseColorG, offenseColorB
        elseif node.category == "Defense" then r, g, b = defenseColorR, defenseColorG, defenseColorB
        elseif node.category == "Support" then r, g, b = supportColorR, supportColorG, supportColorB
        end

        love.graphics.setColor(r, g, b)
        love.graphics.circle("fill", node.x + UI.treeOffset.x, node.y + UI.treeOffset.y, nodeRadius)

        if node.maxed then
            love.graphics.setLineWidth(scaledBorderWidth)
            love.graphics.setColor(maxedBorderR, maxedBorderG, maxedBorderB)
            love.graphics.circle("line", node.x + UI.treeOffset.x, node.y + UI.treeOffset.y, nodeRadius)
        end

        love.graphics.setLineWidth(scaledLineWidth) -- Set for text and connection lines if needed, or reset to 1 for text.
                                                 -- love.graphics.print doesn't use line width.
        love.graphics.setColor(textColorR, textColorG, textColorB)
        local levelStr = node.level .. "/" .. node.maxLevel
        if node.maxed then
            levelStr = levelStr .. " (MAXED +3)"
        end
        -- Scaled text offsets
        local textOffsetX = 10 * uiScale
        local textOffsetYLevel = 5 * uiScale
        local textOffsetYEffect = 20 * uiScale
        local textOffsetXEffect = 30 * uiScale

        love.graphics.print(levelStr, node.x - textOffsetX + UI.treeOffset.x, node.y - textOffsetYLevel + UI.treeOffset.y)

        local effectKey = node.effect
        local effectDisplayName = effectKey
        if effectParams and effectParams[effectKey] and effectParams[effectKey].name then
            effectDisplayName = effectParams[effectKey].name
        end
        local categoryDisplayName = node.category or "N/A"
        love.graphics.print(effectDisplayName .. " [" .. categoryDisplayName .. "]", node.x - textOffsetXEffect + UI.treeOffset.x, node.y + textOffsetYEffect + UI.treeOffset.y)

        love.graphics.setColor(lineColorR, lineColorG, lineColorB)
        love.graphics.setLineWidth(scaledLineWidth)
        if node.children then
            for _, childNodeRef in ipairs(node.children) do
                local childNode = childNodeRef
                if childNode and childNode.x and childNode.y then
                    love.graphics.line(node.x + UI.treeOffset.x, node.y + UI.treeOffset.y, childNode.x + UI.treeOffset.x, childNode.y + UI.treeOffset.y)
                end
            end
        end
    end
    love.graphics.setLineWidth(1) -- Reset line width to default after drawing tree
    love.graphics.setColor(1,1,1)
end

return UI
