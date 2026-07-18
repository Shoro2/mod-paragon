-- Paragon Mount Speed spell (spell_dbc ID 100029)
--
-- Server-side, hidden, non-stacking aura applied once with the full value via
-- CastCustomSpell + SPELLVALUE_BASE_POINT0/1 (no stacking → no 255 cap).
-- Mirrors the two effects of the legacy stacking spell:
--   Effect 1: SPELL_AURA_MOD_INCREASE_SPEED      (31) - run speed
--   Effect 2: SPELL_AURA_MOD_INCREASE_SWIM_SPEED (58) - swim speed
-- Both base points are set at cast time (DieSides 0 → exact value).
--
-- Attributes match the hidden legacy stat auras (100001-100026), NOT the old
-- Life Leech spell 100027 whose bits were wrong (its Ex3 0x18000080 was junk
-- and it was missing death persistence — the reason it dropped on wipes):
--   Attributes:    0x180    DO_NOT_DISPLAY (0x80, hides aura icon)
--                           + DO_NOT_LOG (0x100, hides combat log)
--   AttributesEx:  0x420    ALLOW_WHILE_STEALTHED + NO_THREAT
--   AttributesEx3: 0x130000 SUPPRESS_CASTER_PROCS + SUPPRESS_TARGET_PROCS
--                           + ALLOW_AURA_WHILE_DEAD (death persistent)
--   AttributesEx4: 0x400    NOT_STEALABLE
--   AttributesEx5: 0x60000  ALLOW_WHILE_FLEEING + ALLOW_WHILE_CONFUSED

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
    384, 1056, 0, 1245184, 1024, 393216,
    21, 1, 0, 1,
    6, 0, 0, 31, 1,
    6, 0, 0, 58, 1,
    1, 'Paragon Mount Speed');
