-- Create normalized schema for movie credits database
-- This script runs during container initialization

-- Connect as credits_user to create objects in their schema
CONNECT credits_user/credits_pass@XEPDB1

-- Table for movies
CREATE TABLE movies (
    movie_id NUMBER PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table for people (actors and crew members)
CREATE TABLE people (
    person_id NUMBER PRIMARY KEY,
    name VARCHAR2(200) NOT NULL,
    gender NUMBER DEFAULT 0,
    profile_path VARCHAR2(500)
);

CREATE UNIQUE INDEX idx_people_id ON people(person_id);
CREATE INDEX idx_people_name ON people(name);

-- Table for cast (actors in movies)
CREATE TABLE cast_members (
    cast_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    movie_id NUMBER NOT NULL,
    person_id NUMBER NOT NULL,
    character_name VARCHAR2(500),
    credit_id VARCHAR2(100),
    cast_order NUMBER,
    CONSTRAINT fk_cast_movie FOREIGN KEY (movie_id) REFERENCES movies(movie_id),
    CONSTRAINT fk_cast_person FOREIGN KEY (person_id) REFERENCES people(person_id)
);

CREATE INDEX idx_cast_movie ON cast_members(movie_id);
CREATE INDEX idx_cast_person ON cast_members(person_id);
CREATE INDEX idx_cast_credit ON cast_members(credit_id);

-- Table for crew (crew members on movies)
CREATE TABLE crew_members (
    crew_id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    movie_id NUMBER NOT NULL,
    person_id NUMBER NOT NULL,
    department VARCHAR2(100),
    job VARCHAR2(200),
    credit_id VARCHAR2(100),
    CONSTRAINT fk_crew_movie FOREIGN KEY (movie_id) REFERENCES movies(movie_id),
    CONSTRAINT fk_crew_person FOREIGN KEY (person_id) REFERENCES people(person_id)
);

CREATE INDEX idx_crew_movie ON crew_members(movie_id);
CREATE INDEX idx_crew_person ON crew_members(person_id);
CREATE INDEX idx_crew_department ON crew_members(department);
CREATE INDEX idx_crew_job ON crew_members(job);
CREATE INDEX idx_crew_credit ON crew_members(credit_id);

-- Create some useful views
CREATE OR REPLACE VIEW movie_cast_details AS
SELECT 
    m.movie_id,
    p.person_id,
    p.name,
    c.character_name,
    c.cast_order,
    p.gender,
    p.profile_path
FROM movies m
JOIN cast_members c ON m.movie_id = c.movie_id
JOIN people p ON c.person_id = p.person_id
ORDER BY m.movie_id, c.cast_order;

CREATE OR REPLACE VIEW movie_crew_details AS
SELECT 
    m.movie_id,
    p.person_id,
    p.name,
    cr.department,
    cr.job,
    p.gender,
    p.profile_path
FROM movies m
JOIN crew_members cr ON m.movie_id = cr.movie_id
JOIN people p ON cr.person_id = p.person_id
ORDER BY m.movie_id, cr.department, cr.job;

COMMIT;
