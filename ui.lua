local UI = {}

UI.state = {
    showInventory = false,
    showUpgradeTree = true, -- Default as per original main.lua
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

-- Updated signature to accept effectParams
function UI.drawUpgradeTree(upgradeNodesTable, effectParams)
    if not UI.state.showUpgradeTree then return end
    
    local defaultNodeColor = {0.7, 0.7, 1}
    local maxedNodeColor = {1, 0.84, 0} -- Gold
    local textColor = {1, 1, 1} -- White
    local lineColor = {1, 1, 1} -- White for lines

    for _, node in ipairs(upgradeNodesTable) do
        if node.maxed then
            love.graphics.setColor(maxedNodeColor[1], maxedNodeColor[2], maxedNodeColor[3])
        else
            love.graphics.setColor(defaultNodeColor[1], defaultNodeColor[2], defaultNodeColor[3])
        end
        love.graphics.circle("fill", node.x + UI.treeOffset.x, node.y + UI.treeOffset.y, 15)

        -- Set color for text
        love.graphics.setColor(textColor[1], textColor[2], textColor[3])
        
        -- Level text
        local levelStr = node.level .. "/" .. node.maxLevel
        if node.maxed then
            levelStr = levelStr .. " (MAXED +3)"
        end
        love.graphics.print(levelStr, node.x - 10 + UI.treeOffset.x, node.y - 5 + UI.treeOffset.y)
        
        -- Effect text
        local effectKey = node.effect
        local effectDisplayName = effectKey -- Fallback to the key itself
        if effectParams and effectParams[effectKey] and effectParams[effectKey].name then
            effectDisplayName = effectParams[effectKey].name
        end
        local categoryDisplayName = node.category or "N/A"
        love.graphics.print(effectDisplayName .. " [" .. categoryDisplayName .. "]", node.x - 30 + UI.treeOffset.x, node.y + 20 + UI.treeOffset.y)
        
        -- Set color for lines to children
        love.graphics.setColor(lineColor[1], lineColor[2], lineColor[3])
        if node.children then 
            for _, childNodeRef in ipairs(node.children) do
                local childNode = childNodeRef 
                if childNode and childNode.x and childNode.y then 
                    love.graphics.line(node.x + UI.treeOffset.x, node.y + UI.treeOffset.y, childNode.x + UI.treeOffset.x, childNode.y + UI.treeOffset.y)
                end
            end
        end
    end
end

return UI
