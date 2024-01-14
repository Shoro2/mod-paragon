CREATE TABLE `character_paragon_points` (
  `characterID` int(11) NOT NULL,
  `pstrength` int(11) DEFAULT 0,
  `pintellect` int(11) DEFAULT 0,
  `pagility` int(11) DEFAULT 0,
  `pspirit` int(11) DEFAULT 0,
  `pstamina` int(11) DEFAULT 0,
  PRIMARY KEY (`characterID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;