-- Creating a duplicate of the original table so you can go back
CREATE TABLE auto_stage1 AS 
SELECT *
FROM `automobile-insurance-company-complaint-rankings-beginning-2009-1`;


-- organize by company by year 
SELECT *
FROM auto_stage1
ORDER BY `company name` ASC, `filing year` ASC;

-- Check for copmanies with duplicates rows where company name and filling year are the same
SELECT `company name`, `filing year`, COUNT(*) AS count
FROM auto_stage1
GROUP BY `company name`, `Filing Year`
HAVING COUNT(*) > 1;

-- Investigating where having count > 1
SELECT *
FROM auto_stage1
WHERE `Company Name` LIKE 'maid%' 
ORDER BY 1;

-- changing company name
SELECT DISTINCT(NAIC)
FROM auto_stage1
WHERE `company name` LIKE 'Maid%';

SELECT *
FROM auto_stage1
WHERE `company name` LIKE 'Maid%';


UPDATE auto_stage1
SET `company name` = 'Maidstone Insurance Company 2'
WHERE `Company Name` = 'Maidstone Insurance Company'
	AND `NAIC` <> '34460';
    
-- delete duplicate maidstone row 
DELETE FROM auto_stage1
WHERE `company name` LIKE 'Maidstone%'
AND `NAIC` = '34479'
AND `index` = 342;

-- changing upheld complaints where index = 446
SELECT SUM(`upheld complaints`) AS total_upheld
FROM auto_stage1
WHERE `index` IN (341, 446);


SET @total_upheld := (SELECT SUM(`upheld complaints`) 
                      FROM auto_stage1 
                      WHERE `index` IN (341, 446));

UPDATE auto_stage1
SET `upheld complaints` = @total_upheld
WHERE `index` IN (341, 446);


-- changing not upheld complaints column where index = 446
SELECT SUM(`not upheld complaints`) AS total_not_upheld
FROM auto_stage1
WHERE `index` IN (341, 446);


SET @total_not_upheld := (SELECT SUM(`not upheld complaints`) 
                      FROM auto_stage1 
                      WHERE `index` IN (341, 446));

UPDATE auto_stage1
SET `not upheld complaints` = @total_not_upheld
WHERE `index` IN (341, 446);


-- changing question of fact complaint column where index = 446
SELECT SUM(`Question of Fact Complaints`) AS total_question
FROM auto_stage1
WHERE `index` IN (341, 446);


SET @total_question := (SELECT SUM(`Question of Fact Complaints`) 
                      FROM auto_stage1 
                      WHERE `index` IN (341, 446));

UPDATE auto_stage1
SET `Question of Fact Complaints` = @total_question
WHERE `index` IN (341, 446);


-- changing total complaints column where index = 446, this is 25 after going back to the original table 

SELECT SUM(`total complaints`) AS total_complaints
FROM auto_stage1
WHERE `index` IN (341, 446);


SET @total_complaints := (SELECT SUM(`total complaints`) 
                      FROM auto_stage1 
                      WHERE `index` IN (341, 446));

UPDATE auto_stage1
SET `total complaints` = 25
WHERE `index` IN (341, 446);



-- changing premium written in millions column where index = 446

SELECT SUM(`Premiums Written (in Millions)`) AS total_premium
FROM auto_stage1
WHERE `index` IN (341, 446);


SET @total_premium := (SELECT SUM(`Premiums Written (in Millions)`) 
                      FROM auto_stage1 
                      WHERE `index` IN (341, 446));

UPDATE auto_stage1
SET `Premiums Written (in Millions)` = @total_premium
WHERE `index` IN (341, 446);


-- rank will be deleted and remade
ALTER TABLE auto_stage1
DROP COLUMN `Rank`;

-- add new ratio which is based off of upheld complaints/ premiums
UPDATE auto_stage1
SET `ratio` = `upheld complaints` / `Premiums Written (in Millions)`
WHERE `index` IN (341, 446);

-- delete index = 341

DELETE FROM auto_stage1
WHERE `index` = 341;

-- rounding the ratio up to 2 decimal points
UPDATE auto_stage1
SET `ratio` = ROUND(ratio, 2);

-- creating a new column categorizing ratio column by likely or unlikely to uphold your complaint
ALTER TABLE auto_stage1
ADD COLUMN uphold_likelihood VARCHAR(20);


UPDATE auto_stage1
SET uphold_likelihood = CASE
    WHEN ratio >= 5 THEN 'Likely'
    ELSE 'Unlikely'
END;


SELECT *
FROM auto_stage1
WHERE uphold_likelihood = 'likely';



-- ranking based off of premiums written by year
-- Step 1: Add a new column to store the rank
ALTER TABLE auto_stage1
ADD COLUMN premium_rank INT;

-- Step 2: Update the new column with ranks based on premiums_written within each year
WITH RankedData AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY `filing year` ORDER BY `Premiums Written (in Millions)` DESC) AS `rank`
    FROM auto_stage1
)
UPDATE auto_stage1
JOIN RankedData ON auto_stage1.`index` = RankedData.`index`
SET auto_stage1.premium_rank = RankedData.rank;


-- top 5 ranked insurance companies each year 
SELECT *
FROM auto_stage1
WHERE `premium_rank` <= 5
ORDER BY `filing year`, `premium_rank`;

-- looks like 2015 and 2016 data are the same so we should not rely on that year, lets investigate
SELECT *
FROM auto_stage1
WHERE (`FILING YEAR` = 2016
OR `FILING YEAR` = 2015)
AND (`Question of Fact Complaints` = 17
AND `Not upheld complaints` = 29);

-- Check for copmanies with duplicates rows where company name and filling year are the same fix this 
SELECT `company name`, `upheld complaints`, `ratio`,  `Total Complaints`, `premiums written (in millions)`, COUNT(*) AS count
FROM auto_stage1
GROUP BY `company name`, `upheld complaints`, `ratio`,  `Total Complaints`, `premiums written (in millions)`
HAVING COUNT(*) > 1;


-- backup data before deletion
CREATE TABLE insurance_data_backup AS
SELECT * FROM auto_stage1;

SELECT *
FROM insurance_data_backup;
-- delete duplicate rows
WITH RankedRows AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY premium_rank, `premiums written (in millions)` ORDER BY `index`) AS row_num
    FROM insurance_data_backup
)
DELETE FROM insurance_data_backup
WHERE `index` IN (
    SELECT `index`
    FROM RankedRows
    WHERE row_num > 1
);

-- 2015 data was deleted so we're going to change 2016 data to 2015 as it's likely 2016 that wasn't updated
SELECT *
FROM insurance_data_backup 
WHERE `filing year` = 2016;

UPDATE insurance_data_backup
SET `filing year` = 2015
WHERE `filing year` = 2016;
