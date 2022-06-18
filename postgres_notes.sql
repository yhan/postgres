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

select * from pg_tables where tablename='mytable';

/****************************************************
  POSTGRES NOTES
  ***************************************************/
-- https://www.prisma.io/dataguide/postgresql/authentication-and-authorization/role-management

-- 1. list roles permission
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


-- 2. which user have what privileges
SELECT *
FROM information_schema.role_table_grants
WHERE table_name='mytable';



SELECT * FROM pg_roles WHERE rolname !~ '^pg_';

-- who is super user
SELECT rolname FROM pg_roles WHERE rolsuper;


-- only member of a role and having "admin option" can grant role to another user ?
-- ** do this with superuser 'postgres' **
create role readonly;
grant readonly to myuser3 with admin option;
-- Then, myuser3 can do the grant
grant readonly to myuser2;

-- list all schemas
-- and you will see the schema owner
-- if you are not owner of schema, you can't do ALTER SCHEMA <SCHEMA_NAME> TO ...
SELECT * FROM information_schema.schemata;


grant usage on schema test_schema to myuser2;
ALTER SCHEMA test_schema owner to myuser3;

use quant to create table
transfer owner to api_ro ( this depends if quant is the owner of the table, I failed to do so )


-- transfer table owner to another user
-- the current user has to be owner of that table
-- you transfer to a role which current member is of that role
-- and the new owning user should have CREATE privilege of that schema
