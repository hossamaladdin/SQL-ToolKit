set nocount on
go

--Add sysadmin login
USE [master]
GO
CREATE LOGIN [DOMAIN\dba.admin] FROM WINDOWS WITH DEFAULT_DATABASE=[master]
GO
ALTER SERVER ROLE [sysadmin] ADD MEMBER [DOMAIN\dba.admin]
GO
--===================