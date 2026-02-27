sqlcmd -E -i .\Log_Size_Check.sql -o .\Results\result1.csv 		-s "," -W -f 65001 -S EGASSPCI

cd .\results\ && copy result*.csv Final.csv && del result*.csv && cd ..