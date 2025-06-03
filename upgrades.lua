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
    if node.id % 3 == 1 then node.category = "Offense"
    elseif node.id % 3 == 2 then node.category = "Defense"
    else node.category = "Support" end
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
    local parentNode = nil
    if type(nodeToExpand) == "number" then -- If an ID was passed
        for _, n in ipairs(Upgrades.nodes) do
            if n.id == nodeToExpand then
                parentNode = n
                break
            end
        end
    else -- Assume it's the node object itself
        parentNode = nodeToExpand
    end

    if not parentNode then
        print("Error: Parent node for expansion not found with: ", nodeToExpand)
        return
    end

    -- Only expand if the node doesn't already have children from this new logic
    -- The old logic created 2 children. This new logic creates 1 if space.
    -- We might need a flag on the node like `expandedWithNewLogic = true` or check child count.
    -- For now, let's assume if #parentNode.children == 0, it can be expanded.
    -- Or, more robustly, allow expansion only once when it's maxed.
    -- The call to expandTree is already inside `if nodeToUpgrade.level == nodeToUpgrade.maxLevel then`
    -- so this function is called only when a node is maxed.
    -- We should ensure it only adds *one* child as per the new design, or if it could be called multiple times,
    -- ensure it doesn't keep adding.
    -- Let's assume it tries to add one child and if that spot is taken, it does nothing more *in this call*.

    local distance = 100
    local targetX, targetY

    if parentNode.category == "Offense" then
        targetX, targetY = parentNode.x + distance, parentNode.y
    elseif parentNode.category == "Defense" then
        targetX, targetY = parentNode.x - distance, parentNode.y
    elseif parentNode.category == "Support" then
        targetX, targetY = parentNode.x, parentNode.y + distance
    else -- Default fallback (e.g., if category is nil)
        targetX, targetY = parentNode.x + distance, parentNode.y
        print("Warning: Node " .. parentNode.id .. " has undefined category. Defaulting expansion direction.")
    end

    local collisionDetected = false
    local nodeVisualRadius = 15 -- As drawn in UI
    local minSpacing = (nodeVisualRadius * 2) + 10 -- Diameter + buffer

    for _, existingNode in ipairs(Upgrades.nodes) do
        if utils.distance(targetX, targetY, existingNode.x, existingNode.y) < minSpacing then
            collisionDetected = true
            print("Collision detected at:", targetX, targetY, "for new child of node:", parentNode.id, ". Tried to expand from category:", parentNode.category)
            break
        end
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
            children = {}
        }

        Upgrades.categorizeNode(newNode) -- Assign category based on ID

        table.insert(parentNode.children, newNode) -- Store the actual node object
        table.insert(Upgrades.nodes, newNode)

        print("Expanded node", parentNode.id, "(category: "..parentNode.category..") to new node", newNode.id, "at", newNode.x, newNode.y, "with effect", newNode.effect, "and category", newNode.category)
    else
         print("Expansion skipped for node", parentNode.id, "due to collision at target:", targetX, targetY)
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
            -- Only attempt to expand if it hasn't been expanded before with the new logic.
            -- Check children count: if 0, try to expand. If already has children, don't.
            -- This assumes the new logic only adds one child at a time.
            -- If the old logic (2 children) ran, #children would be 2.
            -- If this new logic ran once, #children would be 1.
            -- To prevent re-running and adding more children if it fails once due to collision:
            -- A better way would be a flag on the node: `node.expansionAttempted = true`
            -- For now, let's assume that if a maxed node has 0 children, it's eligible for this new expansion.
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
