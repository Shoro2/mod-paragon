-- Paragon Big Stat Spells (spell_dbc)
--
-- Each Paragon stat spell gives a fixed amount per aura stack, but WoW 3.3.5
-- client aura stacks are capped at uint8 (255).  To support allocations above
-- 255 points we create "big" versions that give 100x the value per stack.
--
-- The server applies:
--   big_stacks  = allocatedPoints / 100
--   small_stacks = allocatedPoints % 100
--
-- Example for 666 Strength (original value = 5/stack):
--   big_stacks = 6  (6 * 500 = 3000)
--   small_stacks = 66 (66 * 5 = 330)
--   Total = 3330 Strength
--
-- ID scheme: original + 200   (100001 -> 100201, 100027 -> 100227)
--
-- Shared attributes (match existing Paragon stat spells):
--   Attributes:    0xA98000C0  (hidden, no target, etc.)
--   AttributesEx:  0x00000420  (NOT_BREAK_STEALTH, CHANNELED_2)
--   AttributesEx2: 0x10084000  (CANT_CRIT + ...)
--   AttributesEx3: 0x00130000  (DEATH_PERSISTENT + HIDE_IN_COMBAT_LOG + STACK_FOR_DIFF_CASTERS)
--   DurationIndex:  21 = infinite
--   RangeIndex:      1 = self
--   CastingTimeIndex: 1 = instant
--   CumulativeAura: 255 = max stacks
--   Effect:          6 = SPELL_EFFECT_APPLY_AURA
--   ImplicitTargetA: 1 = TARGET_UNIT_CASTER
--   SchoolMask:      1 = SPELL_SCHOOL_MASK_NORMAL
--
-- Note: EffectBasePoints = (desired_value - 1) because DieSides = 1,
--       so actual value = BasePoints + irand(1, DieSides) = (val-1) + 1 = val.
--       For 100x multiplier: BigBasePoints = (original_value * 100) - 1.

-- ───────────────────────────────────────────────
-- Primary Stats (SPELL_AURA_MOD_STAT = 29)
-- Original value: 5/stack → Big value: 500/stack
-- ───────────────────────────────────────────────

-- 100201: Big Strength (MiscValue 0 = STAT_STRENGTH)
DELETE FROM `spell_dbc` WHERE `ID` = 100201;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`, `SchoolMask`, `Name_Lang_enUS`)
VALUES (100201,
    0xA98000C0, 0x00000420, 0x10084000, 0x00130000,
    21, 1, 255, 1,
    6, 1, 499, 29,
    0, 1, 1, 'Paragon Strength (x100)');

-- 100202: Big Intellect (MiscValue 3 = STAT_INTELLECT)
DELETE FROM `spell_dbc` WHERE `ID` = 100202;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`, `SchoolMask`, `Name_Lang_enUS`)
VALUES (100202,
    0xA98000C0, 0x00000420, 0x10084000, 0x00130000,
    21, 1, 255, 1,
    6, 1, 499, 29,
    3, 1, 1, 'Paragon Intellect (x100)');

-- 100203: Big Agility (MiscValue 1 = STAT_AGILITY)
DELETE FROM `spell_dbc` WHERE `ID` = 100203;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`, `SchoolMask`, `Name_Lang_enUS`)
VALUES (100203,
    0xA98000C0, 0x00000420, 0x10084000, 0x00130000,
    21, 1, 255, 1,
    6, 1, 499, 29,
    1, 1, 1, 'Paragon Agility (x100)');

-- 100204: Big Spirit (MiscValue 4 = STAT_SPIRIT)
DELETE FROM `spell_dbc` WHERE `ID` = 100204;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`, `SchoolMask`, `Name_Lang_enUS`)
VALUES (100204,
    0xA98000C0, 0x00000420, 0x10084000, 0x00130000,
    21, 1, 255, 1,
    6, 1, 499, 29,
    4, 1, 1, 'Paragon Spirit (x100)');

