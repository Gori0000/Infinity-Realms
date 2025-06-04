-- items.lua
local ItemsData = {
    essence_t1 = {
        id = "essence_t1",
        name = "Tier 1 Essence",
        description = "A common magical essence.",
        icon = "assets/graphics/essence_green.png", -- Path to the icon
        type = "essence", -- General item type
        stackable = true,
        maxStack = 99
    },
    essence_t2 = {
        id = "essence_t2",
        name = "Tier 2 Essence",
        description = "A potent magical essence.",
        icon = "assets/graphics/essence_blue.png", -- Path to the icon
        type = "essence",
        stackable = true,
        maxStack = 99
    },
    basic_wand = {
        id = "basic_wand",
        name = "Basic Wand",
        type = "gear",
        slot = "wand",
        effects = { SPELL_DAMAGE = 5, CRIT_CHANCE = 0.02 },
        icon = "assets/graphics/icon_wand.png",
        description = "A simple wand that slightly boosts spell power."
    },
    basic_robe = {
        id = "basic_robe",
        name = "Basic Robe",
        type = "gear",
        slot = "robe",
        effects = { HP_MAX = 10 },
        icon = "assets/graphics/icon_robe.png",
        description = "A simple robe that slightly increases maximum health."
    },
    basic_hat = {
        id = "basic_hat",
        name = "Basic Hat",
        type = "gear",
        slot = "hat",
        effects = { CDR = 5 }, -- Changed to CDR and value to 5 (for 5%)
        icon = "assets/graphics/icon_hat.png",
        description = "A simple hat that slightly reduces spell cooldowns."
    },
    basic_boots = {
        id = "basic_boots",
        name = "Basic Boots",
        type = "gear",
        slot = "boots",
        effects = { MOVE_SPEED = 5 },
        icon = "assets/graphics/icon_boots.png",
        description = "Simple boots that slightly increase movement speed."
    },
    basic_charm = {
        id = "basic_charm",
        name = "Basic Charm",
        type = "gear",
        slot = "charm",
        effects = { LOOT_MULTIPLIER = 0.1 },
        icon = "assets/graphics/icon_charm.png",
        description = "A simple charm that slightly increases loot drops."
    },
    essence_green = {
        id = "essence_green",
        name = "Green Essence",
        description = "Essence from the meadows.",
        icon = "assets/graphics/essence_green.png",
        type = "essence",
        stackable = true, maxStack = 99
    },
    essence_blue = {
        id = "essence_blue",
        name = "Blue Essence",
        description = "Essence from the swamps.",
        icon = "assets/graphics/essence_blue.png",
        type = "essence",
        stackable = true, maxStack = 99
    },
    essence_red = {
        id = "essence_red",
        name = "Red Essence",
        description = "Essence from snowy plains.", -- Or lava, adjust as per biome description
        icon = "assets/graphics/essence_red.png",
        type = "essence",
        stackable = true, maxStack = 99
    },
    essence_violet = {
        id = "essence_violet",
        name = "Violet Essence",
        description = "Essence from lava caverns.", -- Or void
        icon = "assets/graphics/essence_violet.png",
        type = "essence",
        stackable = true, maxStack = 99
    },
    essence_black = {
        id = "essence_black",
        name = "Black Essence",
        description = "Essence from the void.",
        icon = "assets/graphics/essence_black.png",
        type = "essence",
        stackable = true, maxStack = 99
    }
    -- Equipment items like { id="basic_staff", name="Basic Staff", type="weapon", slot="main_hand", damage=5, range_bonus=50, icon="path/to/staff.png"},
    -- Consumables like { id="health_potion", name="Health Potion", type="consumable", effect="heal", amount=50, icon="path/to/potion.png"}
}
return ItemsData
