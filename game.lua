local Game = {}
local utils = require("utils") -- Required for deepCopy in dropLoot

Game.bullets = {}
Game.shootCooldown = 0
Game.currentRealm = 1
Game.realms = {}
Game.loot = {}
Game.activeSpells = {} -- For active spell effects

-- Biome Management
Game.biomeIndex = 0
Game.currentBiomeName = "meadow"
Game.currentDropOrbColorName = "green"
Game.biomes = {
    {name="meadow", bg="assets/graphics/bg_meadow.png", orb="green"},
    {name="swamp",  bg="assets/graphics/bg_swamp.png",  orb="blue"},
    {name="snow",   bg="assets/graphics/bg_snow.png",   orb="red"},
    {name="lava",   bg="assets/graphics/bg_lava.png",   orb="violet"},
    {name="void",   bg="assets/graphics/bg_void.png",   orb="black"}
}
Game.dropOrbColors = {
    green = {0,1,0,1}, blue = {0,0,1,1}, red = {1,0,0,1},
    violet = {0.5,0,0.5,1}, black = {0.1,0.1,0.1,1},
    default_fallback = {1,1,1,0.5} -- White semi-transparent for unknown
}
Game.CHANCE_TO_DROP_ESSENCE = 0.15 -- Example: 15% chance to drop an essence orb

-- Base game mechanics values
local BASE_PROJECTILE_DAMAGE = 25
local BASE_SHOOT_COOLDOWN = 0.25
local MIN_SHOOT_COOLDOWN = 0.05 -- Minimum possible cooldown

function Game.calculateEffectiveSpellDamage(baseDamage, playerData)
    local effectiveDamage = baseDamage
    if playerData and playerData.calculatedBonuses then
        local spellDamageBonus = (playerData.calculatedBonuses.SPELL_DAMAGE or 0) / 100
        effectiveDamage = effectiveDamage * (1 + spellDamageBonus)

        local critChance = playerData.calculatedBonuses.CRIT_CHANCE or 0
        if math.random() < critChance then
            effectiveDamage = effectiveDamage * 2.0 -- 2x crit multiplier
            -- TODO: Add a flag or event for crits if visual/audio feedback is desired later
            -- print("CRIT!")
        end
    end
    return effectiveDamage
end

function Game.initializeRealms()
    Game.realms = {}
    for i = 1, 10 do -- For now, keep 10 realms for testing, can expand later
        table.insert(Game.realms, "Realm " .. i)
    end
    Game.loadBiome() -- Load initial biome
end

function Game.loadBiome()
    local newBiomeIndex = math.floor((Game.currentRealm - 1) / 10)
    Game.biomeIndex = newBiomeIndex % #Game.biomes

    local biomeData = Game.biomes[Game.biomeIndex + 1] -- Lua tables are 1-indexed
    if not biomeData then
        print("Error: Could not find biome data for biomeIndex: " .. Game.biomeIndex)
        Game.currentBiomeName = "unknown"
        Game.currentDropOrbColorName = "default_fallback"
        Assets.current_background = nil
        return
    end

    Game.currentBiomeName = biomeData.name
    Game.currentDropOrbColorName = biomeData.orb

    if Assets and love.filesystem and love.graphics then -- Ensure love modules are available
        local info = love.filesystem.getInfo(biomeData.bg)
        if info and info.type == "file" then
            local status_ok, img_or_err = pcall(love.graphics.newImage, biomeData.bg)
            if status_ok then
                Assets.current_background = img_or_err
                print("Loaded background for biome: " .. Game.currentBiomeName .. " from " .. biomeData.bg)
            else
                Assets.current_background = nil
                print("Warning: Failed to load image for biome background: " .. Game.currentBiomeName .. " at " .. biomeData.bg .. ". Error: " .. tostring(img_or_err))
            end
        else
            Assets.current_background = nil
            print("Warning: Background image not found or not a file for biome: " .. Game.currentBiomeName .. " at " .. biomeData.bg)
        end
    else
        Assets.current_background = nil
        print("Warning: Assets table, love.filesystem, or love.graphics not available for Game.loadBiome. Cannot load background.")
    end
end

function Game.getPlayerRealm()
    return Game.currentRealm
end

function Game.getLootTable()
    return Game.loot
end

function Game.getBulletsTable()
    return Game.bullets
end

function Game.getRealmsTable()
    return Game.realms
end

