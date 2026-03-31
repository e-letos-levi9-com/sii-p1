-- Setup oracle_fdw extension and connection to Oracle database

-- Create extension
CREATE EXTENSION IF NOT EXISTS oracle_fdw;

-- Create server connection to Oracle
-- Note: Using container name 'oracle-credits-db' as hostname within Docker network
CREATE SERVER oracle_server
  FOREIGN DATA WRAPPER oracle_fdw
  OPTIONS (dbserver '//oracle-credits-db:1521/XEPDB1');

-- Create user mapping
CREATE USER MAPPING FOR postgres
  SERVER oracle_server
  OPTIONS (user 'credits_user', password 'credits_pass');

-- Create schema for foreign tables
CREATE SCHEMA IF NOT EXISTS oracle_movies;

COMMENT ON SCHEMA oracle_movies IS 'Foreign tables connected to Oracle database';

-- Note: IMPORT FOREIGN SCHEMA will be run manually after Oracle is fully initialized
-- Run this manually after both containers are up:
-- IMPORT FOREIGN SCHEMA "CREDITS_USER" FROM SERVER oracle_server INTO oracle_movies;

-- Grant permissions
GRANT USAGE ON SCHEMA oracle_movies TO postgres;
