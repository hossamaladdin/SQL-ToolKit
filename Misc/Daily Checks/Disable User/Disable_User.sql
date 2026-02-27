set nocount on
go

--disable user login
USE [master]
GO
ALTER LOGIN [svcotad!] DISABLE
GO
--===================