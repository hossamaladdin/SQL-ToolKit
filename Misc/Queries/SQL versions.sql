exec sp_configure 'show adv',1;reconfigure with override;
exec sp_configure 'Ad Hoc Dist',1 ;reconfigure with override;

declare @Server varchar(100)
,@sql nvarchar(max)

declare @servers table (servername varchar(100))

insert @servers values
('APEXN\APEX')
,('APPDB19N\APPDB19')
,('DEDRAKDIRPROD\DEDRAKDIRPROD')
,('DESKTOPN19\DESKTOP19')
,('E11PRODN\E11PROD')
,('EGASP2016N\EGASP2016')
,('FinbudgetN\FINBUDGET')
,('GRAPROD1N\GRAPROD1')
,('GRAPROD2019N\GRAPROD2019')
,('IDAMPRODN\IDAMPROD')
,('OPENTEXTPROD\OPENTEXTPROD')
,('RAKPOLICELIMSN\RAKPOLICELIMS')
,('SMSN\SMS')
,('TimeN\TIME')
,('TREND2019N\TRENDMICRO')
,('UCSRAKN\UCSRAK')

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
SELECT * FROM OPENROWSET(''SQLNCLI'', ''Server='+@Server+';user_id=sa;password=ega@1234;'',''SELECT @@SERVERNAME,@@VERSION'') AS d;'

EXEC (@sql)
FETCH NEXT FROM servernames INTO @Server
end
CLOSE servernames
DEALLOCATE servernames

SELECT * FROM #results

exec sp_configure 'Ad Hoc Dist',0 ;reconfigure with override;
exec sp_configure 'show adv',0;reconfigure with override;