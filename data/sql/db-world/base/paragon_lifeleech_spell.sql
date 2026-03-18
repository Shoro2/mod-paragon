-- Paragon Life Leech passive aura (spell_dbc ID 100027)
-- Server-side only spell: passive, hidden, stackable dummy aura
-- Used by mod-paragon to track Life Leech stat (each stack = 0.1% lifesteal)

DELETE FROM `spell_dbc` WHERE `ID` = 100027;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectAura_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `Name_Lang_enUS`)
VALUES (100027,
    320,   -- 0x140: SPELL_ATTR0_PASSIVE (0x40) + SPELL_ATTR0_HIDDEN_CLIENTSIDE (0x100)
    1024,  -- SPELL_ATTR1_NOT_BREAK_STEALTH
    0,     -- AttributesEx2
    268435456, -- SPELL_ATTR3_DEATH_PERSISTENT (0x10000000) - persists through death
    21,    -- DurationIndex 21 = infinite (-1)
    1,     -- RangeIndex 1 = self (0 yards)
    255,   -- CumulativeAura = max 255 stacks
    1,     -- CastingTimeIndex 1 = instant
    6,     -- Effect_1 = SPELL_EFFECT_APPLY_AURA
    4,     -- EffectAura_1 = SPELL_AURA_DUMMY
    1,     -- ImplicitTargetA_1 = TARGET_UNIT_CASTER
    1,     -- SchoolMask = SPELL_SCHOOL_MASK_NORMAL
    'Paragon Life Leech');
