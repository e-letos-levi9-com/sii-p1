-- P3 - Integration and Analytical Model (ROLAP)
-- Consolidation views + Fact views + Dimension views + Analytical views

CREATE SCHEMA IF NOT EXISTS integration_model;

-- Access compatibility views (safe to recreate)
-- Drop existing tables if they exist
DROP TABLE IF EXISTS mongo_movies.movies_local CASCADE;
DROP TABLE IF EXISTS csv_data.ratings_local CASCADE;

CREATE OR REPLACE VIEW mongo_movies.movies_local AS
SELECT
    _id::text AS _id,
    title,
    budget,
    revenue,
    runtime,
    vote_average,
    vote_count,
    popularity,
    NULLIF(release_date, '') AS release_date,
    overview,
    original_language,
    genres,
    production_companies,
    production_countries
FROM mongo_movies.movies;

CREATE OR REPLACE VIEW csv_data.ratings_local AS
SELECT
    user_id,
    movie_id,
    rating,
    timestamp,
    TO_TIMESTAMP(timestamp) AS rating_date
FROM csv_data.ratings;

-- (1) Consolidation layer
CREATE OR REPLACE VIEW integration_model.vw_movie_consolidated AS
WITH ratings_agg AS (
    SELECT
        movie_id::text AS movie_id_text,
        COUNT(*)::bigint AS rating_events,
        COUNT(DISTINCT user_id)::bigint AS unique_raters,
        ROUND(AVG(rating)::numeric, 2) AS avg_user_rating
    FROM csv_data.ratings_local
    GROUP BY movie_id::text
),
cast_agg AS (
    SELECT
        movie_id::text AS movie_id_text,
        COUNT(*)::bigint AS cast_size
    FROM oracle_movies.cast_members
    GROUP BY movie_id::text
),
crew_agg AS (
    SELECT
        movie_id::text AS movie_id_text,
        COUNT(*)::bigint AS crew_size
    FROM oracle_movies.crew_members
    GROUP BY movie_id::text
)
SELECT
    mm._id::text AS movie_id_text,
    mm.title,
    mm.original_language,
    CASE
        WHEN mm.release_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN mm.release_date::date
        ELSE NULL
    END AS release_date_d,
    mm.budget,
    mm.revenue,
    mm.runtime,
    mm.vote_average,
    mm.vote_count,
    mm.popularity,
    COALESCE(ra.rating_events, 0) AS rating_events,
    COALESCE(ra.unique_raters, 0) AS unique_raters,
    ra.avg_user_rating,
    COALESCE(ca.cast_size, 0) AS cast_size,
    COALESCE(cra.crew_size, 0) AS crew_size
FROM mongo_movies.movies_local mm
LEFT JOIN ratings_agg ra ON ra.movie_id_text = mm._id::text
LEFT JOIN cast_agg ca ON ca.movie_id_text = mm._id::text
LEFT JOIN crew_agg cra ON cra.movie_id_text = mm._id::text;

CREATE OR REPLACE VIEW integration_model.vw_actor_movie_consolidated AS
WITH ratings_agg AS (
    SELECT
        movie_id::text AS movie_id_text,
        COUNT(*)::bigint AS rating_events,
        ROUND(AVG(rating)::numeric, 2) AS avg_user_rating
    FROM csv_data.ratings_local
    GROUP BY movie_id::text
)
SELECT
    p.person_id,
    p.name AS actor_name,
    cm.movie_id,
    mm._id::text AS movie_id_text,
    mm.title,
    cm.cast_order,
    mm.budget,
    mm.revenue,
    ra.rating_events,
    ra.avg_user_rating
FROM oracle_movies.cast_members cm
JOIN oracle_movies.people p ON p.person_id = cm.person_id
JOIN mongo_movies.movies_local mm ON cm.movie_id::text = mm._id::text
LEFT JOIN ratings_agg ra ON ra.movie_id_text = mm._id::text;

-- (2) ROLAP schema - fact views
CREATE OR REPLACE VIEW integration_model.fact_movie_performance AS
SELECT
    movie_id_text,
    title,
    original_language,
    release_date_d,
    budget,
    revenue,
    runtime,
    vote_average,
    vote_count,
    popularity,
    rating_events,
    unique_raters,
    avg_user_rating,
    cast_size,
    crew_size,
    (revenue - budget) AS profit,
    CASE
        WHEN budget IS NOT NULL AND budget > 0 AND revenue IS NOT NULL
            THEN ROUND(((revenue - budget)::numeric / budget::numeric) * 100, 2)
        ELSE NULL
    END AS roi_percent
FROM integration_model.vw_movie_consolidated;

CREATE OR REPLACE VIEW integration_model.fact_person_movie_performance AS
SELECT
    person_id,
    actor_name,
    movie_id,
    movie_id_text,
    title,
    cast_order,
    budget,
    revenue,
    (revenue - budget) AS profit,
    CASE
        WHEN budget IS NOT NULL AND budget > 0 AND revenue IS NOT NULL
            THEN ROUND(((revenue - budget)::numeric / budget::numeric) * 100, 2)
        ELSE NULL
    END AS roi_percent,
    rating_events,
    avg_user_rating
