-- Import Oracle foreign schema
IMPORT FOREIGN SCHEMA "CREDITS_USER" FROM SERVER oracle_server INTO oracle_movies;

-- Verify tables
\det+ oracle_movies.*
