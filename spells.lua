return {
  Fireball = {
    name = "Fireball",
    icon = "assets/graphics/spell_fireball.png",
    baseDamage = 20,
    cooldown = 2.0,
    range = 500,
    aoeRadius = 64, -- This is if the projectile itself explodes, not the burn AoE
    pierce = 0,
    effects = {
      burn = {
        duration = 3,
        dpsRatio = 0.25,
        description = "Applies a burn dealing 25% of impact damage per second for 3 seconds."
      }
    },
    type = "projectile"
  },
  IceLance = {
    name = "Ice Lance",
    icon = "assets/graphics/spell_icelance.png",
    baseDamage = 14,
    cooldown = 1.4,
    range = 600,
    aoeRadius = 0,
    pierce = 2,
    effects = {
      slow = {
        duration = 2,
        magnitude = 0.4,
        description = "Slows target by 40% for 2 seconds."
      }
    },
    type = "projectile"
  },
  ChainBolt = {
    name = "Chain Bolt",
    icon = "assets/graphics/spell_chainbolt.png",
    baseDamage = 10,
    cooldown = 2.5,
    range = 300,         -- Initial range for first target or general spell property
    aoeRadius = 0,
    pierce = 0,          -- Original projectile does not pierce; chains are new events
    effects = {
      chain = {
        count = 4,
        searchRadius = 200,
        damageMultiplier = 0.75,
        description = "Chains to up to 4 nearby enemies, each hit dealing 75% of original damage."
      }
    },
    type = "projectile"
  },
  ArcaneWave = {
    name = "Arcane Wave",
    icon = "assets/graphics/spell_wave.png",
    baseDamage = 12,
    cooldown = 3.0,
    range = 0,           -- It's centered on player, range is its AoE radius
    aoeRadius = 160,     -- This is the primary radius of the wave
    pierce = 0,          -- AoE typically hits all in range, pierce not applicable
    effects = {
      knockback = {
        strength = 50,
        description = "Pushes hit enemies outward from the center of the wave."
      }
    },
    type = "aoe_centered"
  },
  VoidBeam = {
    name = "Void Beam",
    icon = "assets/graphics/spell_voidbeam.png",
    baseDamage = 8,      -- This will be used as DPS for the DoT
    cooldown = 0.1,      -- Very low cooldown suggests channeled or rapid-fire application
    range = 600,
    aoeRadius = 48,      -- This is used as the beam width
    pierce = 999,        -- Beam pierces all targets, DoT applied once per cast
    effects = {
      dot = {
        duration = 5,
        description = "Applies a Damage over Time effect using spell damage as DPS for 5 seconds to enemies touched by the beam."
      }
    },
    type = "beam"
  }
}
