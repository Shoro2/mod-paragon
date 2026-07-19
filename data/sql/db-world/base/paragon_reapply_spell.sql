-- Paragon Reapply Trigger (spell_dbc ID 100028)
--
-- Hidden, server-side dummy spell. The Lua/AIO layer casts it on the player
-- after writing a point allocation to the DB; the C++ SpellScript
-- 'spell_paragon_reapply' then re-derives and applies the player's stats,
-- keeping C++ the single source of truth for stat application.
--
-- Effect 1 = SPELL_EFFECT_DUMMY (3), self target. No aura is created.
-- Attributes 0x180 = DO_NOT_DISPLAY (0x80) + DO_NOT_LOG (0x100).

-- EquippedItemClass MUST be -1 (no item requirement): the table default is 0
-- = ITEM_CLASS_CONSUMABLE, which makes every cast fail CheckItems (this
-- exact default-0 trap silently broke the reapply cast on 2026-07-19).

DELETE FROM `spell_dbc` WHERE `ID` = 100028;
INSERT INTO `spell_dbc` (`ID`, `Attributes`,
    `EquippedItemClass`, `EquippedItemSubclass`, `EquippedItemInvTypes`,
    `DurationIndex`, `RangeIndex`, `CastingTimeIndex`,
    `Effect_1`, `ImplicitTargetA_1`,
    `SchoolMask`, `Name_Lang_enUS`)
VALUES (100028,
    384,
    -1, 0, 0,
    1, 1, 1,
    3, 1,
    1, 'Paragon Reapply Trigger');

DELETE FROM `spell_script_names` WHERE `spell_id` = 100028;
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`)
VALUES (100028, 'spell_paragon_reapply');