function Game.triggerSpellEffect(playerOriginData, spellData, targetX, targetY)
    local spellInstance = {}
    if spellData.type == "projectile" then
        local angle = math.atan2(targetY - playerOriginData.y, targetX - playerOriginData.x)
        local projectileSpeed = spellData.projectileSpeed or 400 -- Use spellData or default
        spellInstance = {
            type = "projectile",
            spellId = spellData.id,
            name = spellData.name, -- For drawing/debugging
            x = playerOriginData.x,
            y = playerOriginData.y,
            dx = math.cos(angle) * projectileSpeed,
            dy = math.sin(angle) * projectileSpeed,
            baseRadius = spellData.projectileRadius or 8, -- Store baseRadius
            radius = spellData.projectileRadius or 8,     -- Initial radius, will be updated
            rangeRemaining = spellData.calculatedRange,
            damage = spellData.calculatedDamage,
            pierceRemaining = spellData.calculatedPierce,
            aoeRadiusOnHit = spellData.calculatedAoeRadius, -- For later, if projectile explodes
            effectsToApply = spellData.effects,
            owner = playerOriginData, -- Could be just player ID or reference
            hitEnemies = {} -- Store IDs of enemies hit
        }
    elseif spellData.type == "aoe_centered" then
        if Effects and Effects.createArcaneWavePulse and spellData.id == "ArcaneWave" then
            Effects.createArcaneWavePulse(playerOriginData.x, playerOriginData.y, spellData.calculatedAoeRadius)
        end
        spellInstance = {
            type = "aoe_centered",
            spellId = spellData.id,
            name = spellData.name,
            x = playerOriginData.x,
            y = playerOriginData.y,
            radius = spellData.calculatedAoeRadius,
            damage = spellData.calculatedDamage,
            effectsToApply = spellData.effects,
            duration = 0.2, -- Short duration, processed once then removed
            alreadyHit = false,
            owner = playerOriginData
        }
    elseif spellData.type == "beam" then
        local beamAngle = math.atan2(targetY - playerOriginData.y, targetX - playerOriginData.x)
        local beamEndX = playerOriginData.x + math.cos(beamAngle) * spellData.calculatedRange
        local beamEndY = playerOriginData.y + math.sin(beamAngle) * spellData.calculatedRange

        if Effects and Effects.createVoidBeamVisual and spellData.id == "VoidBeam" then
            Effects.createVoidBeamVisual(playerOriginData.x, playerOriginData.y, beamEndX, beamEndY, spellData.calculatedAoeRadius, 0.5) -- duration 0.5 hardcoded for now
        end

        spellInstance = {
            type = "beam", -- This type might become mainly for logic, visuals handled by Effects
            spellId = spellData.id,
            name = spellData.name,
            x1 = playerOriginData.x, y1 = playerOriginData.y, -- Keep for logic if needed
            x2 = beamEndX, y2 = beamEndY,
            targetX = targetX, targetY = targetY,
            range = spellData.calculatedRange,
            width = spellData.calculatedAoeRadius,
            damage = spellData.calculatedDamage,
            effectsToApply = spellData.effects,
            duration = 0.5, -- Logical duration for the beam's effect application period
            owner = playerOriginData,
            hitEnemiesThisCast = {}
        }
    else
        print("Game.triggerSpellEffect: Unknown spell type: " .. spellData.type)
        return
    end
    table.insert(Game.activeSpells, spellInstance)
end

function Game.handleChainEffect(firstHitEnemy, originalSpellData, playerData, config_arg, utils)
    local chainParams = originalSpellData.effectsToApply and originalSpellData.effectsToApply.chain or {}
    local maxChains = chainParams.count or 0
    local chainSearchRadius = chainParams.searchRadius or 200 -- Default if not specified
    local chainDamageMultiplier = chainParams.damageMultiplier or 1.0 -- Default if not specified

    -- Calculate base damage for this chain link
    local baseChainDamage = originalSpellData.damage * chainDamageMultiplier
    -- Apply SPELL_DAMAGE and CRIT_CHANCE from playerData (which is spell.owner)
    local effectiveChainDamage = Game.calculateEffectiveSpellDamage(baseChainDamage, playerData)

    local currentChainTarget = firstHitEnemy
    local alreadyChainedTo = { [currentChainTarget] = true }
    local chainCount = 0

    -- print("Starting chain effect from enemy at: " .. currentChainTarget.x .. "," .. currentChainTarget.y)

    for c = 1, maxChains do
        local nearestNextTarget = nil
        local minDistance = chainSearchRadius

        -- Check regular enemies
        local currentEnemiesList = Enemies.getList()
        for i, potentialTarget in ipairs(currentEnemiesList) do
            if not alreadyChainedTo[potentialTarget] then
                local dist = utils.distance(currentChainTarget.x, currentChainTarget.y, potentialTarget.x, potentialTarget.y)
                if dist < minDistance then
                    minDistance = dist
                    nearestNextTarget = potentialTarget
                end
            end
        end

        -- Check boss
        local currentBoss = Enemies.getBoss()
        if currentBoss and not alreadyChainedTo[currentBoss] then
            local dist = utils.distance(currentChainTarget.x, currentChainTarget.y, currentBoss.x, currentBoss.y)
            if dist < minDistance then
                minDistance = dist
                nearestNextTarget = currentBoss
            end
        end

        if nearestNextTarget then
            chainCount = chainCount + 1
            alreadyChainedTo[nearestNextTarget] = true

            -- Add visual effect for the chain using Effects module
            if Effects and Effects.createChainBoltVisual then
                Effects.createChainBoltVisual(currentChainTarget.x, currentChainTarget.y, nearestNextTarget.x, nearestNextTarget.y)
            else
                 -- Fallback or old visual if new one isn't there
                table.insert(Game.activeSpells, {
                    type = "visual_chain_bolt", -- This type might be removed from Game.draw if fully replaced
                    x1 = currentChainTarget.x, y1 = currentChainTarget.y,
                    x2 = nearestNextTarget.x, y2 = nearestNextTarget.y,
                    duration = 0.15, color = {0.5, 0.5, 1, 0.8}
                })
            end

            -- Apply damage
            if nearestNextTarget == currentBoss then -- Check if the nearest target is the boss
                 Enemies.damageBoss(nearestNextTarget, effectiveChainDamage, -- Use effectiveChainDamage
                    function(exp) playerData.exp = playerData.exp + exp end,
                    function() playerData.kills = playerData.kills + 1 end,
                    function(lx, ly) Game.dropLoot(lx, ly, playerData) end)
            else
                -- Find index for regular enemy
                local enemyIndex = nil
                for idx, enemyInList in ipairs(currentEnemiesList) do
                    if enemyInList == nearestNextTarget then
                        enemyIndex = idx
                        break
                    end
                end
                if enemyIndex then
                    Enemies.damageEnemy(nearestNextTarget, effectiveChainDamage, enemyIndex, -- Use effectiveChainDamage
                        function(exp) playerData.exp = playerData.exp + exp end,
                        function() playerData.kills = playerData.kills + 1 end,
                        function(lx, ly) Game.dropLoot(lx, ly, playerData) end)
                end
            end
            -- print("Chain " .. chainCount .. ": Hit enemy at " .. nearestNextTarget.x .. "," .. nearestNextTarget.y)
            currentChainTarget = nearestNextTarget
        else
            -- print("Chain effect ended: No more valid targets in range.")
            break -- No more valid targets
        end
    end
