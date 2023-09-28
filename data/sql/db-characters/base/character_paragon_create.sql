CREATE TABLE `acore_characters`.`character_paragon` (
  `guid` INT UNSIGNED NOT NULL,
  `level` SMALLINT NULL,
  `xp` SMALLINT NULL,
  PRIMARY KEY (`guid`));

CREATE TABLE `acore_characters`.`character_paragon_points` (
  `guid` INT NULL,
  `spell` INT NULL,
  `points` INT NULL,
  `id` INT NOT NULL,
  PRIMARY KEY (`id`));