-- Paragon Reapply Trigger (spell_dbc ID 100028)
--
-- Hidden, server-side dummy spell. The Lua/AIO layer casts it on the player
-- after writing a point allocation to the DB; the C++ SpellScript
-- 'spell_paragon_reapply' then re-derives and applies the player's stats,
-- keeping C++ the single source of truth for stat application.
--
-- Effect 1 = SPELL_EFFECT_DUMMY (3), self target. No aura is created.

DELETE FROM `spell_dbc` WHERE `ID` = 100028;
INSERT INTO `spell_dbc` (`ID`, `Attributes`,
    `DurationIndex`, `RangeIndex`, `CastingTimeIndex`,
    `Effect_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `Name_Lang_enUS`)
VALUES (100028,
    256,
    1, 1, 1,
    3, 1,
    1, 'Paragon Reapply Trigger');

DELETE FROM `spell_script_names` WHERE `spell_id` = 100028;
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`)
VALUES (100028, 'spell_paragon_reapply');
