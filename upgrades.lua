local Upgrades = {}

Upgrades.effectParams = {
    DMG = { 
        name = "Damage Bonus", 
        base = 100, -- Max potential bonus percentage (e.g., 100%)
        falloff = 0.98, 
        unit = "%" 
    },
    CDR = { 
        name = "Cooldown Reduction", 
        base = 50,  -- Max potential CDR (e.g., 50%)
        falloff = 0.97, 
        unit = "%" 
    },
    HP_MAX = { 
        name = "Max HP Bonus", 
        base = 500, -- Max potential flat HP bonus
        falloff = 0.99, 
        unit = "flat" 
    },
    MOVE_SPEED = { 
        name = "Movement Speed", 
        base = 50,  -- Max potential speed bonus (e.g., 50%)
        falloff = 0.98, 
        unit = "%" 
    }
    -- Add more effect types as needed (e.g., CRIT_CHANCE, HEALTH_REGEN)
}

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

    -- a. Calculate totalLevels per effect type and handle maxed nodes
    local totalLevels = {}
    for _, node in ipairs(nodes) do
        node.maxed = false -- Reset maxed status
        local effectType = node.effect
        
        if Upgrades.effectParams[effectType] then -- Only process known effect types
            totalLevels[effectType] = totalLevels[effectType] or 0
            totalLevels[effectType] = totalLevels[effectType] + node.level

            if node.level == node.maxLevel then
                node.maxed = true
                totalLevels[effectType] = totalLevels[effectType] + 3 -- Logical bonus for maxing
            end
        else
            -- print("Warning: Unknown effect type '" .. tostring(effectType) .. "' on node ID " .. tostring(node.id))
        end
    end

    -- b. Calculate final bonus values using the formula and store them
    Player.data.calculatedBonuses = {} -- Initialize/reset the storage for calculated bonuses

    for effectType, currentTotalLevel in pairs(totalLevels) do
        local params = Upgrades.effectParams[effectType]
        if params then 
            local finalValue = params.base * (1 - params.falloff ^ currentTotalLevel)
            Player.data.calculatedBonuses[effectType] = finalValue
        end
    end
    
    -- c. Remove old direct modification logic / temporary translation layer
    -- Player.data.bonusDamage = Player.data.calculatedBonuses["DMG"] / 10 -- REMOVED
    -- Player.data.bonusCooldown = Player.data.calculatedBonuses["CDR"] / 100 -- REMOVED
    
    -- Call Player.applyCalculatedBonuses() to update actual player stats
    if Player.applyCalculatedBonuses then
        Player.applyCalculatedBonuses()
    else
        print("Warning: Player.applyCalculatedBonuses function not found on Player object.")
    end
end

function Upgrades.initializeTree()
    Upgrades.nodes = {} 
    local root = {
        id = 1, 
        x = 400, y = 300, 
        level = 0, maxLevel = 10, 
        effect = "DMG", 
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
        local childEffects = {"DMG", "CDR"} 

        for i = 1, 2 do
            local angle = angleStep * i
            local newId = #Upgrades.nodes + 1
            local newNode = {
                id = newId, 
                x = actualNode.x + math.cos(angle) * 100,
                y = actualNode.y + math.sin(angle) * 100,
                level = 0, maxLevel = 10,
                effect = childEffects[i] or "DMG", 
                children = {}
            }
            Upgrades.categorizeNode(newNode) 
            table.insert(actualNode.children, newNode) 
            table.insert(Upgrades.nodes, newNode)   
        end
    end
end

function Upgrades.upgradeNode(nodeId, Player)
    local nodeToUpgrade = nil
    if nodeId >= 1 and nodeId <= #Upgrades.nodes then
        nodeToUpgrade = Upgrades.nodes[nodeId] 
    end

    if nodeToUpgrade and nodeToUpgrade.level < nodeToUpgrade.maxLevel then
        nodeToUpgrade.level = nodeToUpgrade.level + 1
        
        Upgrades.recalculatePlayerBonuses(Player, Upgrades.nodes) 
        
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
