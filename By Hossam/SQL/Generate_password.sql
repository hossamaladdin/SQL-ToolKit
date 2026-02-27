DECLARE @Password NVARCHAR(50) = '';

-- Character pools
DECLARE @Upper NVARCHAR(26) = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
DECLARE @Lower NVARCHAR(26) = 'abcdefghijklmnopqrstuvwxyz';
DECLARE @Numbers NVARCHAR(10) = '0123456789';

-- Ensure complexity: pick at least one from each category
SET @Password += SUBSTRING(@Upper, ABS(CHECKSUM(NEWID())) % LEN(@Upper) + 1, 1);
SET @Password += SUBSTRING(@Lower, ABS(CHECKSUM(NEWID())) % LEN(@Lower) + 1, 1);
SET @Password += SUBSTRING(@Numbers, ABS(CHECKSUM(NEWID())) % LEN(@Numbers) + 1, 1);

-- Fill remaining characters randomly from all pools combined
DECLARE @AllChars NVARCHAR(100) = @Upper + @Lower + @Numbers;

WHILE LEN(@Password) < 12
BEGIN
    SET @Password += SUBSTRING(@AllChars, ABS(CHECKSUM(NEWID())) % LEN(@AllChars) + 1, 1);
END

-- Shuffle characters (to avoid predictable first 3)
;WITH cte AS (
    SELECT SUBSTRING(@Password, number, 1) AS Ch
    FROM master.dbo.spt_values
    WHERE type = 'P' AND number BETWEEN 1 AND LEN(@Password)
)
SELECT STRING_AGG(Ch, '') WITHIN GROUP (ORDER BY NEWID()) AS RandomPassword
FROM cte;
