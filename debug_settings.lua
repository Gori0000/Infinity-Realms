local Config = require("config")

local DebugSettings = {}

-- Shallow copy initial values from Config
-- This ensures that if Config has tables, DebugSettings gets references to them,
-- which might be okay for simple config values but could be an issue if Config's tables are modified by other parts of the game.
-- However, Config is typically read-only after load.
if Config then
    for k, v in pairs(Config) do
        DebugSettings[k] = v
    end
else
    print("CRITICAL ERROR: config.lua not found or returned nil. DebugSettings cannot be initialized from Config.")
    -- Initialize with some very basic fallbacks if Config is missing
    DebugSettings.windowWidth = 1920
    DebugSettings.windowHeight = 1080
    DebugSettings.playerScale = 0.5
    DebugSettings.enemyScale = 0.25
    DebugSettings.projectileScale = 0.35
    DebugSettings.coinScale = 0.5
    DebugSettings.defaultSpriteScale = 0.5
    DebugSettings.uiScaleFactor = 3
    DebugSettings.baseFontSize = 14
end

-- Add new debug-specific settings with defaults
DebugSettings.hitboxScale = 1.0 -- Global multiplier for collision radii
-- Example: DebugSettings.showHitboxes = true (if we add a toggle later)

-- Store original defaults separately for a potential "Reset to Defaults" button
DebugSettings.originalDefaults = {}
if Config then
    for k, v in pairs(Config) do
        DebugSettings.originalDefaults[k] = v -- Store a copy of original config values
    end
else
    -- Populate originalDefaults with the same fallbacks if Config was missing
    DebugSettings.originalDefaults.windowWidth = 1920
    DebugSettings.originalDefaults.windowHeight = 1080
    DebugSettings.originalDefaults.playerScale = 0.5
    DebugSettings.originalDefaults.enemyScale = 0.25
    DebugSettings.originalDefaults.projectileScale = 0.35
    DebugSettings.originalDefaults.coinScale = 0.5
    DebugSettings.originalDefaults.defaultSpriteScale = 0.5
    DebugSettings.originalDefaults.uiScaleFactor = 3
    DebugSettings.originalDefaults.baseFontSize = 14
end
DebugSettings.originalDefaults.hitboxScale = 1.0 -- Also store default for new settings

return DebugSettings
