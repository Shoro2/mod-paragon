-- Fix wrong attribute bits on the paragon server-side spells (2026-07-19).
--
-- Both rows carried Attributes 0x100 (DO_NOT_LOG) where the comment claimed
-- HIDDEN_CLIENTSIDE — the real hide-icon bit is 0x80 (DO_NOT_DISPLAY).
-- 100029 additionally copied its Ex1/Ex3/Ex5 bits from the broken legacy
-- Life Leech spell 100027: Ex3 0x18000080 is junk (the death-persistent bit
-- is 0x100000) and Ex5 0x84000 was AI_DOESNT_FACE_TARGET + NOT_AVAILABLE_
-- WHILE_CHARMED instead of the intended ALLOW_WHILE_FLEEING/CONFUSED.
-- Target bits now match the hidden legacy stat auras 100001-100026.

UPDATE `spell_dbc`
    SET `Attributes` = `Attributes` | 0x80
    WHERE `ID` IN (100028, 100029);

UPDATE `spell_dbc`
    SET `AttributesEx` = `AttributesEx` | 0x20,
        `AttributesEx3` = (`AttributesEx3` & ~0x18000080) | 0x130000,
        `AttributesEx5` = (`AttributesEx5` & ~0x84000) | 0x60000
    WHERE `ID` = 100029;
