-- Install multicorn extension
CREATE EXTENSION IF NOT EXISTS multicorn;

-- Create MongoDB foreign server
CREATE SERVER IF NOT EXISTS mongodb_server
FOREIGN DATA WRAPPER multicorn
OPTIONS (
    wrapper 'mongo_fdw.MongoFDW'
);

-- Create user mapping for MongoDB
CREATE USER MAPPING IF NOT EXISTS FOR postgres
SERVER mongodb_server
OPTIONS (
    username 'admin',
    password 'admin123'
);

-- Create schema for MongoDB foreign tables
CREATE SCHEMA IF NOT EXISTS mongo_movies;
COMMENT ON SCHEMA mongo_movies IS 'Foreign tables for MongoDB movies database';

-- Grant usage on schema
GRANT USAGE ON SCHEMA mongo_movies TO postgres;

-- Create foreign table for movies collection
CREATE FOREIGN TABLE IF NOT EXISTS mongo_movies.movies (
    _id TEXT,
    title TEXT,
    budget BIGINT,
    revenue BIGINT,
    runtime INTEGER,
    vote_average FLOAT,
    vote_count INTEGER,
    popularity FLOAT,
    release_date TEXT,
    overview TEXT,
    original_language TEXT,
    genres TEXT,  -- JSON array
    production_companies TEXT,  -- JSON array
    production_countries TEXT  -- JSON array
)
SERVER mongodb_server
OPTIONS (
    host 'mongodb-movies',
    port '27017',
    database 'moviesdb',
    collection 'movies'
);

-- Create foreign table for genres collection
CREATE FOREIGN TABLE IF NOT EXISTS mongo_movies.genres (
    _id INTEGER,
    name TEXT
)
SERVER mongodb_server
OPTIONS (
    host 'mongodb-movies',
    port '27017',
    database 'moviesdb',
    collection 'genres'
);

-- Create foreign table for production_companies collection
CREATE FOREIGN TABLE IF NOT EXISTS mongo_movies.production_companies (
    _id INTEGER,
    name TEXT
)
SERVER mongodb_server
OPTIONS (
    host 'mongodb-movies',
    port '27017',
    database 'moviesdb',
    collection 'production_companies'
);

-- Create foreign table for production_countries collection (stored as 'countries' in MongoDB)
CREATE FOREIGN TABLE IF NOT EXISTS mongo_movies.production_countries (
    _id TEXT,
    name TEXT
)
SERVER mongodb_server
OPTIONS (
    host 'mongodb-movies',
    port '27017',
    database 'moviesdb',
    collection 'countries'
);

COMMENT ON FOREIGN TABLE mongo_movies.movies IS 'Movies collection from MongoDB';
COMMENT ON FOREIGN TABLE mongo_movies.genres IS 'Genres collection from MongoDB';
COMMENT ON FOREIGN TABLE mongo_movies.production_companies IS 'Production companies from MongoDB';
COMMENT ON FOREIGN TABLE mongo_movies.production_countries IS 'Production countries from MongoDB';
