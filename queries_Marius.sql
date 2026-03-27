-- 1. POPULARITY VS QUALITY
-- Investigate if popular movies (many ratings) are also high quality
-- Expected: Blockbusters get more ratings but smaller films may have higher avg ratings
WITH movie_metrics AS (
    SELECT 
        mm._id,
        mm.title,
        mm.budget,
        mm.revenue,
        AVG(r.rating) as user_rating,
        COUNT(DISTINCT r.user_id) as rating_count
    FROM mongo_movies.movies_local mm
    JOIN csv_data.ratings_local r ON mm._id = r.movie_id::text
    WHERE mm.budget > 5000000
    GROUP BY mm._id, mm.title, mm.budget, mm.revenue
)
SELECT 
    CASE 
        WHEN rating_count < 100 THEN 'Niche (<100 ratings)'
        WHEN rating_count < 500 THEN 'Limited (100-500)'
        WHEN rating_count < 2000 THEN 'Popular (500-2K)'
        WHEN rating_count < 10000 THEN 'Very Popular (2K-10K)'
        ELSE 'Blockbuster (10K+)'
    END as popularity_tier,
    COUNT(*) as movie_count,
    ROUND(AVG(user_rating), 2) as avg_user_rating,
    AVG(rating_count)::INTEGER as avg_ratings_per_movie,
    ROUND(AVG(revenue::numeric/1000000), 1) as avg_revenue_millions,
    ROUND(AVG((revenue - budget)::numeric/budget * 100), 1) as avg_roi_percent
FROM movie_metrics
WHERE revenue > 0
GROUP BY popularity_tier
ORDER BY MIN(rating_count);


-- 2. LANGUAGE/COUNTRY MARKET PERFORMANCE
-- Identify which languages/countries produce the most profitable and well-rated films
-- Expected: English dominates revenue, but other markets may show strong ROI
SELECT 
    COALESCE(NULLIF(mm.original_language, ''), 'Unknown') as language,
    COUNT(DISTINCT mm._id) as movie_count,
    ROUND(AVG(r.rating), 2) as avg_user_rating,
    COUNT(DISTINCT r.user_id) as total_raters,
    ROUND(AVG(mm.budget::numeric/1000000), 1) as avg_budget_millions,
    ROUND(AVG(mm.revenue::numeric/1000000), 1) as avg_revenue_millions,
    ROUND(SUM(mm.revenue)::numeric/1000000, 1) as total_revenue_millions,
    ROUND(AVG((mm.revenue - mm.budget)::numeric/mm.budget * 100), 1) as avg_roi_percent
FROM mongo_movies.movies_local mm
JOIN csv_data.ratings_local r ON mm._id = r.movie_id::text
WHERE mm.budget > 1000000
  AND mm.revenue > 0
GROUP BY mm.original_language
HAVING COUNT(DISTINCT mm._id) >= 20
ORDER BY total_revenue_millions DESC
LIMIT 15;

-- 3. RELEASE MONTH STRATEGY ANALYSIS
-- Determine optimal release months for maximizing revenue and audience engagement
-- Expected: Summer and holiday seasons perform best, January slowest
SELECT 
    EXTRACT(MONTH FROM mm.release_date::date) as release_month,
    TO_CHAR(TO_DATE(EXTRACT(MONTH FROM mm.release_date::date)::text, 'MM'), 'Month') as month_name,
    COUNT(DISTINCT mm._id) as movies_released,
    ROUND(AVG(r.rating), 2) as avg_user_rating,
    COUNT(DISTINCT r.user_id) as total_raters,
    ROUND(AVG(mm.revenue::numeric/1000000), 1) as avg_revenue_millions,
    ROUND(SUM(mm.revenue)::numeric/1000000, 1) as total_revenue_millions,
    ROUND(AVG((mm.revenue - mm.budget)::numeric/mm.budget * 100), 1) as avg_roi_percent,
    ROUND(MAX(mm.revenue)::numeric/1000000, 1) as highest_grossing_millions
FROM mongo_movies.movies_local mm
JOIN csv_data.ratings_local r ON mm._id = r.movie_id::text
WHERE mm.release_date IS NOT NULL 
  AND mm.release_date != ''
  AND mm.budget > 5000000
  AND mm.revenue > 0
  AND EXTRACT(YEAR FROM mm.release_date::date) >= 1990
GROUP BY release_month
ORDER BY release_month;
