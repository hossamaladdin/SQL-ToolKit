set nocount on
go

--disable user login
USE [master]
GO
ALTER LOGIN [svc_account] DISABLE
GO
--===================