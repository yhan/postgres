
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

 ## Connection pool in Unit of work
 What we want: 1000 requests, only several connections are opened (say 10).   
 In other words, we expect that 1000 requests can share 10 db conections.   
 
 Each request triggers a unit of work. Each unit of work does 12 operations using DbContext.  
 
 
 Taking this "slow motion" example:   
 connection pool has a size of 1,   
 
1. **Unit of work NOT in a transaction**   

   Two identical units of work, UOW-1 and UOW-2  each does:  
   (1) query1 lasts for 10s  
   (2) no op during **20s**  
   (3) query2 lasts for 10s  
  
   UOW-1 and UOW-2 start at the same time. They will compete for the sole connection in the pool.  
   Say UOW-1 wins, during (1), UOW-2 waits until UOW-1:(2) starts
   |   |   |   |   |   |
   |---|---|---|---|---|
   | UOW-1:  |  (1)  |   (2)  | (3)   |   |
   |   | 10s  | 20s  |  10s |   |
   | UOW-2:  |   | (1)  |  (2) | (3)  |
   |   |   | 10s  |  20s | 10s  |

   Another example:  
   Two identical units of work, UOW-1 and UOW-2 each does:  
   (1) query1 lasts for 10s  
   (2) no op during **5s**  
   (3) query2 lasts for 10s  
   |   |   |   |   |   |
   |---|---|---|---|---|
   | UOW-1:  |  (1)  |   (2)  | (3)   |   |
   |   | 10s  | 5s  | **(10-5)** + 10 s   => during (10-5)s, UOW-1 waits for UOW-2:(1) to be finished  |   |
   | UOW-2:  |   | (1)  |  (2) | (3)  |
   |   |   | 10s  |  5s | **(10-5)** + 10 s   => during (10-5)s, UOW-2 waits for UOW-1:(3) to be finished  |
 

   ![image](https://user-images.githubusercontent.com/760399/209679978-25d9a2c9-f863-43db-a703-0495ae174c06.png)


   We can see that Units of work compete and wait, all depends on shared DB Connection's state.  
   If Connection is `Active`, then UOW-x waits, if Connection is `Idle`, then UOW-x can enter.  
   **Connection state transition:** `Idle` -> `Active` -> `Idle` -> `Active` -> `Idle`.
   **Overall duration:** 40s

2. **Unit of work IN a transaction**

   |   |   |   |   |   |   |   |   |
   |---|---|---|---|---|---|---|---|
   | UOW-1:  |  (1)  |   (2)  | (3)   |   |   |   |
   |   | 10s  | 5s  |  10s |   |   |   |
   | UOW-2:  |      |   || (1)  |  (2) | (3)  |
   |   |   |   |   | 10s  |  5s | 10s  |
   
   
    **Connection state transition:** `Idle` -> `Active` -> **`Idle in transaction`** -> `Active` -> `Idle`  
    During **`Idle in transaction`**, contrary to `Idle`, the connection can't be shared. 
    
    **Overall duration:** 50s          
 
 
### Sum up

 | Unit of work  | db connection can be shared  |  1000 requests arrive at the same time, how many db connections required  |   |   |   |   |   |
   |---|---|---|---|---|---|---|---|
   | In a transaction  | NO  | 1000  |  |   |   |   |
   | Not in a transaction  | YES  | less than 1000  |  |   |   |   |
   
   
## How connection got closed/returned to pool


1. Read

   ```csharp

   [HttpGet("Close")]
   public int Close()
   {
        //context registered as a singleton
        return context.MarketOrderVms.Count();
   }

   ```


   ```
   NpgsqlConnection.Close()at C:\Users\hanyi\AppData\Roaming\JetBrains\Rider2022.3\resharper-host\SourcesCache\58e753b49452a9b2ca6a4a8ffb5fdf4e88633db5cdc6516141328567148779\NpgsqlConnection.cs:line 782
   NpgsqlConnection.Close()at C:\Users\hanyi\AppData\Roaming\JetBrains\Rider2022.3\resharper-host\SourcesCache\58e753b49452a9b2ca6a4a8ffb5fdf4e88633db5cdc6516141328567148779\NpgsqlConnection.cs:line 758
   RelationalConnection.CloseDbConnection() //EF CORE
   RelationalConnection.Close()
   RelationalDataReader.Dispose()
   SingleQueryingEnumerable<int>.Enumerator.Dispose()
   Enumerable.TryGetSingle<int>()
   Enumerable.Single<int>()
   [Lightweight Method Call]
   QueryCompiler.Execute<int>()
   EntityQueryProvider.Execute<int>()
   Queryable.Count<Common.MarketOrderVm>()
   CnxPoolController.Close()
   ```

   `Enumerable.TryGetSingle<int>()`:  
   https://github.com/dotnet/runtime/blob/ebba1d4acb7abea5ba15e1f7f69d1d1311465d16/src/libraries/System.Linq/src/System/Linq/Single.cs#L120  


   `RelationalConnection.CloseDbConnection()`:  
   https://github.com/dotnet/efcore/blob/e78f0d48f94fab2e78a16701e2aa6b0059aa8ee5/src/EFCore.Relational/Storage/RelationalConnection.cs#L887  
   
2. Write


   ```csharp
   [HttpGet("WriteAndClose")]
    public void WriteAndClose()
    {
        context.MarketOrderVms.AddRange(new Generator().Execute());
        context.SaveChanges();
    }
   ```

   ```
   RelationalConnection.Close()at C:\Users\hanyi\AppData\Roaming\JetBrains\Rider2022.3\resharper-host\SourcesCache\20c132316f9f203a2868f88ac266cb785c1b298491352ce0e7c5ec23c820e4d3\RelationalConnection.cs:line 865
   RelationalDataReader.Dispose()at C:\Users\hanyi\AppData\Roaming\JetBrains\Rider2022.3\resharper-host\SourcesCache\8ba9ab14678cb93a3fac93994b4f5f345bd3438420205057eec9d0dce8cc31fe\RelationalDataReader.cs:line 183
   ReaderModificationCommandBatch.Execute()
   BatchExecutor.Execute()
   RelationalDatabase.SaveChanges()
   StateManager.SaveChanges()
   StateManager.SaveChanges()
   StateManager.<>c.<SaveChanges>b__107_0()
   NpgsqlExecutionStrategy.Execute<(Microsoft.EntityFrameworkCore.ChangeTracking.Internal.StateManager, bool), int>()
   StateManager.SaveChanges()
   DbContext.SaveChanges()
   DbContext.SaveChanges()
   CnxPoolController.WriteAndClose()
   ```


   `ReaderModificationCommandBatch.Execute`:  
   https://github.com/dotnet/efcore/blob/e78f0d48f94fab2e78a16701e2aa6b0059aa8ee5/src/EFCore.Relational/Update/ReaderModificationCommandBatch.cs#L346
