-- 1. GENRE PROFITABILITY ANALYSIS
-- Determine which movie genres offer the best ROI and audience ratings
-- Expected: Action/Adventure may have high revenue but Horror could have better ROI
WITH top_users AS (
    SELECT 
        user_id,
        COUNT(*) as total_ratings,
        AVG(rating) as avg_rating_given
    FROM csv_data.ratings_local
    GROUP BY user_id
    HAVING COUNT(*) >= 2000
    ORDER BY total_ratings DESC
    LIMIT 100
)
SELECT 
    CASE 
        WHEN tu.avg_rating_given < 2.5 THEN 'Harsh Critics (<2.5)'
        WHEN tu.avg_rating_given < 3.5 THEN 'Average Raters (2.5-3.5)'
        WHEN tu.avg_rating_given < 4.0 THEN 'Generous Raters (3.5-4.0)'
        ELSE 'Very Generous (4.0+)'
    END as rater_type,
    COUNT(DISTINCT tu.user_id) as user_count,
    ROUND(AVG(tu.avg_rating_given), 2) as avg_rating_given,
    AVG(tu.total_ratings)::INTEGER as avg_movies_rated,
    ROUND(AVG(mm.budget::numeric/1000000), 1) as avg_movie_budget_millions,
    ROUND(AVG(mm.revenue::numeric/1000000), 1) as avg_movie_revenue_millions,
    COUNT(DISTINCT mm._id) as unique_movies_rated
FROM top_users tu
JOIN csv_data.ratings_local r ON tu.user_id = r.user_id
JOIN mongo_movies.movies_local mm ON r.movie_id::text = mm._id
WHERE mm.budget > 0
GROUP BY rater_type
ORDER BY MIN(tu.avg_rating_given);


-- 2. RUNTIME IMPACT ON SUCCESS
-- Determine the sweet spot for movie length regarding ratings and profitability
-- Expected: 90-120 minutes optimal; too short or too long may hurt performance
SELECT 
    CASE 
        WHEN mm.runtime < 90 THEN 'Short (<90 min)'
        WHEN mm.runtime < 105 THEN 'Standard (90-105 min)'
        WHEN mm.runtime < 120 THEN 'Long (105-120 min)'
        WHEN mm.runtime < 150 THEN 'Very Long (120-150 min)'
        ELSE 'Epic (150+ min)'
    END as runtime_category,
    COUNT(DISTINCT mm._id) as movie_count,
    ROUND(AVG(mm.runtime), 0) as avg_runtime_minutes,
    ROUND(AVG(r.rating), 2) as avg_user_rating,
    ROUND(AVG(mm.vote_average::numeric), 2) as avg_tmdb_rating,
    ROUND(AVG(mm.revenue::numeric/1000000), 1) as avg_revenue_millions,
    ROUND(AVG((mm.revenue - mm.budget)::numeric/mm.budget * 100), 1) as avg_roi_percent,
    COUNT(r.*)::BIGINT as total_user_ratings
FROM mongo_movies.movies_local mm
JOIN csv_data.ratings_local r ON mm._id = r.movie_id::text
WHERE mm.runtime > 0
  AND mm.budget > 1000000
  AND mm.revenue > 0
GROUP BY runtime_category
ORDER BY MIN(mm.runtime);

-- 3. RATING TRENDS OVER TIME
-- Track evolution of movie quality, budgets, and audience engagement by decade
-- Expected: Rising budgets and crew sizes, but not necessarily better ratings
SELECT 
    FLOOR(EXTRACT(YEAR FROM mm.release_date::date) / 10) * 10 as decade,
    COUNT(DISTINCT mm._id) as movies_released,
    ROUND(AVG(r.rating), 2) as avg_user_rating,
    ROUND(AVG(mm.vote_average::numeric), 2) as avg_tmdb_rating,
    ROUND(AVG(mm.budget::numeric/1000000), 1) as avg_budget_millions,
    ROUND(AVG(mm.revenue::numeric/1000000), 1) as avg_revenue_millions,
    COUNT(r.*)::BIGINT as total_user_ratings,
    (COUNT(r.*) / COUNT(DISTINCT mm._id))::INTEGER as avg_ratings_per_movie
FROM mongo_movies.movies_local mm
JOIN csv_data.ratings_local r ON mm._id = r.movie_id::text
WHERE mm.release_date IS NOT NULL 
  AND mm.release_date != ''
  AND EXTRACT(YEAR FROM mm.release_date::date) >= 1970
  AND mm.budget > 0
GROUP BY decade
ORDER BY decade DESC;