FROM integration_model.vw_actor_movie_consolidated;

-- (2) ROLAP schema - dimension views
CREATE OR REPLACE VIEW integration_model.dim_movie AS
SELECT
    movie_id_text,
    title,
    COALESCE(NULLIF(original_language, ''), 'unknown') AS language,
    release_date_d,
    EXTRACT(YEAR FROM release_date_d)::int AS release_year,
    (FLOOR(EXTRACT(YEAR FROM release_date_d) / 10) * 10)::int AS release_decade,
    CASE
        WHEN budget IS NULL OR budget <= 0 THEN 'unknown'
        WHEN budget < 10000000 THEN 'low'
        WHEN budget < 50000000 THEN 'medium'
        WHEN budget < 150000000 THEN 'high'
        ELSE 'blockbuster'
    END AS budget_bucket,
    CASE
        WHEN runtime IS NULL OR runtime <= 0 THEN 'unknown'
        WHEN runtime < 90 THEN 'short'
        WHEN runtime < 120 THEN 'standard'
        WHEN runtime < 150 THEN 'long'
        ELSE 'epic'
    END AS runtime_bucket
FROM integration_model.vw_movie_consolidated;

CREATE OR REPLACE VIEW integration_model.dim_person AS
WITH cast_credits AS (
    SELECT person_id, COUNT(*)::bigint AS cast_credit_count
    FROM oracle_movies.cast_members
    GROUP BY person_id
),
crew_credits AS (
    SELECT person_id, COUNT(*)::bigint AS crew_credit_count
    FROM oracle_movies.crew_members
    GROUP BY person_id
)
SELECT
    p.person_id,
    p.name,
    p.gender,
    COALESCE(cc.cast_credit_count, 0) AS cast_credit_count,
    COALESCE(cr.crew_credit_count, 0) AS crew_credit_count
FROM oracle_movies.people p
LEFT JOIN cast_credits cc ON cc.person_id = p.person_id
LEFT JOIN crew_credits cr ON cr.person_id = p.person_id;

CREATE OR REPLACE VIEW integration_model.dim_time_release AS
SELECT DISTINCT
    release_date_d,
    EXTRACT(YEAR FROM release_date_d)::int AS year,
    EXTRACT(QUARTER FROM release_date_d)::int AS quarter,
    EXTRACT(MONTH FROM release_date_d)::int AS month,
    (FLOOR(EXTRACT(YEAR FROM release_date_d) / 10) * 10)::int AS decade
FROM integration_model.vw_movie_consolidated
WHERE release_date_d IS NOT NULL;

-- (2) OLAP analytical views
CREATE OR REPLACE VIEW integration_model.av_budget_runtime_rollup AS
SELECT
    d.budget_bucket,
    d.runtime_bucket,
    COUNT(*)::bigint AS movie_count,
    ROUND(AVG(f.avg_user_rating)::numeric, 2) AS avg_user_rating,
    ROUND(AVG(f.roi_percent)::numeric, 2) AS avg_roi_percent,
    ROUND(SUM(f.revenue)::numeric / 1000000, 2) AS total_revenue_musd
FROM integration_model.fact_movie_performance f
JOIN integration_model.dim_movie d ON d.movie_id_text = f.movie_id_text
WHERE f.revenue IS NOT NULL AND f.revenue > 0
GROUP BY ROLLUP (d.budget_bucket, d.runtime_bucket);

CREATE OR REPLACE VIEW integration_model.av_language_decade_cube AS
SELECT
    d.language,
    d.release_decade,
    COUNT(*)::bigint AS movie_count,
    ROUND(AVG(f.avg_user_rating)::numeric, 2) AS avg_user_rating,
    ROUND(AVG(f.roi_percent)::numeric, 2) AS avg_roi_percent,
    ROUND(SUM(f.revenue)::numeric / 1000000, 2) AS total_revenue_musd
FROM integration_model.fact_movie_performance f
JOIN integration_model.dim_movie d ON d.movie_id_text = f.movie_id_text
WHERE f.revenue IS NOT NULL AND f.revenue > 0
GROUP BY CUBE (d.language, d.release_decade);

CREATE OR REPLACE VIEW integration_model.av_top_actors AS
WITH actor_stats AS (
    SELECT
        person_id,
        actor_name,
        COUNT(DISTINCT movie_id_text)::bigint AS movie_count,
        ROUND(AVG(avg_user_rating)::numeric, 2) AS avg_user_rating,
        ROUND(AVG(roi_percent)::numeric, 2) AS avg_roi_percent,
        COALESCE(SUM(rating_events), 0)::bigint AS total_rating_events
    FROM integration_model.fact_person_movie_performance
    WHERE avg_user_rating IS NOT NULL
    GROUP BY person_id, actor_name
    HAVING COUNT(DISTINCT movie_id_text) >= 5
),
ranked AS (
    SELECT
        *,
        DENSE_RANK() OVER (ORDER BY avg_user_rating DESC, avg_roi_percent DESC) AS actor_rank
    FROM actor_stats
)
SELECT
    actor_rank,
    person_id,
    actor_name,
    movie_count,
    avg_user_rating,
    avg_roi_percent,
    total_rating_events
FROM ranked
WHERE actor_rank <= 50;
