-- The previous design applied paragon stats as non-passive, infinite-duration
-- auras, which the core saved to `character_aura` on logout and reloaded with
-- stale/255-capped stacks (the root of the relog/decay bug). Stats are now
-- applied via direct core stat APIs, so these saved auras must be purged.
-- The level marker (100000) is intentionally kept.

DELETE FROM `character_aura` WHERE `spell` IN (
    100001, 100002, 100003, 100004, 100005,
    100016, 100017, 100018, 100019, 100020, 100021, 100022, 100023,
    100024, 100025, 100026, 100027,
    100201, 100202, 100203, 100204, 100205,
    100216, 100217, 100218, 100219, 100220, 100221, 100222, 100223,
    100224, 100225, 100226, 100227
);
