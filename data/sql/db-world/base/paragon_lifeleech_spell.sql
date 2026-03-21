-- Paragon Life Leech passive aura (spell_dbc ID 100027)
-- Server-side only spell: hidden, stackable dummy aura
-- Used by mod-paragon to track Life Leech stat (each stack = 0.1% lifesteal)
-- Healing logic is in C++ (ParagonLifeLeech::OnDamage), not in the spell itself.
--
-- Attribute flags match the working Paragon stat spells from Spell.dbc:
--   AttributesEx3: DEATH_PERSISTENT + HIDE_IN_COMBAT_LOG + STACK_FOR_DIFF_CASTERS
--   AttributesEx4: NOT_STEALABLE (prevents Spellsteal from removing the aura)
--   AttributesEx5: USABLE_WHILE_FEARED + USABLE_WHILE_CONFUSED (aura persists through CC)

DELETE FROM `spell_dbc` WHERE `ID` = 100027;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`,
    `AttributesEx4`, `AttributesEx5`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectAura_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `Name_Lang_enUS`)
VALUES (100027,
    256,       -- 0x100: SPELL_ATTR0_HIDDEN_CLIENTSIDE (no PASSIVE — aura is manually applied)
    1024,      -- 0x400: SPELL_ATTR1_NOT_BREAK_STEALTH
    0,         -- AttributesEx2
    402653312, -- 0x18000000: DEATH_PERSISTENT (0x10000000) + HIDE_IN_COMBAT_LOG (0x08000000)
    1024,      -- 0x400: SPELL_ATTR4_NOT_STEALABLE
    540672,    -- 0x84000: USABLE_WHILE_FEARED (0x4000) + USABLE_WHILE_CONFUSED (0x80000)
    21,        -- DurationIndex 21 = infinite (-1)
    1,         -- RangeIndex 1 = self (0 yards)
    255,       -- CumulativeAura = max 255 stacks
    1,         -- CastingTimeIndex 1 = instant
    6,         -- Effect_1 = SPELL_EFFECT_APPLY_AURA
    4,         -- EffectAura_1 = SPELL_AURA_DUMMY
    1,         -- ImplicitTargetA_1 = TARGET_UNIT_CASTER
    1,         -- SchoolMask = SPELL_SCHOOL_MASK_NORMAL
    'Paragon Life Leech');
