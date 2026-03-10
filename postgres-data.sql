-- Drop tables if they exist
DROP TABLE IF EXISTS tags CASCADE;
DROP TABLE IF EXISTS ratings CASCADE;
DROP TABLE IF EXISTS links CASCADE;
DROP TABLE IF EXISTS movies CASCADE;

-- Create movies table
CREATE TABLE movies (
    movieId INTEGER PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    genres VARCHAR(255)
);

-- Create links table
CREATE TABLE links (
    movieId INTEGER PRIMARY KEY,
    imdbId VARCHAR(10),
    tmdbId INTEGER,
    FOREIGN KEY (movieId) REFERENCES movies(movieId) ON DELETE CASCADE
);

-- Create ratings table
CREATE TABLE ratings (
    userId INTEGER NOT NULL,
    movieId INTEGER NOT NULL,
    rating DECIMAL(2,1) NOT NULL CHECK (rating >= 0 AND rating <= 5),
    timestamp BIGINT NOT NULL,
    PRIMARY KEY (userId, movieId),
    FOREIGN KEY (movieId) REFERENCES movies(movieId) ON DELETE CASCADE
);

-- Create tags table
CREATE TABLE tags (
    userId INTEGER NOT NULL,
    movieId INTEGER NOT NULL,
    tag VARCHAR(255) NOT NULL,
    timestamp BIGINT NOT NULL,
    FOREIGN KEY (movieId) REFERENCES movies(movieId) ON DELETE CASCADE
);

-- Create indexes for better query performance
CREATE INDEX idx_ratings_userid ON ratings(userId);
CREATE INDEX idx_ratings_movieid ON ratings(movieId);
CREATE INDEX idx_ratings_rating ON ratings(rating);
CREATE INDEX idx_tags_userid ON tags(userId);
CREATE INDEX idx_tags_movieid ON tags(movieId);
CREATE INDEX idx_tags_tag ON tags(tag);
CREATE INDEX idx_movies_title ON movies(title);

-- Add comments to tables
COMMENT ON TABLE movies IS 'Contains movie information including title and genres';
COMMENT ON TABLE links IS 'Links to external movie databases (IMDB and TMDB)';
COMMENT ON TABLE ratings IS 'User ratings for movies';
COMMENT ON TABLE tags IS 'User-generated tags for movies';

-- Add comments to columns
COMMENT ON COLUMN movies.movieId IS 'Unique identifier for each movie';
COMMENT ON COLUMN movies.title IS 'Movie title with year in parentheses';
COMMENT ON COLUMN movies.genres IS 'Pipe-separated list of genres';
COMMENT ON COLUMN ratings.rating IS 'Rating value from 0 to 5 in 0.5 increments';
COMMENT ON COLUMN ratings.timestamp IS 'Unix timestamp of when the rating was created';
COMMENT ON COLUMN tags.timestamp IS 'Unix timestamp of when the tag was created';

-- Verify data import counts
SELECT 'Movies imported: ' || COUNT(*) AS count FROM movies;
SELECT 'Links imported: ' || COUNT(*) AS count FROM links;
SELECT 'Ratings imported: ' || COUNT(*) AS count FROM ratings;
SELECT 'Tags imported: ' || COUNT(*) AS count FROM tags;