end


function Game.dropLoot(x, y, playerData)
    local lootChanceMultiplier = 1.0
    if playerData and playerData.calculatedBonuses and playerData.calculatedBonuses.LOOT_MULTIPLIER then
        lootChanceMultiplier = 1 + (playerData.calculatedBonuses.LOOT_MULTIPLIER or 0)
    end

    -- Coin drop
    if math.random() < (0.5 * lootChanceMultiplier) then
        table.insert(Game.loot, {x=x,y=y, type="coin", baseRadius=8, radius=8})
    end

    -- Biome-specific Essence Orb drop
    if math.random() < (Game.CHANCE_TO_DROP_ESSENCE * lootChanceMultiplier) then
        local orb_type_id = "essence_" .. Game.currentDropOrbColorName
        if ItemsData and ItemsData[orb_type_id] then
            local itemToDrop = utils.deepCopy(ItemsData[orb_type_id])
            table.insert(Game.loot, {
                x=x, y=y, type="item_drop",
                baseRadius=8, radius=8,
                itemData = itemToDrop
            })
        else
            -- Fallback to a default essence if specific color not found
            if ItemsData and ItemsData.essence_t1 then
                 local itemToDrop = utils.deepCopy(ItemsData.essence_t1)
                 table.insert(Game.loot, {
                    x=x, y=y, type="item_drop",
                    baseRadius=8, radius=8,
                    itemData = itemToDrop,
                    visual_tint_color_name = Game.currentDropOrbColorName -- Hint for drawing
                })
                print("Warning: ItemData for '" .. orb_type_id .. "' not found. Dropping default t1 essence with color hint: " .. Game.currentDropOrbColorName)
            else
                print("Warning: ItemData for '" .. orb_type_id .. "' and fallback 'essence_t1' not found for loot drop.")
            end
        end
    end
end

local function calculateBulletDamage(bullet, playerData)
    local damageBonusPercent = (playerData.calculatedBonuses and playerData.calculatedBonuses.DMG) or 0
    return BASE_PROJECTILE_DAMAGE * (1 + damageBonusPercent / 100)
end

