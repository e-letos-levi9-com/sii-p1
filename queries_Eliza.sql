-- 1. MOVIE SUCCESS METRICS
-- Analyze how budget levels correlate with ratings, revenue, and profitability
-- Expected: Higher budget films may have better production but not always better ROI
SELECT 
    CASE 
        WHEN mm.budget < 10000000 THEN 'Low (<$10M)'
        WHEN mm.budget < 50000000 THEN 'Medium ($10M-$50M)'
        WHEN mm.budget < 150000000 THEN 'High ($50M-$150M)'
        ELSE 'Blockbuster (>$150M)'
    END as budget_category,
    COUNT(DISTINCT mm._id) as movie_count,
    ROUND(AVG(r.rating), 2) as avg_user_rating,
    ROUND(AVG(mm.vote_average::numeric), 2) as avg_tmdb_rating,
    ROUND(AVG(mm.budget::numeric/1000000), 1) as avg_budget_millions,
    ROUND(AVG(mm.revenue::numeric/1000000), 1) as avg_revenue_millions,
    ROUND(AVG((mm.revenue - mm.budget)::numeric/mm.budget * 100), 1) as avg_roi_percent
FROM mongo_movies.movies_local mm
JOIN csv_data.ratings_local r ON mm._id = r.movie_id::text
WHERE mm.budget > 100000 AND mm.revenue > 0
GROUP BY budget_category
ORDER BY MIN(mm.budget);

-- 2. TOP PERFORMING ACTORS
-- Identify top-billed actors who consistently deliver profitable, well-rated films
-- Expected: Star actors with proven track records and commercial appeal
SELECT 
    p.name as actor_name,
    COUNT(DISTINCT cm.movie_id) as movies_acted,
    ROUND(AVG(r.rating), 2) as avg_user_rating,
    ROUND(AVG(mm.vote_average::numeric), 2) as avg_tmdb_rating,
    COUNT(DISTINCT r.user_id) as total_user_ratings,
    ROUND(SUM(mm.revenue - mm.budget)::numeric/1000000, 1) as total_profit_millions,
    ROUND(AVG((mm.revenue - mm.budget)::numeric/mm.budget * 100), 1) as avg_roi_percent,
    ROUND(AVG(mm.budget::numeric/1000000), 1) as avg_movie_budget_millions
FROM oracle_movies.people p
JOIN oracle_movies.cast_members cm ON p.person_id = cm.person_id
JOIN mongo_movies.movies_local mm ON cm.movie_id::text = mm._id
JOIN csv_data.ratings_local r ON mm._id = r.movie_id::text
WHERE cm.cast_order < 5
  AND mm.budget > 5000000
  AND mm.revenue > 0
  AND r.rating >= 3.0
GROUP BY p.person_id, p.name
HAVING COUNT(DISTINCT cm.movie_id) >= 10
ORDER BY avg_roi_percent DESC, avg_user_rating DESC
LIMIT 25;

-- 3. DIRECTOR SUCCESS ANALYSIS
-- Rank directors by financial success and audience satisfaction
-- Expected: Directors who balance artistic vision with commercial viability
SELECT 
    p.name as director_name,
    COUNT(DISTINCT crw.movie_id) as movies_directed,
    ROUND(AVG(r.rating), 2) as avg_user_rating,
    ROUND(AVG(mm.vote_average::numeric), 2) as avg_tmdb_rating,
    COUNT(DISTINCT r.user_id) as total_raters,
    ROUND(SUM(mm.revenue)::numeric/1000000, 1) as total_revenue_millions,
    ROUND(SUM(mm.revenue - mm.budget)::numeric/1000000, 1) as total_profit_millions,
    ROUND(AVG((mm.revenue - mm.budget)::numeric/mm.budget * 100), 1) as avg_roi_percent,
    ROUND(MAX(mm.revenue)::numeric/1000000, 1) as biggest_hit_millions
FROM oracle_movies.people p
JOIN oracle_movies.crew_members crw ON p.person_id = crw.person_id
JOIN mongo_movies.movies_local mm ON crw.movie_id::text = mm._id
JOIN csv_data.ratings_local r ON mm._id = r.movie_id::text
WHERE crw.job = 'Director'
  AND mm.budget > 1000000
  AND mm.revenue > 0
GROUP BY p.person_id, p.name
HAVING COUNT(DISTINCT crw.movie_id) >= 5
ORDER BY avg_roi_percent DESC, avg_user_rating DESC
LIMIT 20;
