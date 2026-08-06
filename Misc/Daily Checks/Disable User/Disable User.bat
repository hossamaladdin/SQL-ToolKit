sqlcmd -E -i .\Disable_User.sql -o .\Results\result1.csv 		-s "," -W -f 65001 -S YOURSERVER

cd .\results\ && copy result*.csv Final.csv && del result*.csv && cd ..