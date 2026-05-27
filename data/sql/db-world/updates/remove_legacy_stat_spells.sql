-- Paragon stats are now applied via direct core stat APIs (no stacking auras).
-- Remove the obsolete module-defined spell_dbc rows from existing worlds:
--   100201-100227 : "big" (x100) stacking stat spells
--   100027        : Life Leech dummy aura (leech is pure C++ now)
-- The small primary/rating spells (100001-100026) live in the binary Spell.dbc
-- and are left untouched (unused but harmless).

DELETE FROM `spell_dbc` WHERE `ID` BETWEEN 100201 AND 100227;
DELETE FROM `spell_dbc` WHERE `ID` = 100027;
