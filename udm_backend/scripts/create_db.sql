-- One-time local database setup for UDM. PostgreSQL 16.
--
-- The role password is never stored in this repository: pass it in from the
-- UDM_DB_PASSWORD value you already have in the git-ignored .env file.
--
--   "C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres ^
--     -v udm_password="paste-UDM_DB_PASSWORD-here" ^
--     -f udm_backend\scripts\create_db.sql
--
-- You will be prompted for the postgres superuser password chosen at install
-- time. Re-running is safe: existing objects are updated, not recreated.

-- Undefined-variable reference below aborts the script if -v udm_password is missing.

SELECT format('CREATE ROLE udm WITH LOGIN CREATEDB PASSWORD %L', :'udm_password') AS stmt
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'udm')\gexec

SELECT format('ALTER ROLE udm WITH LOGIN CREATEDB PASSWORD %L', :'udm_password') AS stmt
WHERE EXISTS (SELECT FROM pg_roles WHERE rolname = 'udm')\gexec

SELECT 'CREATE DATABASE udm OWNER udm'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'udm')\gexec

ALTER DATABASE udm OWNER TO udm;

-- No schema grant is needed: `udm` owns the database, and from PostgreSQL 15
-- onward the public schema belongs to whoever owns the database.
