#!/bin/bash
# Script to complete the oracle_fdw setup after Oracle is ready

echo "Waiting for Oracle database to be ready..."
sleep 60

echo "Importing foreign schema from Oracle..."
docker exec -i postgres-with-oracle psql -U postgres -d moviesdb <<EOF
IMPORT FOREIGN SCHEMA "CREDITS_USER"
  FROM SERVER oracle_server
  INTO oracle_movies;

GRANT SELECT ON ALL TABLES IN SCHEMA oracle_movies TO postgres;

-- Verify
SELECT tablename FROM pg_tables WHERE schemaname = 'oracle_movies';
EOF

echo "Setup complete!"