-- 100205: Big Stamina (MiscValue 2 = STAT_STAMINA)
-- Note: Original spell has slightly different Attributes (0xA9800000),
-- but we use the common pattern for consistency.
DELETE FROM `spell_dbc` WHERE `ID` = 100205;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`, `SchoolMask`, `Name_Lang_enUS`)
VALUES (100205,
    0xA98000C0, 0x00000420, 0x10084000, 0x00130000,
    21, 1, 255, 1,
    6, 1, 499, 29,
    2, 1, 1, 'Paragon Stamina (x100)');

-- ───────────────────────────────────────────────
-- Offensive Stats (SPELL_AURA_MOD_RATING = 189)
-- ───────────────────────────────────────────────

-- 100216: Big Haste (original: 5/stack → big: 500/stack)
-- MiscValue 917504 = CR_HASTE_MELEE|CR_HASTE_RANGED|CR_HASTE_SPELL
DELETE FROM `spell_dbc` WHERE `ID` = 100216;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`, `SchoolMask`, `Name_Lang_enUS`)
VALUES (100216,
    0xA98000C0, 0x00000420, 0x10084000, 0x00130000,
    21, 1, 255, 1,
    6, 1, 499, 189,
    917504, 1, 1, 'Paragon Haste (x100)');

-- 100217: Big Armor Penetration (original: 5/stack → big: 500/stack)
-- MiscValue 16777216 = CR_ARMOR_PENETRATION
DELETE FROM `spell_dbc` WHERE `ID` = 100217;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`, `SchoolMask`, `Name_Lang_enUS`)
VALUES (100217,
    0xA98000C0, 0x00000420, 0x10084000, 0x00130000,
    21, 1, 255, 1,
    6, 1, 499, 189,
    16777216, 1, 1, 'Paragon Armor Pen (x100)');

-- 100218: Big Spell Power (original: 10/stack → big: 1000/stack)
-- TWO effects: MOD_DAMAGE_DONE (13) + MOD_HEALING_DONE (135)
-- MiscValue 126 = all spell schools
DELETE FROM `spell_dbc` WHERE `ID` = 100218;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`,
    `Effect_2`, `EffectDieSides_2`, `EffectBasePoints_2`, `EffectAura_2`,
    `EffectMiscValue_2`, `ImplicitTargetA_2`,
    `SchoolMask`, `Name_Lang_enUS`)
VALUES (100218,
    0xA98000C0, 0x00000420, 0x10084000, 0x00130000,
    21, 1, 255, 1,
    6, 1, 999, 13,
    126, 1,
    6, 1, 999, 135,
    126, 1,
    1, 'Paragon Spell Power (x100)');

-- 100219: Big Crit (original: 10/stack → big: 1000/stack)
-- MiscValue 1792 = CR_CRIT_MELEE|CR_CRIT_RANGED|CR_CRIT_SPELL
DELETE FROM `spell_dbc` WHERE `ID` = 100219;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`, `SchoolMask`, `Name_Lang_enUS`)
VALUES (100219,
    0xA98000C0, 0x00000420, 0x10084000, 0x00130000,
    21, 1, 255, 1,
    6, 1, 999, 189,
    1792, 1, 1, 'Paragon Crit (x100)');

-- 100220: Big Mount Speed (original: 1/stack → big: 100/stack)
-- TWO effects: SPELL_AURA_MOD_INCREASE_SPEED (31) + Effect 58 (mounted speed)
DELETE FROM `spell_dbc` WHERE `ID` = 100220;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`,
    `ImplicitTargetA_1`,
    `Effect_2`, `EffectDieSides_2`, `EffectBasePoints_2`, `EffectAura_2`,
    `ImplicitTargetA_2`,
    `SchoolMask`, `Name_Lang_enUS`)
VALUES (100220,
    0xA98000C0, 0x00000420, 0x10084000, 0x00130000,
    21, 1, 255, 1,
    6, 1, 99, 31,
    1,
    6, 1, 99, 58,
    1,
    1, 'Paragon Mount Speed (x100)');

