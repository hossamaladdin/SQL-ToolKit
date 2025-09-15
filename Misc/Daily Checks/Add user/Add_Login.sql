set nocount on
go

--Add sysadmin login
USE [master]
GO
CREATE LOGIN [EGA\mohamed.reda.adm] FROM WINDOWS WITH DEFAULT_DATABASE=[master]
GO
ALTER SERVER ROLE [sysadmin] ADD MEMBER [EGA\mohamed.reda.adm]
GO
--===================