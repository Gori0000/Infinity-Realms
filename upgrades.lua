local Upgrades = {}

Upgrades.nodes = {}

function Upgrades.categorizeNode(node)
    if node.id % 3 == 1 then node.category = "Offense"
    elseif node.id % 3 == 2 then node.category = "Defense"
    else node.category = "Support" end
end

function Upgrades.recalculatePlayerBonuses(Player, nodes)
    if not Player or not Player.data then
        print("Warning: Player data not available for recalculatePlayerBonuses.")
        return
    end

    local totalBonusDamage = 0
    local totalBonusCooldown = 0

    for _, node in ipairs(nodes) do
        if node.level > 0 then
            -- Simple string matching for effects
            if string.find(node.effect, "DMG") then
                -- Example: "+10% DMG" node. Each level gives 1 unit to bonusDamage.
                -- local percent = tonumber(string.match(node.effect, "(%d+)%% DMG"))
                -- if percent then totalBonusDamage = totalBonusDamage + (node.level * (percent / 10)) end
                totalBonusDamage = totalBonusDamage + (node.level * 1) -- Simplified: each level of a DMG node adds 1
            end
            if string.find(node.effect, "CDR") then
                -- Example: "+5% CDR" node. Each level gives 0.05 to bonusCooldown.
                -- local percent = tonumber(string.match(node.effect, "(%d+)%% CDR"))
                -- if percent then totalBonusCooldown = totalBonusCooldown + (node.level * (percent / 100)) end
                totalBonusCooldown = totalBonusCooldown + (node.level * 0.05) -- Simplified: each level of a CDR node adds 0.05
            end
            -- Add more effect parsing here if needed
        end
    end

    Player.data.bonusDamage = totalBonusDamage
    Player.data.bonusCooldown = totalBonusCooldown
    -- print("Recalculated Bonuses: DMG=" .. Player.data.bonusDamage .. ", CDR=" .. Player.data.bonusCooldown)
end

function Upgrades.initializeTree()
    Upgrades.nodes = {} 
    local root = {
        id = 1, 
        x = 400, y = 300, 
        level = 0, maxLevel = 10, 
        effect = "+10% DMG", -- Specific effect for root
        children = {}
    }
    Upgrades.categorizeNode(root)
    table.insert(Upgrades.nodes, root)
end

function Upgrades.expandTree(nodeToExpand)
    local actualNode = nil
    if type(nodeToExpand) == "number" then
        for _, n in ipairs(Upgrades.nodes) do
            if n.id == nodeToExpand then
                actualNode = n
                break
            end
        end
    else 
        actualNode = nodeToExpand
    end

    if not actualNode then
        print("Error: Node to expand not found for ID/object: ", nodeToExpand)
        return
    end
    
    if #actualNode.children == 0 then 
        local angleStep = math.pi / 4 
        local effects = {"+10% DMG", "+5% CDR"} -- Specific effects for new children

        for i = 1, 2 do
            local angle = angleStep * i
            local newNode = {
                id = #Upgrades.nodes + 1, 
                x = actualNode.x + math.cos(angle) * 100,
                y = actualNode.y + math.sin(angle) * 100,
                level = 0, maxLevel = 10,
                effect = effects[i] or "Default Effect " .. (#Upgrades.nodes + 1), -- Assign specific effect
                children = {}
            }
            Upgrades.categorizeNode(newNode)
            table.insert(actualNode.children, newNode) 
            table.insert(Upgrades.nodes, newNode)   
        end
    end
end

-- Modified to accept Player and call recalculatePlayerBonuses
function Upgrades.upgradeNode(nodeId, Player)
    local nodeToUpgrade = nil
    if nodeId >= 1 and nodeId <= #Upgrades.nodes then
        nodeToUpgrade = Upgrades.nodes[nodeId] 
    end

    if nodeToUpgrade and nodeToUpgrade.level < nodeToUpgrade.maxLevel then
        nodeToUpgrade.level = nodeToUpgrade.level + 1
        
        Upgrades.recalculatePlayerBonuses(Player, Upgrades.nodes) -- Recalculate bonuses
        
        if nodeToUpgrade.level == nodeToUpgrade.maxLevel then
            Upgrades.expandTree(nodeToUpgrade) 
        end
        return true 
    else
        return false 
    end
end

function Upgrades.getNodes()
    return Upgrades.nodes
end

return Upgrades
