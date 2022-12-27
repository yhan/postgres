
# Postgres
Environment:  
Postgres v15  
DB driver: https://www.npgsql.org/doc/index.html  

##  Conclusion
DbContext without dispose, connection are immedialy closed.  
DbContext with dispose, connection state depends on pool is used or not, see below.  

## Some Tests
> **ALL Below Without DbContext dipose**. Code under https://github.com/yhan/postgres/tree/main/src


### Within Unit test
   `TestConnectionPool`  
   DbContext not disposed, but connection still closed !

### Within an long running process
> Turn ON/OFF connection pool with `appsettings`: bool `DbCnxPooling`.  

#### No Connection Pool 
      
   1. Sequential queries in loop.  `SequentialQueryDB`  
      , always only one connection.  
      
      ![image](https://user-images.githubusercontent.com/760399/209582043-b85c3ec3-2e70-40a8-aa19-9948daf34216.png)

       ```
       dbug: 12/26/2022 21:30:19.439 RelationalEventId.CommandCreating[20103] (Microsoft.EntityFrameworkCore.Database.Command)
             Creating DbCommand for 'ExecuteReader'.
       dbug: 12/26/2022 21:30:19.439 RelationalEventId.CommandCreated[20104] (Microsoft.EntityFrameworkCore.Database.Command)
             Created DbCommand for 'ExecuteReader' (0ms).
       dbug: 12/26/2022 21:30:19.440 RelationalEventId.CommandInitialized[20106] (Microsoft.EntityFrameworkCore.Database.Command)
             Initialized DbCommand for 'ExecuteReader' (0ms).
       dbug: 12/26/2022 21:30:19.440 RelationalEventId.ConnectionOpening[20000] (Microsoft.EntityFrameworkCore.Database.Connection)
             Opening connection to database 'hello' on server ''.
       dbug: 12/26/2022 21:30:19.440 RelationalEventId.ConnectionOpened[20001] (Microsoft.EntityFrameworkCore.Database.Connection)
             Opened connection to database 'hello' on server 'tcp://localhost:5444'.
       dbug: 12/26/2022 21:30:19.440 RelationalEventId.CommandExecuting[20100] (Microsoft.EntityFrameworkCore.Database.Command)
             Executing DbCommand [Parameters=[], CommandType='Text', CommandTimeout='30']
             SELECT count(*)::int
             FROM "MarketOrderVms" AS m
       info: 12/26/2022 21:30:19.443 RelationalEventId.CommandExecuted[20101] (Microsoft.EntityFrameworkCore.Database.Command) 
             Executed DbCommand (1ms) [Parameters=[], CommandType='Text', CommandTimeout='30']
             SELECT count(*)::int
             FROM "MarketOrderVms" AS m
       infodbug: 12/26/2022 21:30:19.443 RelationalEventId.DataReaderClosing[20301] (Microsoft.EntityFrameworkCore.Database.Command)
             Closing data reader to 'hello' on server 'tcp://localhost:5444'.
       : Microsoft.EntityFrameworkCore.Database.Command[20101]
             Executed DbCommand (1ms) [Parameters=[], CommandType='Text', CommandTimeout='30']
             SELECT count(*)::int
             FROM "MarketOrderVms" AS m
       dbug: 12/26/2022 21:30:19.444 RelationalEventId.DataReaderDisposing[20300] (Microsoft.EntityFrameworkCore.Database.Command)
             A data reader for 'hello' on server 'tcp://localhost:5444' is being disposed after spending 0ms reading results.
       dbug: 12/26/2022 21:30:19.444 RelationalEventId.ConnectionClosing[20002] (Microsoft.EntityFrameworkCore.Database.Connection)
             Closing connection to database 'hello' on server 'tcp://localhost:5444'.
       dbug: 12/26/2022 21:30:19.444 RelationalEventId.ConnectionClosed[20003] (Microsoft.EntityFrameworkCore.Database.Connection)
             Closed connection to database 'hello' on server '' (0ms).
       cnt=0

       ```
1. Run 10 blocking query in parallel (each lasts for 10 sec): `ParallelQueryDb`  
    ![image](https://user-images.githubusercontent.com/760399/209583694-3c7d5387-6ff5-4489-aa69-ee752a9be690.png)
    Then after 10s, connections immdiatly disapear.
    
    ![image](https://user-images.githubusercontent.com/760399/209585695-c337deae-5985-4cad-94f7-4f42fb42f6f6.png)


#### With Connection Pool
   `ParallelQueryDb`  
   Played pruning extra connections beyond Minimum Pool Size.  
   `Minimum Pool Size=5;Connection Idle Lifetime=5;Connection Pruning Interval=2;`  
   
   > Condition: DbContext Dispose AND No Dispose  
   
   As I started 10 tasks keeping alive connections for 10 sec.  
   after 10 sec (query duration) + 5 sec(idle then kill), 5 extra connections are pruned.  
   Pool keep 5 connections:
   ![image](https://user-images.githubusercontent.com/760399/209584905-4fea0505-62d3-4d09-abc1-613ea1211dfe.png)

 ## Connection pool
 What we want: 1000 requests, only several connections are opened (say 10).  
 In other words, we expect that 1000 requests can share 10 db conections.  
 
 Each request triggers a unit of work. Each unit of work does 12 operations using DbContext.
 
 
 Taking this "slow motion" example:  
 connection pool has a size of 1,  
 Two identical units of work, UOW-1 and UOW-2  each do:
  (1) query1 lasts for 10s
  (2) no op during 20s
  (3) query2 lasts for 10s

if the unit of work is not in one db transaction
UOW-1 and UOW-2 start at the same time. They will compete for the sole connection in the pool.  
Say UOW-1 wins, during (1), UOW-2 waits until UOW-1:(2) starts
|   |   |   |   |   |
|---|---|---|---|---|
| UOW-1:  |  (1)  |   (2)  | (3)   |   |
|   | 10s  | 20s  |  10s |   |
| UOW-2:  |   | (1)  |  (2) | (3)  |
|   |   | 10s  |  20s | 10s  |

 
 |   |   |   |   |   |
|---|---|---|---|---|
| UOW-1:  |  (1)  |   (2)  | (3)   |   |
|   | 10s  | 5s  | **(10-5)** + 10 s   => during (10-5)s, UOW-1 waits for UOW-2:(1) finishes  |   |
| UOW-2:  |   | (1)  |  (2) | (3)  |
|   |   | 10s  |  5s | 10s  |
 
 
UOW-1: (1)    (2)    (3)
       10s    5s     **(10-5)+10 s**   => during (10-5)s, UOW-1 waits for UOW-2:(1) finishes
UOW-2:        (1)    (2)    (3)
              10s    5s    10s
              

The compete and wait depends on shared DB Connection's state.  
if Connection is `Active`, then UOW-x waits, if Connection is `Idle`, then UOW-x can enter.
              
 
 