-- 'config_arg' here is the global 'Config' passed from main.lua
function Game.update(dt, Player, Enemies, config_arg, utils)
    Game.shootCooldown = Game.shootCooldown - dt

    local cooldownReductionPercent = (Player.data.calculatedBonuses and Player.data.calculatedBonuses.CDR) or 0
    local actualCooldown = BASE_SHOOT_COOLDOWN * (1 - cooldownReductionPercent / 100)
    actualCooldown = math.max(actualCooldown, MIN_SHOOT_COOLDOWN)

    if love.mouse.isDown(1) and Game.shootCooldown <= 0 then
        local mx, my = love.mouse.getPosition()
        local angle = math.atan2(my - Player.data.y, mx - Player.data.x)
        table.insert(Game.bullets, {
            x = Player.data.x, y = Player.data.y,
            dx = math.cos(angle) * 400,
            dy = math.sin(angle) * 400,
            baseRadius = 5, -- Store baseRadius
            radius = 5,     -- Initial radius, will be updated
            type = "normal"
        })
        Game.shootCooldown = actualCooldown
    end

    for i = #Game.bullets, 1, -1 do
        local b = Game.bullets[i]
        if b then
            -- Update dynamic radius for bullets
            b.radius = (b.baseRadius or 5) * (config_arg and config_arg.hitboxScale or 1.0) -- Use config_arg as DebugSettings

            b.x, b.y = b.x + b.dx * dt, b.y + b.dy * dt
            if b.x < 0 or b.x > config_arg.windowWidth or b.y < 0 or b.y > config_arg.windowHeight then
                table.remove(Game.bullets, i)
            end
        end
    end

    for i = #Game.bullets, 1, -1 do
        local b = Game.bullets[i]
        if not b then goto next_bullet_enemy_collision end

        -- Ensure radius is updated if not already (e.g. if created before hitboxScale was available)
        b.radius = (b.baseRadius or 5) * (config_arg and config_arg.hitboxScale or 1.0)

        local currentEnemies = Enemies.getList()
        for j = #currentEnemies, 1, -1 do
            local e = currentEnemies[j]
            if e and utils.distance(b.x, b.y, e.x, e.y) < b.radius + e.radius then
                local damage = calculateBulletDamage(b, Player.data)
                local enemyDied = Enemies.damageEnemy(e, damage, j,
                    function(exp) Player.data.exp = Player.data.exp + exp end,
                    function() Player.data.kills = Player.data.kills + 1 end,
                    function(lx, ly) Game.dropLoot(lx, ly, Player.data) end)

                table.remove(Game.bullets, i)
                goto next_bullet_enemy_collision
            end
        end
        ::next_bullet_enemy_collision::
    end

    local currentBoss = Enemies.getBoss()
    if currentBoss then
        for i = #Game.bullets, 1, -1 do
            local b = Game.bullets[i]
            if not b then goto next_bullet_boss_collision end

            if utils.distance(b.x, b.y, currentBoss.x, currentBoss.y) < b.radius + currentBoss.radius then
                local damage = calculateBulletDamage(b, Player.data)
                local bossDied = Enemies.damageBoss(damage,
                    function(exp) Player.data.exp = Player.data.exp + exp end,
                    function() Player.data.kills = Player.data.kills + 1 end,
                    function(lx, ly) Game.dropLoot(lx, ly, Player.data) end)

                table.remove(Game.bullets, i)
            end
            ::next_bullet_boss_collision::
        end
    end

    -- Player-Loot collision (specifically for coins)
    for i = #Game.loot, 1, -1 do
        local l = Game.loot[i]
        if l then
            -- Update dynamic radius for loot items
            l.radius = (l.baseRadius or 8) * (config_arg and config_arg.hitboxScale or 1.0)

            if l.type == "coin" then
                local playerRadius = (Player.data and Player.data.radius) or 10
                if utils.distance(Player.data.x, Player.data.y, l.x, l.y) < (playerRadius + l.radius) then
                    Player.data.gold = Player.data.gold + 0.1 -- Changed from 1 to 0.1
                    table.remove(Game.loot, i)
                end
            elseif l.type == "item_drop" then
                local playerRadius = (Player.data and Player.data.radius) or 10
                if utils.distance(Player.data.x, Player.data.y, l.x, l.y) < (playerRadius + l.radius) then
                    if Player.addItemToInventory then
                        if Player.addItemToInventory(l.itemData) then
                            table.remove(Game.loot, i)
                        else
                            -- Optional: print("Inventory full, cannot pick up " .. l.itemData.name)
                        end
                    else
                        print("Error: Player.addItemToInventory function not found.")
                    end
                end
            end
        end
    end

    if Player.data.exp >= Player.data.level * 100 then
        Player.data.exp = Player.data.exp - Player.data.level * 100
        Player.data.level = Player.data.level + 1
        Player.data.maxHp = Player.data.maxHp + 10
        Player.data.hp = Player.data.maxHp
        Player.data.skillPoints = (Player.data.skillPoints or 0) + 2
        Player.data.spellUpgradePoints = (Player.data.spellUpgradePoints or 0) + 2 -- Grant spell points
        if Player.recalculateBonuses then Player.recalculateBonuses() end -- Add this call
    end

    -- Update active spells
    for i = #Game.activeSpells, 1, -1 do
        local spell = Game.activeSpells[i]
        if not spell then goto next_spell_update end

        if spell.type == "projectile" then
            -- Update dynamic radius for spell projectiles
            spell.radius = (spell.baseRadius or 8) * (config_arg and config_arg.hitboxScale or 1.0)

            spell.x = spell.x + spell.dx * dt
            spell.y = spell.y + spell.dy * dt
            local distanceMoved = (spell.dx^2 + spell.dy^2)^0.5 * dt
            spell.rangeRemaining = spell.rangeRemaining - distanceMoved

            -- Add trail effects for specific projectiles
            if Effects then
                if spell.spellId == "Fireball" and Effects.createFireballTrail then
                    Effects.createFireballTrail(spell.x, spell.y)
                elseif spell.spellId == "IceLance" and Effects.createIceLanceTrail then
                    Effects.createIceLanceTrail(spell.x, spell.y)
                end
            end

            if spell.rangeRemaining <= 0 or
               spell.x < 0 or spell.x > config_arg.windowWidth or
               spell.y < 0 or spell.y > config_arg.windowHeight then
                -- Projectile expired or went off-screen
                if Effects and spell.spellId == "Fireball" and Effects.createFireballExplosion then
                    Effects.createFireballExplosion(spell.x, spell.y)
                elseif Effects and spell.spellId == "IceLance" and Effects.createIcePuff then
                    Effects.createIcePuff(spell.x, spell.y) -- Puff even if no hit
                end
                table.remove(Game.activeSpells, i)
                goto next_spell_update
            end

            -- Projectile collision with enemies
            local currentEnemies = Enemies.getList()
            for j = #currentEnemies, 1, -1 do
                local e = currentEnemies[j]
                if e and not spell.hitEnemies[e] and utils.distance(spell.x, spell.y, e.x, e.y) < spell.radius + e.radius then
                    local effectiveDamage = Game.calculateEffectiveSpellDamage(spell.damage, spell.owner)
                    Enemies.damageEnemy(e, effectiveDamage, j,
                        function(exp) spell.owner.exp = spell.owner.exp + exp end,
                        function() spell.owner.kills = spell.owner.kills + 1 end,
                        function(lx, ly) Game.dropLoot(lx, ly, spell.owner) end)

                    -- Hit Effects & Status Effects
                    if Effects then
                        if spell.spellId == "Fireball" and Effects.createFireballExplosion then
                            Effects.createFireballExplosion(spell.x, spell.y)
                        elseif spell.spellId == "IceLance" and Effects.createIcePuff then
                            Effects.createIcePuff(spell.x, spell.y)
                            if Enemies and Enemies.flash then Enemies.flash(e, {0.5, 0.8, 1, 0.4}, 0.2) end -- Tint enemy
                        end
                    end

                    if spell.effectsToApply then
                        if spell.effectsToApply.burn and spell.spellId == "Fireball" then
                            local burnEffect = spell.effectsToApply.burn
                            local burnDPS = spell.damage * burnEffect.dpsRatio
                            Enemies.applyStatusEffect(e, "burn", burnEffect.duration, burnDPS)
                        elseif spell.effectsToApply.slow and spell.spellId == "IceLance" then
                            local slowEffect = spell.effectsToApply.slow
                            Enemies.applyStatusEffect(e, "slow", slowEffect.duration, slowEffect.magnitude)
                        end

                        if spell.effectsToApply.chain and spell.spellId == "ChainBolt" then
                            Game.handleChainEffect(e, spell, spell.owner, config_arg, utils)
                            -- ChainBolt projectile is consumed upon first hit that triggers chains
                            table.remove(Game.activeSpells, i)
                            goto next_spell_update
                        end
                    end

                    spell.hitEnemies[e] = true
                    spell.pierceRemaining = spell.pierceRemaining - 1
                    if spell.pierceRemaining < 0 then
                        -- Fireball explodes even if it pierces all targets and expires
                        if Effects and spell.spellId == "Fireball" and Effects.createFireballExplosion and not (spell.effectsToApply and spell.effectsToApply.chain) then
                           -- Avoid double explosion if already exploded due to chain
                           -- Effects.createFireballExplosion(spell.x, spell.y) -- Already called above on hit
                        end
                        table.remove(Game.activeSpells, i)
                        goto next_spell_update
                    end
                end
            end

            local currentBoss = Enemies.getBoss()
            if currentBoss and not spell.hitEnemies[currentBoss] and utils.distance(spell.x, spell.y, currentBoss.x, currentBoss.y) < spell.radius + currentBoss.radius then
                 local effectiveDamage = Game.calculateEffectiveSpellDamage(spell.damage, spell.owner)
                 Enemies.damageBoss(currentBoss, effectiveDamage,
                    function(exp) spell.owner.exp = spell.owner.exp + exp end,
                    function() spell.owner.kills = spell.owner.kills + 1 end,
                    function(lx, ly) Game.dropLoot(lx, ly, spell.owner) end)

                -- Hit Effects & Status Effects for Boss
                if Effects then
                    if spell.spellId == "Fireball" and Effects.createFireballExplosion then
                        Effects.createFireballExplosion(spell.x, spell.y)
                    elseif spell.spellId == "IceLance" and Effects.createIcePuff then
                        Effects.createIcePuff(spell.x, spell.y)
                        if Enemies and Enemies.flash then Enemies.flash(currentBoss, {0.5, 0.8, 1, 0.4}, 0.2) end -- Tint boss
                    end
                end

                if spell.effectsToApply then
                    if spell.effectsToApply.burn and spell.spellId == "Fireball" then
                        local burnEffect = spell.effectsToApply.burn
                        local burnDPS = spell.damage * burnEffect.dpsRatio
                        Enemies.applyStatusEffect(currentBoss, "burn", burnEffect.duration, burnDPS)
                    elseif spell.effectsToApply.slow and spell.spellId == "IceLance" then
                        local slowEffect = spell.effectsToApply.slow
                        Enemies.applyStatusEffect(currentBoss, "slow", slowEffect.duration, slowEffect.magnitude)
                    end

                    if spell.effectsToApply.chain and spell.spellId == "ChainBolt" then
                        Game.handleChainEffect(currentBoss, spell, spell.owner, config_arg, utils)
                        table.remove(Game.activeSpells, i) -- ChainBolt projectile is consumed
                        goto next_spell_update
                    end
                end

                spell.hitEnemies[currentBoss] = true
                spell.pierceRemaining = spell.pierceRemaining - 1
                 if spell.pierceRemaining < 0 then
                    if Effects and spell.spellId == "Fireball" and Effects.createFireballExplosion and not (spell.effectsToApply and spell.effectsToApply.chain) then
                        -- Effects.createFireballExplosion(spell.x, spell.y) -- Already called on hit
                    end
                    table.remove(Game.activeSpells, i)
                    goto next_spell_update
                end
            end

        elseif spell.type == "aoe_centered" then
            if not spell.alreadyHit then
                local effectiveDamage = Game.calculateEffectiveSpellDamage(spell.damage, spell.owner)
                if spell.spellId == "ArcaneWave" and Effects and Effects.startScreenShake and Enemies and Enemies.flash then
                    Effects.startScreenShake(3, 0.1)
                end

                local allEnemies = Enemies.getList()
                for enemyIndex, e in ipairs(allEnemies) do -- ipairs for index
                    if utils.distance(spell.x, spell.y, e.x, e.y) < spell.radius + e.radius then
                         Enemies.damageEnemy(e, effectiveDamage, enemyIndex,
                            function(exp) spell.owner.exp = spell.owner.exp + exp end,
                            function() spell.owner.kills = spell.owner.kills + 1 end,
                            function(lx, ly) Game.dropLoot(lx, ly, spell.owner) end)

                        if spell.effectsToApply and spell.effectsToApply.knockback and spell.spellId == "ArcaneWave" then
                            if Enemies and Enemies.flash then Enemies.flash(e, {1,1,1,0.7}, 0.15) end
                            local knockbackEffect = spell.effectsToApply.knockback
                            local knockbackStrength = knockbackEffect.strength or 50 -- Default if not set
                            local dirX = e.x - spell.x
                            local dirY = e.y - spell.y
                            local dist = (dirX^2 + dirY^2)^0.5
                            if dist > 0 then
                                local normX = dirX / dist
                                local normY = dirY / dist
                                e.x = e.x + normX * knockbackStrength
                                e.y = e.y + normY * knockbackStrength
                                e.x = math.max(e.radius, math.min(config_arg.windowWidth - e.radius, e.x))
                                e.y = math.max(e.radius, math.min(config_arg.windowHeight - e.radius, e.y))
                            end
                        end
                    end
                end
                local currentBoss = Enemies.getBoss()
                if currentBoss and utils.distance(spell.x, spell.y, currentBoss.x, currentBoss.y) < spell.radius + currentBoss.radius then
                    Enemies.damageBoss(currentBoss, effectiveDamage,
                        function(exp) spell.owner.exp = spell.owner.exp + exp end,
                        function() spell.owner.kills = spell.owner.kills + 1 end,
                        function(lx, ly) Game.dropLoot(lx, ly, spell.owner) end)

                    if spell.effectsToApply and spell.effectsToApply.knockback and spell.spellId == "ArcaneWave" then
                        if Enemies and Enemies.flash then Enemies.flash(currentBoss, {1,1,1,0.7}, 0.15) end
                        local knockbackEffect = spell.effectsToApply.knockback
                        local knockbackStrength = knockbackEffect.strength or 50
                        local dirX = currentBoss.x - spell.x
                        local dirY = currentBoss.y - spell.y
                        local dist = (dirX^2 + dirY^2)^0.5
                        if dist > 0 then
                            local normX = dirX / dist
                            local normY = dirY / dist
                            currentBoss.x = currentBoss.x + normX * knockbackStrength
                            currentBoss.y = currentBoss.y + normY * knockbackStrength
                            currentBoss.x = math.max(currentBoss.radius, math.min(config_arg.windowWidth - currentBoss.radius, currentBoss.x))
                            currentBoss.y = math.max(currentBoss.radius, math.min(config_arg.windowHeight - currentBoss.radius, currentBoss.y))
                        end
                    end
                end
                spell.alreadyHit = true
            end
            spell.duration = spell.duration - dt
            if spell.duration <= 0 then
                table.remove(Game.activeSpells, i)
            end

        elseif spell.type == "beam" then
            if spell.spellId == "VoidBeam" then
                -- Collision detection for VoidBeam (segmented circles)
                local numSegments = 10 -- Or calculate based on length/width: math.ceil(spell.range / (spell.width * 0.5))
                local dx_segment = (spell.x2 - spell.x1) / numSegments
                local dy_segment = (spell.y2 - spell.y1) / numSegments

                for s = 0, numSegments -1 do
                    local checkX = spell.x1 + dx_segment * s + dx_segment * 0.5 -- Midpoint of segment
                    local checkY = spell.y1 + dy_segment * s + dy_segment * 0.5

                    local enemiesToCheck = Enemies.getList()
                    for _, e in ipairs(enemiesToCheck) do
                        if not spell.hitEnemiesThisCast[e] and utils.distance(checkX, checkY, e.x, e.y) < (spell.width / 2 + e.radius) then
                            if spell.effectsToApply and spell.effectsToApply.dot then
                                spell.hitEnemiesThisCast[e] = true
                                local dotEffect = spell.effectsToApply.dot
                                local effectiveDps = Game.calculateEffectiveSpellDamage(spell.damage, spell.owner)
                                local effectiveDps = Game.calculateEffectiveSpellDamage(spell.damage, spell.owner)
                                Enemies.applyStatusEffect(e, "dot", dotEffect.duration, effectiveDps)
                                if Enemies and Enemies.flash then Enemies.flash(e, {0.2, 0, 0.2, 0.4}, 0.5) end -- Dark flash for Void Beam DoT
                            end
                        end
                    end

                    local boss = Enemies.getBoss()
                    if boss and not spell.hitEnemiesThisCast[boss] and utils.distance(checkX, checkY, boss.x, boss.y) < (spell.width / 2 + boss.radius) then
                        if spell.effectsToApply and spell.effectsToApply.dot then
                            spell.hitEnemiesThisCast[boss] = true
                            local dotEffect = spell.effectsToApply.dot
                            local effectiveDps = Game.calculateEffectiveSpellDamage(spell.damage, spell.owner)
                            Enemies.applyStatusEffect(boss, "dot", dotEffect.duration, effectiveDps)
                            if Enemies and Enemies.flash then Enemies.flash(boss, {0.2, 0, 0.2, 0.4}, 0.5) end -- Dark flash for Void Beam DoT
                        end
                    end
                end
            end
            -- Common beam duration handling
            spell.duration = spell.duration - dt
            if spell.duration <= 0 then
                table.remove(Game.activeSpells, i)
            end

        elseif spell.type == "visual_chain_bolt" then
            spell.duration = spell.duration - dt
            if spell.duration <= 0 then
                table.remove(Game.activeSpells, i)
            end
        end
        ::next_spell_update::
    end
