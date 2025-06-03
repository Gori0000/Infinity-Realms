local Upgrades = {}
local utils = require("utils") -- Required for distance calculation

Upgrades.effectParams = {
    DMG = {
        name = "Damage Bonus",
        base = 100,
        falloff = 0.98,
        unit = "%"
    },
    CDR = {
        name = "Cooldown Reduction",
        base = 50,
        falloff = 0.97,
        unit = "%"
    },
    HP_MAX = {
        name = "Max HP Bonus",
        base = 500,
        falloff = 0.99,
        unit = "flat"
    },
    MOVE_SPEED = {
        name = "Movement Speed",
        base = 50,
        falloff = 0.98,
        unit = "%"
    }
}

Upgrades.nodes = {}

function Upgrades.categorizeNode(node)
    -- This function is primarily for nodes whose category isn't set by inheritance.
    -- Or, it could be a fallback if a parent node somehow has no category.
    if not node.category then -- Only categorize if not already set (e.g. by inheritance)
        if node.id % 3 == 1 then node.category = "Offense"
        elseif node.id % 3 == 2 then node.category = "Defense"
        else node.category = "Support" end
    end
end

function Upgrades.recalculatePlayerBonuses(Player, nodes)
    if not Player or not Player.data then
        print("Warning: Player data not available for recalculatePlayerBonuses.")
        return
    end

    local totalLevels = {}
    for _, node in ipairs(nodes) do
        node.maxed = false
        local effectType = node.effect

        if Upgrades.effectParams[effectType] then
            totalLevels[effectType] = totalLevels[effectType] or 0
            totalLevels[effectType] = totalLevels[effectType] + node.level

            if node.level == node.maxLevel then
                node.maxed = true
                totalLevels[effectType] = totalLevels[effectType] + 3
            end
        end
    end

    Player.data.calculatedBonuses = {}

    for effectType, currentTotalLevel in pairs(totalLevels) do
        local params = Upgrades.effectParams[effectType]
        if params then
            local finalValue = params.base * (1 - params.falloff ^ currentTotalLevel)
            Player.data.calculatedBonuses[effectType] = finalValue
        end
    end

    if Player.applyCalculatedBonuses then
        Player.applyCalculatedBonuses()
    else
        print("Warning: Player.applyCalculatedBonuses function not found on Player object.")
    end
end

function Upgrades.initializeTree()
    Upgrades.nodes = {}
    local centerX = (Config and Config.windowWidth or 1920) / 2
    local centerY = (Config and Config.windowHeight or 1080) / 2
    local initialNodeYOffset = 200
    local initialNodeXOffset = 250
    local supportNodeYDisplacement = 200

    local offenseNode = {
        id = 1, x = centerX - initialNodeXOffset, y = centerY - initialNodeYOffset,
        level = 0, maxLevel = 10, effect = "DMG", category = "Offense",
        children = {}, maxed = false
    }
    local defenseNode = {
        id = 2, x = centerX + initialNodeXOffset, y = centerY - initialNodeYOffset,
        level = 0, maxLevel = 10, effect = "HP_MAX", category = "Defense",
        children = {}, maxed = false
    }
    local supportNode = {
        id = 3, x = centerX, y = centerY - initialNodeYOffset + supportNodeYDisplacement,
        level = 0, maxLevel = 10, effect = "CDR", category = "Support",
        children = {}, maxed = false
    }
    table.insert(Upgrades.nodes, offenseNode)
    table.insert(Upgrades.nodes, defenseNode)
    table.insert(Upgrades.nodes, supportNode)
end

function Upgrades.expandTree(nodeToExpand) -- nodeToExpand is the parent node object
    if not nodeToExpand then print("Error: expandTree called with nil nodeToExpand."); return end

    print("Attempting to expand node ID:", nodeToExpand.id, "Category:", nodeToExpand.category, "at (", nodeToExpand.x, ",", nodeToExpand.y, ")")

    local parentNode = nodeToExpand
    local distance = 100
    local targetX, targetY

    if parentNode.category == "Offense" then
        targetX, targetY = parentNode.x + distance, parentNode.y
    elseif parentNode.category == "Defense" then
        targetX, targetY = parentNode.x - distance, parentNode.y
    elseif parentNode.category == "Support" then
        targetX, targetY = parentNode.x, parentNode.y + distance
    else
        targetX, targetY = parentNode.x + distance, parentNode.y
        print("  Warning: Node " .. parentNode.id .. " has undefined category '" .. tostring(parentNode.category) .. "'. Defaulting expansion direction (right).")
    end
    print("  Targeting new child at (", targetX, ",", targetY, ")")

    local collisionDetected = false
    local nodeVisualRadius = 15
    local minSpacing = (nodeVisualRadius * 2) + 15 -- Diameter + 15px buffer (total 45)

    for _, existingNode in ipairs(Upgrades.nodes) do
        if existingNode.id == parentNode.id then goto continue_check end -- Don't check collision with self

        if utils.distance(targetX, targetY, existingNode.x, existingNode.y) < minSpacing then
            collisionDetected = true
            print("  Collision DETECTED with existing node ID:", existingNode.id, "at (", existingNode.x, ",", existingNode.y, "). Distance:", utils.distance(targetX, targetY, existingNode.x, existingNode.y), "MinSpacing:", minSpacing)
            break
        end
        ::continue_check::
    end

    if not collisionDetected then
        local newId = #Upgrades.nodes + 1

        local availableEffects = {}
        for key, _ in pairs(Upgrades.effectParams) do
            table.insert(availableEffects, key)
        end
        local effectKey = availableEffects[math.random(#availableEffects)]

        local newNode = {
            id = newId,
            x = targetX,
            y = targetY,
            level = 0,
            maxLevel = 10,
            effect = effectKey,
            category = parentNode.category, -- Child inherits parent's category
            children = {},
            maxed = false
        }
        -- Upgrades.categorizeNode(newNode) -- No longer needed here due to inheritance

        table.insert(parentNode.children, newNode)
        table.insert(Upgrades.nodes, newNode)

        print("  Expansion SUCCEEDED for node ID:", parentNode.id, ". New child ID:", newNode.id, "Category:", newNode.category, "Effect:", newNode.effect)
    else
         print("  Expansion SKIPPED for node ID:", parentNode.id, "due to collision.")
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
            if #nodeToUpgrade.children == 0 then
                 Upgrades.expandTree(nodeToUpgrade)
            end
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
