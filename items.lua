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
    }
    -- Equipment items like { id="basic_staff", name="Basic Staff", type="weapon", slot="main_hand", damage=5, range_bonus=50, icon="path/to/staff.png"},
    -- Consumables like { id="health_potion", name="Health Potion", type="consumable", effect="heal", amount=50, icon="path/to/potion.png"}
}
return ItemsData
