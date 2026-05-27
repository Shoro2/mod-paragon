-- Paragon Mount Speed spell (spell_dbc ID 100029)
--
-- Server-side, hidden, non-stacking aura applied once with the full value via
-- CastCustomSpell + SPELLVALUE_BASE_POINT0/1 (no stacking → no 255 cap).
-- Mirrors the two effects of the legacy stacking spell:
--   Effect 1: SPELL_AURA_MOD_INCREASE_SPEED      (31) - run speed
--   Effect 2: SPELL_AURA_MOD_INCREASE_SWIM_SPEED (58) - swim speed
-- Both base points are set at cast time (DieSides 0 → exact value).
--
-- Attributes match the sticky Paragon stat spells:
--   Attributes:    0x100   HIDDEN_CLIENTSIDE (movement speed is server-driven)
--   AttributesEx:  0x400   NOT_BREAK_STEALTH
--   AttributesEx3: 0x18000000 DEATH_PERSISTENT + HIDE_IN_COMBAT_LOG
--   AttributesEx4: 0x400   NOT_STEALABLE
--   AttributesEx5: 0x84000 USABLE_WHILE_FEARED + USABLE_WHILE_CONFUSED

DELETE FROM `spell_dbc` WHERE `ID` = 100029;
INSERT INTO `spell_dbc` (`ID`, `Attributes`, `AttributesEx`, `AttributesEx2`,
    `AttributesEx3`, `AttributesEx4`, `AttributesEx5`,
    `DurationIndex`, `RangeIndex`, `CumulativeAura`, `CastingTimeIndex`,
    `Effect_1`, `EffectDieSides_1`, `EffectBasePoints_1`, `EffectAura_1`,
    `ImplicitTargetA_1`,
    `Effect_2`, `EffectDieSides_2`, `EffectBasePoints_2`, `EffectAura_2`,
    `ImplicitTargetA_2`,
    `SchoolMask`, `Name_Lang_enUS`)
VALUES (100029,
    256, 1024, 0, 402653312, 1024, 540672,
    21, 1, 0, 1,
    6, 0, 0, 31, 1,
    6, 0, 0, 58, 1,
    1, 'Paragon Mount Speed');