-- 100221: Big Mana Regen (original: 5/stack → big: 500/stack)
-- SPELL_AURA_MOD_POWER_REGEN = 85
DELETE FROM `spell_dbc` WHERE `ID` = 100221;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`,
    `ImplicitTargetA_1`, `SchoolMask`, `Name_Lang_enUS`)
VALUES (100221,
    0xA98000C0, 0x00000420, 0x10084000, 0x00130000,
    21, 1, 255, 1,
    6, 1, 499, 85,
    1, 1, 'Paragon Mana Regen (x100)');

-- 100222: Big Hit Rating (original: 10/stack → big: 1000/stack)
-- MiscValue 224 = CR_HIT_MELEE|CR_HIT_RANGED|CR_HIT_SPELL
DELETE FROM `spell_dbc` WHERE `ID` = 100222;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`, `SchoolMask`, `Name_Lang_enUS`)
VALUES (100222,
    0xA98000C0, 0x00000420, 0x10084000, 0x00130000,
    21, 1, 255, 1,
    6, 1, 999, 189,
    224, 1, 1, 'Paragon Hit Rating (x100)');

-- ───────────────────────────────────────────────
-- Defensive Stats
-- ───────────────────────────────────────────────

-- 100223: Big Block (original: 4/stack → big: 400/stack)
-- MiscValue 16 = CR_BLOCK
DELETE FROM `spell_dbc` WHERE `ID` = 100223;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`, `SchoolMask`, `Name_Lang_enUS`)
VALUES (100223,
    0xA98000C0, 0x00000420, 0x10084000, 0x00130000,
    21, 1, 255, 1,
    6, 1, 399, 189,
    16, 1, 1, 'Paragon Block (x100)');

-- 100224: Big Expertise (original: 3/stack → big: 300/stack)
-- MiscValue 8388608 = CR_EXPERTISE
DELETE FROM `spell_dbc` WHERE `ID` = 100224;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`, `SchoolMask`, `Name_Lang_enUS`)
VALUES (100224,
    0xA98000C0, 0x00000420, 0x10084000, 0x00130000,
    21, 1, 255, 1,
    6, 1, 299, 189,
    8388608, 1, 1, 'Paragon Expertise (x100)');

-- 100225: Big Parry (original: 10/stack → big: 1000/stack)
-- MiscValue 8 = CR_PARRY
DELETE FROM `spell_dbc` WHERE `ID` = 100225;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`, `SchoolMask`, `Name_Lang_enUS`)
VALUES (100225,
    0xA98000C0, 0x00000420, 0x10084000, 0x00130000,
    21, 1, 255, 1,
    6, 1, 999, 189,
    8, 1, 1, 'Paragon Parry (x100)');

-- 100226: Big Dodge (original: 10/stack → big: 1000/stack)
-- MiscValue 4 = CR_DODGE
DELETE FROM `spell_dbc` WHERE `ID` = 100226;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`,
    `EffectMiscValue_1`, `ImplicitTargetA_1`, `SchoolMask`, `Name_Lang_enUS`)
VALUES (100226,
    0xA98000C0, 0x00000420, 0x10084000, 0x00130000,
    21, 1, 255, 1,
    6, 1, 999, 189,
    4, 1, 1, 'Paragon Dodge (x100)');

-- ───────────────────────────────────────────────
-- Life Leech (SPELL_AURA_DUMMY = 4)
-- Original: 1 dummy per stack → Big: 100 dummy per stack
-- C++ reads stack counts from both auras to compute heal amount.
-- ───────────────────────────────────────────────

DELETE FROM `spell_dbc` WHERE `ID` = 100227;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`, `AttributesEx3`,
    `AttributesEx4`, `AttributesEx5`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`,
    `ImplicitTargetA_1`, `SchoolMask`, `Name_Lang_enUS`)
VALUES (100227,
    256,       -- 0x100: SPELL_ATTR0_HIDDEN_CLIENTSIDE
    1024,      -- 0x400: NOT_BREAK_STEALTH
    0,
    402653312, -- DEATH_PERSISTENT + HIDE_IN_COMBAT_LOG
    1024,      -- NOT_STEALABLE
    540672,    -- USABLE_WHILE_FEARED + USABLE_WHILE_CONFUSED
    21, 1, 255, 1,
    6, 1, 99, 4,
    1, 1, 'Paragon Life Leech (x100)');
