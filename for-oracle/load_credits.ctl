-- ============================================================================
-- SQL*Loader Control File for TMDB Credits
-- ============================================================================

OPTIONS (ROWS=500, BINDSIZE=20000000, READSIZE=20000000, DIRECT=TRUE)
LOAD DATA
INFILE '/tmp/tmdb_5000_credits.csv'
BADFILE '/tmp/credits_bad.log'
DISCARDFILE '/tmp/credits_discard.log'
APPEND
INTO TABLE credits
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
    movie_id,
    title,
    cast CHAR(40000),
    crew CHAR(40000)
)
