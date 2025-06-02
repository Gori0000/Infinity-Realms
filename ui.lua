local UI = {}

UI.state = {
    showInventory = false,
    showUpgradeTree = true, -- Default as per original main.lua
    showRealmList = false
}

UI.treeOffset = { x = 0, y = 0 }

-- Optional: function UI.initialize() ... end

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

-- drawHUD now takes playerData and currentRealm
function UI.drawHUD(playerData, currentRealm)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP: " .. playerData.hp .. "/" .. playerData.maxHp, 10, 10)
    love.graphics.print("Level: " .. playerData.level .. " EXP: " .. playerData.exp, 10, 30)
    love.graphics.print("Kills: " .. playerData.kills, 10, 50)
    love.graphics.print("Gold: " .. playerData.gold, 10, 70)
    love.graphics.print("Essence T1: " .. playerData.essence.tier1 .. " T2: " .. playerData.essence.tier2, 10, 90)
    love.graphics.print("Realm: " .. currentRealm, 10, 110) -- currentRealm passed as argument
end

-- drawInventory now takes specific player currency data
function UI.drawInventory(playerGold, playerEssenceT1, playerEssenceT2)
    if not UI.state.showInventory then return end
    love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
    love.graphics.rectangle("fill", 200, 150, 400, 300)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Inventory", 350, 160)
    -- Display gold and essences if needed, e.g.:
    -- love.graphics.print("Gold: " .. playerGold, 210, 190)
    -- love.graphics.print("Essence T1: " .. playerEssenceT1, 210, 210)
    -- love.graphics.print("Essence T2: " .. playerEssenceT2, 210, 230)
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

function UI.drawUpgradeTree(upgradeNodesTable)
    if not UI.state.showUpgradeTree then return end
    for _, node in ipairs(upgradeNodesTable) do
        love.graphics.setColor(0.7, 0.7, 1)
        love.graphics.circle("fill", node.x + UI.treeOffset.x, node.y + UI.treeOffset.y, 15)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(node.level .. "/" .. node.maxLevel, node.x - 10 + UI.treeOffset.x, node.y - 5 + UI.treeOffset.y)
        love.graphics.print(node.effect .. " [" .. (node.category or "N/A") .. "]", node.x - 30 + UI.treeOffset.x, node.y + 20 + UI.treeOffset.y)
        if node.children then -- Ensure children exist
            for _, childNode in ipairs(node.children) do
                -- find the actual child node object from upgradeNodesTable if childNode is just an ID
                -- For now, assuming childNode is the actual node object as per previous structure.
                -- If childNode were an ID, you'd need to find it in upgradeNodesTable.
                 local childTarget = nil
                 for _, potentialChild in ipairs(upgradeNodesTable) do
                     if potentialChild.id == childNode.id then -- or however children are referenced
                         childTarget = potentialChild
                         break
                     end
                 end
                 -- If child references are direct objects (as they seem to be from expandTree), this lookup is not needed.
                 -- The original code directly iterated node.children which contained objects.
                 -- Let's assume node.children contains direct references to child node objects.
                if childNode and childNode.x and childNode.y then -- Ensure child has coordinates
                    love.graphics.line(node.x + UI.treeOffset.x, node.y + UI.treeOffset.y, childNode.x + UI.treeOffset.x, childNode.y + UI.treeOffset.y)
                end
            end
        end
    end
end

return UI