end

function Game.draw()
    -- Use DebugSettings (passed as config_arg) for scales
    local current_config = config_arg or Config -- Fallback to Config if DebugSettings somehow not passed
    if not current_config then
        print("Warning: Config/DebugSettings not available in Game.draw(). Sprite scales may be incorrect.")
        current_config = {} -- Prevent errors below
    end
    local projScale = (current_config.projectileScale) or 1
    local coinS = (current_config.coinScale) or 1
    local defaultS = (current_config.defaultSpriteScale) or 1

    -- Draw Background
    if Assets and Assets.current_background then
        local bg = Assets.current_background
        local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
        local bgW, bgH = bg:getDimensions()
        local scaleX, scaleY = screenW / bgW, screenH / bgH
        love.graphics.draw(bg, 0, 0, 0, scaleX, scaleY)
    else
        -- Draw a fallback solid color background if no image
        love.graphics.setColor(0.1,0.1,0.15,1) -- Dark grey/blue as default
        love.graphics.rectangle("fill", 0,0, love.graphics.getWidth(), love.graphics.getHeight())
        love.graphics.setColor(1,1,1,1) -- Reset color
    end

    -- Draw bullets
    if Assets and Assets.projectile_blue then
        local projectileImage = Assets.projectile_blue
        local pWidth = projectileImage:getWidth()
        local pHeight = projectileImage:getHeight()
        love.graphics.setColor(1, 1, 1)
        for _, b in ipairs(Game.bullets) do
            love.graphics.draw(projectileImage, b.x, b.y, 0, projScale, projScale, pWidth / 2, pHeight / 2)
        end
    else
        if Assets then
            print("Warning: Assets.projectile_blue is missing. Drawing circles for bullets.")
        end
        love.graphics.setColor(1, 1, 0)
        for _, b in ipairs(Game.bullets) do
            love.graphics.circle("fill", b.x, b.y, b.radius or 5)
        end
    end
    love.graphics.setColor(1, 1, 1)

    -- Draw loot
    for _, l in ipairs(Game.loot) do
        local currentLootScale = defaultS
        local lootImage = nil
        local originalColor = {love.graphics.getColor()}
        local colorToUse = nil
        local fallbackCircleColor = {1,0,1,1} -- Magenta for unknown

        if l.type == "coin" then
            currentLootScale = coinS
            lootImage = Assets.loot and Assets.loot.coin
            fallbackCircleColor = {1, 0.84, 0, 1} -- Gold
        elseif l.type == "item_drop" and l.itemData then
            lootImage = Assets.loot and Assets.loot[l.itemData.id]
            if not lootImage and l.visual_tint_color_name then -- If specific image not found but tint hint exists
                lootImage = Assets.loot and Assets.loot.essence_t1 -- Use generic t1 essence as base for tinting
                colorToUse = Game.dropOrbColors[l.visual_tint_color_name] or Game.dropOrbColors.default_fallback
                fallbackCircleColor = colorToUse
            elseif lootImage then
                 -- If specific image (e.g. essence_green) exists, use its natural color
                 -- No specific fallbackCircleColor needed here unless Assets.loot[l.itemData.id] itself is nil
                 if string.find(l.itemData.id, "essence_") then -- if it's an essence orb
                    local colorKey = string.gsub(l.itemData.id, "essence_", "")
                    fallbackCircleColor = Game.dropOrbColors[colorKey] or Game.dropOrbColors.default_fallback
                 end
            else -- No specific image and no tint hint, or itemData.id itself has no specific asset
                fallbackCircleColor = Game.dropOrbColors.default_fallback
            end
        else -- Old types or unknown
            lootImage = Assets.loot and Assets.loot[l.type] -- Should not happen often with new system
            fallbackCircleColor = Game.dropOrbColors.default_fallback
        end

        if colorToUse then love.graphics.setColor(unpack(colorToUse)) end

        if lootImage then
            local lWidth = lootImage:getWidth()
            local lHeight = lootImage:getHeight()
            love.graphics.draw(lootImage, l.x, l.y, 0, currentLootScale, currentLootScale, lWidth / 2, lHeight / 2)
        else
            if Assets and Assets.loot then
                 print("Info: No sprite for loot type: " .. (l.type or "unknown") .. (l.itemData and (" (" .. l.itemData.id .. ")") or "") .. ". Drawing fallback circle with inferred color.")
            end
            if not colorToUse then love.graphics.setColor(unpack(fallbackCircleColor)) end -- Set fallback color only if no tint applied
            love.graphics.circle("fill", l.x, l.y, l.radius or 5)
        end
        love.graphics.setColor(unpack(originalColor)) -- Reset color to what it was before this loot item
    end
    love.graphics.setColor(1, 1, 1) -- Final safety reset after all loot

    -- Draw active spells (basic placeholders, to be replaced by Effects.draw)
    -- For projectiles, we might still draw a core, or let Effects handle everything.
    -- For now, let's comment out most of this, assuming Effects.draw() will take over.
    --[[
    for _, spell in ipairs(Game.activeSpells) do
        if spell.type == "projectile" then
            -- love.graphics.setColor(1, 0, 0, 0.8) -- Red for projectiles
            -- love.graphics.circle("fill", spell.x, spell.y, spell.radius or 5)
        elseif spell.type == "aoe_centered" then
            -- This is now handled by Effects.createArcaneWavePulse
            -- if spell.duration > 0.1 then
            --      love.graphics.setColor(0, 0, 1, 0.5)
            --      love.graphics.circle("fill", spell.x, spell.y, spell.radius * ( (0.2 - spell.duration) / 0.2) )
            -- end
        elseif spell.type == "visual_chain_bolt" then
            -- This is now handled by Effects.createChainBoltVisual
            -- local r,g,b,a = unpack(spell.color or {0.5,0.5,1,0.8})
            -- love.graphics.setColor(r,g,b,a * (spell.duration / 0.15)) -- Fade out
            -- love.graphics.setLineWidth(3)
            -- love.graphics.line(spell.x1, spell.y1, spell.x2, spell.y2)
            -- love.graphics.setLineWidth(1)
        elseif spell.type == "beam" then
            -- This is now handled by Effects.createVoidBeamVisual
            -- love.graphics.setColor(0.5, 0, 0.5, 0.7) -- Purple for beams
            -- love.graphics.setLineWidth(spell.width or 10)
            -- love.graphics.line(spell.x1, spell.y1, spell.x2, spell.y2)
            -- love.graphics.setLineWidth(1)
        end
    end
    --]]
    love.graphics.setColor(1, 1, 1) -- Reset color
end

function Game.resetForNewRealm(Player, Enemies)
    Enemies.reset()
    Game.bullets = {}
    if Player and Player.data then
        Player.data.kills = 0
    end
    Game.loot = {}
    Game.activeSpells = {} -- Clear active spells on realm change
end

function Game.changeRealm(delta, Player, Enemies)
    Game.currentRealm = math.max(1, Game.currentRealm + delta)
    Game.resetForNewRealm(Player, Enemies)
    Game.loadBiome() -- Load new biome assets and settings
    if Player.recalculateBonuses then Player.recalculateBonuses() end
end

return Game
