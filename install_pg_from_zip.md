https://roytuts.com/how-to-install-postgresql-zip-archive-in-windows/

init cluster:
```
# -D, --pgdata=DATADIR   location of the database storage area
initdb.exe -D C:\pgsql_data -U postgres -W -E UTF8 -A scram-sha-256

```

_-U postgres creates the superuser as postgres, -W prompts for the password of the superuser, -E UTF8 creates the database with UTF-8 encoding and -A scram-sha-256 enables password authentication._


this is where the cluster is generated: 
.\pgsql\pgsql_data


don't foget modify port to avoid port conflict: .\pgsql_data\postgresql.conf

start the cluster:
pg_ctl.exe -D C:\pgsql_data -l logfile start



