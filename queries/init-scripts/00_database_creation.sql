CREATE USER campaign_admin WITH PASSWORD 'pwd';
CREATE USER campaign_user WITH PASSWORD 'pwd'; -- the normal user, with read permissions only

CREATE DATABASE campaign_db;

GRANT ALL PRIVILEGES ON DATABASE campaign_db TO campaign_admin;

\c campaign_db

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO campaign_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO campaign_user;