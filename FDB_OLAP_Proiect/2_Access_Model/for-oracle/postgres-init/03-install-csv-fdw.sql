-- Install file_fdw extension for CSV file access
CREATE EXTENSION IF NOT EXISTS file_fdw;

-- Create file server
CREATE SERVER IF NOT EXISTS csv_server
FOREIGN DATA WRAPPER file_fdw;

-- Create schema for CSV foreign tables
CREATE SCHEMA IF NOT EXISTS csv_data;
COMMENT ON SCHEMA csv_data IS 'Foreign tables for CSV data files';

-- Grant usage on schema
GRANT USAGE ON SCHEMA csv_data TO postgres;

-- Create foreign table for ratings CSV
CREATE FOREIGN TABLE IF NOT EXISTS csv_data.ratings (
    user_id INTEGER,
    movie_id INTEGER,
    rating NUMERIC(2,1),
    timestamp BIGINT
)
SERVER csv_server
OPTIONS (
    filename '/data/ratings.csv',
    format 'csv',
    header 'true',
    delimiter ','
);

COMMENT ON FOREIGN TABLE csv_data.ratings IS 'User ratings from ratings.csv file';

-- Create a view for easier querying with timestamp conversion
CREATE OR REPLACE VIEW csv_data.ratings_with_date AS
SELECT 
    user_id,
    movie_id,
    rating,
    timestamp,
    TO_TIMESTAMP(timestamp) AS rating_date
FROM csv_data.ratings;

COMMENT ON VIEW csv_data.ratings_with_date IS 'Ratings with converted timestamp to datetime';
