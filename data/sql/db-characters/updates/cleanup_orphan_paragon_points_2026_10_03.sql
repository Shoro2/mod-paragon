-- Run with character creation/deletion stopped and a backup of the affected rows.
-- A soft-deleted character still has a characters row and keeps its allocation.
-- Account-wide level/XP in character_paragon is deliberately untouched.
DELETE `points`
FROM `character_paragon_points` AS `points`
LEFT JOIN `characters` AS `character` ON `character`.`guid` = `points`.`characterID`
WHERE `character`.`guid` IS NULL;
