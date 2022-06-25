select * from test_schema.mytable;
grant select on table test_schema.mytable to myuser2;

-- which user have what privileges
SELECT *
FROM information_schema.role_table_grants
WHERE table_name='mytable';

--- ??? HOW TO grant createRole to user - It is not managed by 'grant'!
CREATE ROLE readonly; -- fail

truncate table test_schema.mytable;
grant truncate on table mytable to tableowner;
alter table  test_schema.mytable
    drop column description;



/****************************************************
  POSTGRES NOTES
  ***************************************************/
-- https://www.prisma.io/dataguide/postgresql/authentication-and-authorization/role-management

-- 1. list roles permission
-- show role allowance
-- show also the user's belonging role

SELECT r.rolname, r.rolsuper, r.rolinherit,
  r.rolcreaterole, r.rolcreatedb, r.rolcanlogin,
  r.rolconnlimit, r.rolvaliduntil,
  ARRAY(SELECT b.rolname
        FROM pg_catalog.pg_auth_members m
        JOIN pg_catalog.pg_roles b ON (m.roleid = b.oid)
        WHERE m.member = r.oid) as memberof
, r.rolreplication
, r.rolbypassrls
FROM pg_catalog.pg_roles r
WHERE r.rolname !~ '^pg_'
ORDER BY 1;


-- 2. which user have what privileges on table
SELECT *
FROM information_schema.role_table_grants
WHERE table_name='tbhello';

-- 3. Show table owner
select * from pg_tables where tablename='tbhello';

-- 4. Grant role to another user
-- Current user: alice
-- Todo so, alice have to be member of tbowner and having admin option on role tbowner
-- for that, @postgres (being the superuser): `grant tbowner to alice with admin option;`
grant tbowner to myuser2;

-- 5. Show schema owner
/*
table_schema - schema name
schema_id - schema id, unique within the database
owner - principal that owns this schema
*/

select s.nspname as table_schema,
       s.oid as schema_id,
       u.usename as owner
from pg_catalog.pg_namespace s
join pg_catalog.pg_user u on u.usesysid = s.nspowner
order by table_schema;

SELECT * FROM pg_roles WHERE rolname !~ '^pg_';

-- who is super user
SELECT rolname FROM pg_roles WHERE rolsuper;
SELECT * FROM pg_roles;

-- 6. How grant role to user
-- Case 1) Grant from a user!= role
-- only member of a role and having "admin option" can grant role to another user ?
-- ** do this with superuser 'postgres' **
create role readonly;
grant readonly to myuser3 with admin option;
-- Then, myuser3 can do the grant
grant readonly to myuser2;
-- Case 2) Role with login capacity
-- login with the role, then do grant directly
-- // alice is a role: CREATE ROLE alice LOGIN PASSWORD 'alice';
-- login with alice then do
grant alice to myuser;


-- list all schemas
-- and you will see the schema owner
-- if you are not owner of schema, you can't do ALTER SCHEMA <SCHEMA_NAME> TO ...
SELECT * FROM information_schema.schemata;


grant usage on schema test_schema to myuser2;
ALTER SCHEMA test_schema owner to myuser3;

use quant to create table
transfer owner to api_ro
 --> 'quant' is owner of table => OK
 --> Rejected because 'quant' and 'api_ro' does not share un common role



/****

  ALTER TABLE table_name OWNER TO new_owner;

  Superusers can always do this;
  ordinary roles can only do it if they are both the current owner of the object (or a member of the owning role) and a member of the new owning role.

-- transfer table owner to another user
-- the current user has to be owner of that table
-- you transfer to a role which current member is of that role
-- and the new owning user should have CREATE privilege of that schema


 //////////  USE CASE ///////////

create table tb with quant
create user api_ro
transfer owner to api_ro ?

    do with superuser:
    --------------------------
create role tbowner;
grant tbowner to api_ro with admin option;
grant tbowner to quant;

    using quant:
    --------------
alter table owner to api_ro;
***/


SELECT current_user;  -- user name of current execution context
SELECT session_user;  -- session user name

SELECT * FROM pg_roles;

