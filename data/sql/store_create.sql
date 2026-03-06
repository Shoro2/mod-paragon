/*
-- Query: SELECT * FROM store.store_categories
LIMIT 0, 10

-- Date: 2026-03-07 00:37
*/
CREATE DATABASE `store` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
CREATE TABLE `store_categories` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(765) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `icon` text COLLATE utf8mb4_general_ci,
  `requiredRank` int DEFAULT NULL,
  `flags` int unsigned NOT NULL DEFAULT '0',
  `enabled` int unsigned NOT NULL DEFAULT '1',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `store.store_categories` (`id`,`name`,`icon`,`requiredRank`,`flags`,`enabled`) VALUES (1,'Abyssal Mastery','achievement_arena_5v5_7',0,2,1);
INSERT INTO `store.store_categories` (`id`,`name`,`icon`,`requiredRank`,`flags`,`enabled`) VALUES (2,'Custom Talents','achievement_arena_2v2_7',0,0,0);
INSERT INTO `store.store_categories` (`id`,`name`,`icon`,`requiredRank`,`flags`,`enabled`) VALUES (3,'Ultimate Spells','achievement_arena_3v3_7',0,0,0);

CREATE TABLE `store_category_service_link` (
  `category` int unsigned NOT NULL,
  `service` int unsigned NOT NULL,
  PRIMARY KEY (`category`,`service`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `store_category_service_link` (`category`,`service`) VALUES (1,21);
INSERT INTO `store_category_service_link` (`category`,`service`) VALUES (1,22);
INSERT INTO `store_category_service_link` (`category`,`service`) VALUES (1,23);
INSERT INTO `store_category_service_link` (`category`,`service`) VALUES (1,24);
INSERT INTO `store_category_service_link` (`category`,`service`) VALUES (1,25);
INSERT INTO `store_category_service_link` (`category`,`service`) VALUES (1,26);
INSERT INTO `store_category_service_link` (`category`,`service`) VALUES (1,27);
INSERT INTO `store_category_service_link` (`category`,`service`) VALUES (1,28);
INSERT INTO `store_category_service_link` (`category`,`service`) VALUES (1,29);
INSERT INTO `store_category_service_link` (`category`,`service`) VALUES (1,30);
INSERT INTO `store_category_service_link` (`category`,`service`) VALUES (1,31);
INSERT INTO `store_category_service_link` (`category`,`service`) VALUES (1,32);
INSERT INTO `store_category_service_link` (`category`,`service`) VALUES (1,33);
INSERT INTO `store_category_service_link` (`category`,`service`) VALUES (1,34);
INSERT INTO `store_category_service_link` (`category`,`service`) VALUES (1,35);
INSERT INTO `store_category_service_link` (`category`,`service`) VALUES (1,36);

CREATE TABLE `store_currencies` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `type` int unsigned NOT NULL DEFAULT '1',
  `name` varchar(50) COLLATE utf8mb4_general_ci NOT NULL DEFAULT '',
  `icon` varchar(50) COLLATE utf8mb4_general_ci NOT NULL DEFAULT '',
  `data` int NOT NULL DEFAULT '0',
  `tooltip` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `store.store_currencies` (`id`,`type`,`name`,`icon`,`data`,`tooltip`) VALUES (1,1,'Gold','Gold',0,'This is normal gold.');
INSERT INTO `store.store_currencies` (`id`,`type`,`name`,`icon`,`data`,`tooltip`) VALUES (2,2,'Abyssal Points','Token',920920,'Allocate to improve your character main stats.');

CREATE TABLE `store_logs` (
  `account` int DEFAULT NULL,
  `guid` int DEFAULT NULL,
  `serviceId` int DEFAULT NULL,
  `currencyId` int DEFAULT NULL,
  `cost` int DEFAULT NULL,
  `time` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;



CREATE TABLE `store_services` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `type` int unsigned DEFAULT NULL,
  `name` text COLLATE utf8mb4_general_ci,
  `tooltipName` text COLLATE utf8mb4_general_ci,
  `tooltipType` varchar(765) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `tooltipText` text COLLATE utf8mb4_general_ci,
  `icon` varchar(765) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `price` int DEFAULT NULL,
  `currency` int DEFAULT NULL,
  `hyperlinkId` int DEFAULT NULL,
  `creatureEntry` int DEFAULT NULL,
  `discountAmount` int DEFAULT NULL,
  `flags` int DEFAULT NULL,
  `reward_1` int unsigned DEFAULT NULL,
  `reward_2` int unsigned DEFAULT NULL,
  `reward_3` int unsigned DEFAULT NULL,
  `reward_4` int unsigned DEFAULT NULL,
  `reward_5` int unsigned DEFAULT NULL,
  `reward_6` int unsigned DEFAULT NULL,
  `reward_7` int unsigned DEFAULT NULL,
  `reward_8` int unsigned DEFAULT NULL,
  `rewardcount_1` int unsigned DEFAULT NULL,
  `rewardcount_2` int unsigned DEFAULT NULL,
  `rewardcount_3` int unsigned DEFAULT NULL,
  `rewardcount_4` int unsigned DEFAULT NULL,
  `rewardcount_5` int unsigned DEFAULT NULL,
  `rewardcount_6` int unsigned DEFAULT NULL,
  `rewardcount_7` int unsigned DEFAULT NULL,
  `rewardcount_8` int unsigned DEFAULT NULL,
  `new` int unsigned NOT NULL DEFAULT '0',
  `enabled` int unsigned DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=251 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (1,8,'Level Boost\r\n+10 Levels','Level Boost','','Increase your characters levels by 10.','achievement_level_10',10,2,0,0,0,0,10,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (2,7,'Faction Change','Faction Change','','Allows you to change your characters faction. Available after relogging.','vas_factionchange',5,1,0,0,0,0,64,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (3,7,'Race Change','Race Change','','Allows you to change your characters race. Available after relogging.','vas_racechange',10,1,0,0,5,0,128,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (4,7,'Name Change','Name Change','','Allows you to change your characters name. Available after relogging.','vas_namechange',5,1,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (5,1,'Foam Sword\r\n(Two-Hand Sword)','','item','|cff00FFFFClick to preview!|r','inv_sword_22',10,1,45061,45061,0,1,45061,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (8,3,'Swift Spectral Tiger\r\n(Mount)','','spell','|cff00FFFFClick to preview!|r','ability_mount_spectraltiger',30,1,42777,24004,0,0,42777,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (12,1,'Epic Purple Shirt\r\n(Shirt)','','item','|cff00FFFFClick to preview!|r','inv_shirt_purple_01',10,1,45037,45037,5,1,45037,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (13,4,'Prairie Chicken\r\n(Pet)','','spell','|cff00FFFFClick to preview!|r','spell_magic_polymorphchicken',10,1,10686,7392,0,0,10686,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (14,8,'Level Boost\r\n+20 Levels','Level Boost','','Increase your characters levels by 20.','achievement_level_20',20,1,0,0,0,0,20,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (15,5,'Buff\r\nBlessing of Might','Buff','','Buffs you with Blessing of Might.','spell_holy_fistofjustice',1,1,0,0,0,0,27140,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (16,9,'Title\r\nChampion of the Naaru','Title','','Gives you the title Champion of the Naaru.','inv_mace_51',10,1,0,0,0,0,53,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (17,8,'Level 60 Boost','Level Boost','','Boosts your characters level to level 60!','achievement_level_60',40,1,0,0,0,1,60,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (18,1,'Tuxedo Set','Tuxedo Set','','Express your great fashion sense with this full Tuxedo set!\r\n\r\nContains the following:\r\n\r\n1x Tuxedo Jacket\r\n1x Tuxedo Shirt\r\n1x Tuxedo Pants','inv_shirt_black_01',50,1,0,0,0,1,10036,10035,10034,0,0,0,0,0,1,1,1,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (21,10,'Strength','Allocate Strength','','Increases your Strength by 5.','spell_nature_strength',1,2,0,0,0,0,7507,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (22,10,'Intellect','Allocate Intellect','','Increases your Intellect by 5.','spell_holy_arcaneintellect',1,2,0,0,0,0,100002,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (23,10,'Agility','Allocate Agility','','Increases your Agility by 5.','spell_holy_blessingofagility',1,2,0,0,0,0,100003,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (24,10,'Spirit','Allocate Spirit','','Increases your Spirit by 5.','spell_holy_prayerofspirit',1,2,0,0,0,0,100004,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (25,10,'Stamina','Allocate Stamina','','Increases your Stamina by 5.','spell_holy_blessingofstamina',1,2,0,0,0,0,100005,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (26,10,'Haste','Allocate Haste rating',NULL,'Increases your Haste rating by 5.','inv_jewelry_talisman_04',1,2,0,0,0,0,100016,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (27,10,'Armor Penetration','Allocate Armor Penetration rating',NULL,'Increases your Armor Penetration rating by 5.','ability_warrior_sunder',1,2,0,0,0,0,100017,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (28,10,'Spell Power','Allocate Spell Power',NULL,'Increases your Spell Power by 10.','spell_arcane_studentofmagic',1,2,0,0,0,0,100018,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (29,10,'Crit','Allocate Crit rating',NULL,'Increases your Crit rating by 10.','ability_warrior_unrelentingassault',1,2,0,0,0,0,100019,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (30,10,'Movement Speed','Allocate Movement Speed',NULL,'Increases your Movement Speed by 1%.','ability_rogue_sprint',1,2,0,0,0,0,100020,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (31,10,'MP5','Allocate MP5',NULL,'Increases your mana per 5 seconds by 5.','spell_shadow_soulleech_2',1,2,0,0,0,0,100021,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (32,10,'Hit','Allocate Hit rating',NULL,'Increases your Hit rating by 10','ability_hunter_snipertraining',1,2,0,0,0,0,100022,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (33,10,'Block','Allocate Block rating',NULL,'Increases your Block rating by 4.','ability_warrior_shieldwall',1,2,0,0,0,0,100023,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (34,10,'Expertise','Allocate Expertise rating',NULL,'Increases your Expertise rating by 3.','ability_warrior_offensivestance',1,2,0,0,0,0,100024,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (35,10,'Parry','Allocate Parry rating',NULL,'Increases your Parry rating by 10.','spell_deathknight_spelldeflection',1,2,0,0,0,0,100025,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (36,10,'Dodge','Allocate Dodge rating',NULL,'Increases your Dodge rating by 10.','ability_rogue_unfairadvantage',1,2,0,0,0,0,100026,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (210,11,'Strength','Remove Strength','','Decreases your Strength by 1.','spell_nature_strength',1,2,0,0,0,0,100001,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (220,11,'Intellect','Remove Intellect','','Decreases your Intellect by 1.','spell_holy_arcaneintellect',1,2,0,0,0,0,100002,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (230,11,'Agility','Remove Agility','','Decreases your Agility by 1.','spell_holy_blessingofagility',1,2,0,0,0,0,100003,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (240,11,'Spirit','Remove Spirit','','Decreases your Spirit by 1.','spell_holy_prayerofspirit',1,2,0,0,0,0,100004,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
INSERT INTO `store.store_services` (`id`,`type`,`name`,`tooltipName`,`tooltipType`,`tooltipText`,`icon`,`price`,`currency`,`hyperlinkId`,`creatureEntry`,`discountAmount`,`flags`,`reward_1`,`reward_2`,`reward_3`,`reward_4`,`reward_5`,`reward_6`,`reward_7`,`reward_8`,`rewardcount_1`,`rewardcount_2`,`rewardcount_3`,`rewardcount_4`,`rewardcount_5`,`rewardcount_6`,`rewardcount_7`,`rewardcount_8`,`new`,`enabled`) VALUES (250,11,'Stamina','Remove Stamina','','Decreases your Stamina by 1.','spell_holy_blessingofstamina',1,2,0,0,0,0,100005,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1);
