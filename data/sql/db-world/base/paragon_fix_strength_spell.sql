-- Fix Paragon Strength spell (ID 100001)
--
-- AzerothCore's base spell_dbc.sql contains an entry for spell 100001
-- ("Drain Soul increased damage") with SPELL_AURA_DUMMY.
-- This OVERRIDES the correct definition in the binary Spell.dbc file,
-- which defines 100001 as "Increased Strength 05" with SPELL_AURA_MOD_STAT.
--
-- Result: Paragon Strength stat does nothing because the aura is DUMMY.
-- Fix: Remove the conflicting spell_dbc override so the correct DBC entry is used.

DELETE FROM `spell_dbc` WHERE `ID` = 100001;
