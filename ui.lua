local UI = {}

UI.state = {
    showInventory = false,
    showUpgradeTree = true,
    showRealmList = false
}

UI.treeOffset = { x = 0, y = 0 }

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
    UI.treeOffset.x = UI.treeOffset.x + dx
    UI.treeOffset.y = UI.treeOffset.y + dy
end

function UI.drawHUD(playerData, currentRealm)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP: " .. playerData.hp .. "/" .. playerData.maxHp, 10, 10)
    love.graphics.print("Level: " .. playerData.level .. " EXP: " .. playerData.exp, 10, 30)
    love.graphics.print("Kills: " .. playerData.kills, 10, 50)
    love.graphics.print("Gold: " .. playerData.gold, 10, 70)
    love.graphics.print("Essence T1: " .. playerData.essence.tier1 .. " T2: " .. playerData.essence.tier2, 10, 90)
    love.graphics.print("Realm: " .. currentRealm, 10, 110)
end

function UI.drawInventory(playerGold, playerEssenceT1, playerEssenceT2)
    if not UI.state.showInventory then return end
    love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
    love.graphics.rectangle("fill", 200, 150, 400, 300)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Inventory", 350, 160)
end

function UI.drawRealmList(realmsTable, currentRealm)
    if not UI.state.showRealmList then return end
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 600, 50, 180, 300)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Realms Unlocked:", 610, 60)
    for i, realmName in ipairs(realmsTable) do
        local displayStr = realmName
        if i == currentRealm then
            displayStr = displayStr .. " (Current)"
        end
        love.graphics.print(displayStr, 610, 60 + i * 20)
    end
end

function UI.drawUpgradeTree(upgradeNodesTable, effectParams)
    if not UI.state.showUpgradeTree then return end

    local nodeRadius = 15
    local defaultFillR, defaultFillG, defaultFillB = 0.7, 0.7, 0.7 -- Default grey
    local offenseColorR, offenseColorG, offenseColorB = 1, 0.2, 0.2     -- Red-ish
    local defenseColorR, defenseColorG, defenseColorB = 0.2, 0.2, 1     -- Blue-ish
    local supportColorR, supportColorG, supportColorB = 0.2, 1, 0.2     -- Green-ish
    local maxedBorderR, maxedBorderG, maxedBorderB = 1, 0.84, 0       -- Gold
    local textColorR, textColorG, textColorB = 1, 1, 1                 -- White
    local lineColorR, lineColorG, lineColorB = 0.5, 0.5, 0.5           -- Grey

    for _, node in ipairs(upgradeNodesTable) do
        local r, g, b = defaultFillR, defaultFillG, defaultFillB
        if node.category == "Offense" then
            r, g, b = offenseColorR, offenseColorG, offenseColorB
        elseif node.category == "Defense" then
            r, g, b = defenseColorR, defenseColorG, defenseColorB
        elseif node.category == "Support" then
            r, g, b = supportColorR, supportColorG, supportColorB
        end

        love.graphics.setColor(r, g, b)
        love.graphics.circle("fill", node.x + UI.treeOffset.x, node.y + UI.treeOffset.y, nodeRadius)

        if node.maxed then
            love.graphics.setLineWidth(2)
            love.graphics.setColor(maxedBorderR, maxedBorderG, maxedBorderB)
            love.graphics.circle("line", node.x + UI.treeOffset.x, node.y + UI.treeOffset.y, nodeRadius)
            love.graphics.setLineWidth(1) -- Reset line width
        end

        love.graphics.setColor(textColorR, textColorG, textColorB)
        local levelStr = node.level .. "/" .. node.maxLevel
        if node.maxed then
            levelStr = levelStr .. " (MAXED +3)"
        end
        love.graphics.print(levelStr, node.x - 10 + UI.treeOffset.x, node.y - 5 + UI.treeOffset.y)

        local effectKey = node.effect
        local effectDisplayName = effectKey
        if effectParams and effectParams[effectKey] and effectParams[effectKey].name then
            effectDisplayName = effectParams[effectKey].name
        end
        local categoryDisplayName = node.category or "N/A"
        love.graphics.print(effectDisplayName .. " [" .. categoryDisplayName .. "]", node.x - 30 + UI.treeOffset.x, node.y + 20 + UI.treeOffset.y)

        love.graphics.setColor(lineColorR, lineColorG, lineColorB)
        if node.children then
            for _, childNodeRef in ipairs(node.children) do
                local childNode = childNodeRef
                if childNode and childNode.x and childNode.y then
                    love.graphics.line(node.x + UI.treeOffset.x, node.y + UI.treeOffset.y, childNode.x + UI.treeOffset.x, childNode.y + UI.treeOffset.y)
                end
            end
        end
    end
    love.graphics.setColor(1,1,1) -- Reset color after drawing all nodes
end

return UI
