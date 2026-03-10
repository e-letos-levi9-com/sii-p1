-- ============================================================================
-- SQL*Loader Control File for TMDB Movies
-- ============================================================================

OPTIONS (ROWS=500, BINDSIZE=20000000, READSIZE=20000000, DIRECT=TRUE)
LOAD DATA
INFILE '/tmp/tmdb_5000_movies.csv'
BADFILE '/tmp/movies_bad.log'
DISCARDFILE '/tmp/movies_discard.log'
APPEND
INTO TABLE movies
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
TRAILING NULLCOLS
(
    budget,
    genres CHAR(4000),
    homepage,
    id,
    keywords CHAR(4000),
    original_language,
    original_title,
    overview CHAR(4000),
    popularity,
    production_companies CHAR(4000),
    production_countries CHAR(4000),
    release_date DATE "YYYY-MM-DD",
    revenue,
    runtime,
    spoken_languages CHAR(4000),
    status,
    tagline,
    title,
    vote_average,
    vote_count
)
