exec sp_configure 'show adv',1;reconfigure with override;
exec sp_configure 'Ad Hoc Dist',1 ;reconfigure with override;

declare @Server varchar(100)
,@sql nvarchar(max)

declare @servers table (servername varchar(100))

insert @servers values
('SERVER001\INSTANCE')
,('SERVER002\INSTANCE')
,('SERVER003\INSTANCE')
,('SERVER004\INSTANCE')
,('SERVER005\INSTANCE')
,('SERVER006\INSTANCE')
,('SERVER007\INSTANCE')
,('SERVER008\INSTANCE')
,('SERVER009\INSTANCE')
,('SERVER010\INSTANCE')
,('SERVER011\INSTANCE')
,('SERVER012\INSTANCE')
,('SERVER013\INSTANCE')
,('SERVER014\INSTANCE')
,('SERVER015\INSTANCE')
,('SERVER016\INSTANCE')

if OBJECT_ID('tempdb..#results') is not null
drop table #results;
create table #results (servername varchar(100) , sqlversion varchar(300));

declare servernames cursor for (select servername from @servers)
open servernames
fetch servernames into @Server

while @@FETCH_STATUS=0
begin

set @sql =
'INSERT #results
SELECT * FROM OPENROWSET(''SQLNCLI'', ''Server='+@Server+';user_id=sa;password=<PASSWORD>;'',''SELECT @@SERVERNAME,@@VERSION'') AS d;'

EXEC (@sql)
FETCH NEXT FROM servernames INTO @Server
end
CLOSE servernames
DEALLOCATE servernames

SELECT * FROM #results

exec sp_configure 'Ad Hoc Dist',0 ;reconfigure with override;
exec sp_configure 'show adv',0;reconfigure with override;