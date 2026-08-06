alter database [mydb] set emergency
alter database [mydb] set single_user with rollback immediate
dbcc checkdb('mydb' /*,repair_allow_data_loss*/)

alter database [desktopcentral] set multi_user with rollback immediate

/******/
alter database [mydb] set offline
alter database [mydb] set online