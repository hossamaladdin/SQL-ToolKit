sqlcmd -E -i .\sql2.sql -o .\Results\result1.csv 		-s "," -W -f 65001 -S yourserver
::add your servers here
sqlcmd -U username -P password -i .\sql2.sql -o .\Results\result17.csv  -h-1 -s "," -W -f 65001 -S yourserver

cd .\results\ && copy result*.csv Final.csv && del result*.csv && cd ..