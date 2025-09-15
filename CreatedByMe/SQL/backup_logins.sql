-- Script to backup logins with passwords, SIDs, and server privileges
-- Divided into sections for SQL logins and Windows logins

-- SQL Logins (with hashed passwords and SIDs)
SELECT 
    CASE WHEN sid = 0x01 THEN  -- sa login identified by SID
        CAST('ALTER LOGIN [' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(name AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST('] WITH ' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS +
        CAST('PASSWORD = ' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CONVERT(NVARCHAR(MAX), password_hash, 1) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(' HASHED' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS +
        CASE WHEN is_policy_checked = 0 THEN CAST(', CHECK_POLICY = OFF' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS ELSE CAST('' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS END +
        CASE WHEN is_expiration_checked = 0 THEN CAST(', CHECK_EXPIRATION = OFF' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS ELSE CAST('' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS END +
        CAST(';' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS
    ELSE
        CAST('-- SQL Login: ' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(name AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CHAR(10) +
        CAST('CREATE LOGIN [' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(name AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST('] WITH ' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS +
        CAST('PASSWORD = ' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CONVERT(NVARCHAR(MAX), password_hash, 1) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(' HASHED, ' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS +
        CAST('SID = ' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CONVERT(NVARCHAR(MAX), sid, 1) COLLATE SQL_Latin1_General_CP1_CI_AS + 
        CASE WHEN is_policy_checked = 0 THEN CAST(', CHECK_POLICY = OFF' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS ELSE CAST('' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS END +
        CASE WHEN is_expiration_checked = 0 THEN CAST(', CHECK_EXPIRATION = OFF' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS ELSE CAST('' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS END +
        CAST(';' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS
    END
FROM sys.sql_logins
WHERE name NOT LIKE '##%'  -- Exclude system logins
ORDER BY name;

-- Alter statements for disabled SQL logins
SELECT 
    CAST('ALTER LOGIN [' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(name AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST('] DISABLE;' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS
FROM sys.sql_logins
WHERE is_disabled = 1 AND name NOT LIKE '##%'
ORDER BY name;

-- Windows Logins (users and groups)
SELECT 
    CAST('-- Windows Login: ' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(name AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CHAR(10) +
    CAST('CREATE LOGIN [' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(name AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST('] FROM WINDOWS;' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS
FROM sys.server_principals
WHERE type IN ('U', 'G')  -- U: Windows user, G: Windows group
AND name NOT LIKE 'NT %'  -- Exclude built-in like NT AUTHORITY
ORDER BY name;

-- Server Role Memberships for all logins
SELECT 
    CAST('-- Server Role: ' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(r.name AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(' member ' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(p.name AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CHAR(10) +
    CAST('ALTER SERVER ROLE [' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(r.name AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST('] ADD MEMBER [' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(p.name AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST('];' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS
FROM sys.server_role_members m
JOIN sys.server_principals r ON m.role_principal_id = r.principal_id
JOIN sys.server_principals p ON m.member_principal_id = p.principal_id
WHERE p.type IN ('S', 'U', 'G')  -- SQL, Windows user, Windows group
ORDER BY p.name, r.name;

-- Server-Level Permissions for all logins
SELECT 
    CAST('-- Server Permission: ' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(permission_name AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(' granted to ' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(grantee.name AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CHAR(10) +
    CASE 
        WHEN sp.state = 'G' THEN CAST('GRANT ' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(permission_name AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(' TO [' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(grantee.name AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST('];' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS
        WHEN sp.state = 'D' THEN CAST('DENY ' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(permission_name AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(' TO [' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(grantee.name AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST('];' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS
        WHEN sp.state = 'W' THEN CAST('GRANT ' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(permission_name AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(' TO [' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST(grantee.name AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS + CAST('] WITH GRANT OPTION;' AS NVARCHAR(MAX)) COLLATE SQL_Latin1_General_CP1_CI_AS
    END
FROM sys.server_permissions sp
JOIN sys.server_principals grantee ON sp.grantee_principal_id = grantee.principal_id
WHERE sp.class = 100  -- Server-level permissions
AND grantee.type IN ('S', 'U', 'G')
ORDER BY grantee.name, permission_name;
