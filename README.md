# Multi-Database Integration Project

A comprehensive database integration project that connects **Oracle**, **MongoDB**, and **CSV files** through a central **PostgreSQL** hub using Foreign Data Wrappers (FDW).

## Architecture

```
PostgreSQL Container (Central Hub - port 5433)
    │
    ├─> oracle_fdw → Oracle XE 21c (port 1521)
    │    └─> Credits data (normalized)
    │         ├─ movies (45,432 movies)
    │         ├─ people (353,343 unique people)
    │         ├─ cast_members (652,330 relationships)
    │         └─ crew_members (609,300 relationships)
    │
    ├─> multicorn (Python FDW) → MongoDB 7 (port 27017)
    │    └─> Movie metadata
    │         ├─ movies (45,433 with budget, revenue, ratings)
    │         ├─ genres (20 unique genres)
    │         ├─ production_companies (23,692 companies)
    │         └─ countries (161 countries)
    │
    └─> file_fdw → CSV Files (read-only)
         └─> ratings.csv (26,024,289 user ratings)
```

## Features

✅ **Unified SQL Access**: Query all data sources using standard SQL  
✅ **Foreign Data Wrappers**: No data duplication, live queries to source databases  
✅ **Cross-Database Joins**: Combine Oracle credits, MongoDB metadata, and CSV ratings in one query  
✅ **Docker Containerized**: Complete environment reproducible with Docker Compose  
✅ **Python-based MongoDB FDW**: Uses multicorn for reliable MongoDB connectivity  
✅ **26M+ Ratings**: Direct CSV access without import overhead

## Data Sources

### Oracle Database (Credits)

- **Source**: credits.csv (182 MB)
- **Schema**: Normalized with foreign keys
- **Tables**: movies, people, cast_members, crew_members
- **Size**: 1.2M+ relationships

### MongoDB (Movie Metadata)

- **Source**: movies_metadata.csv (33 MB)
- **Schema**: Hybrid (embedded + normalized)
- **Collections**: movies, genres, production_companies, countries
- **Data**: Budget, revenue, ratings, release dates

### CSV Files (User Ratings)

- **Source**: ratings.csv (677 MB)
- **Access**: Direct file read via file_fdw
- **Records**: 26,024,289 user ratings
- **Fields**: user_id, movie_id, rating, timestamp

## Quick Start

See **[SETUP.md](SETUP.md)** for complete step-by-step instructions.

```powershell
# 1. Start all containers
docker compose -f docker-compose-postgresql.yml up -d

# 2. Import Oracle data
python import_data.py

# 3. Import MongoDB data
cd ..\for-mongo
python import_movies.py

# 4. Import Oracle foreign schema
docker exec -i postgres-with-oracle psql -U postgres -d moviesdb < import-foreign-schemas.sql

# 5. Query all three sources!
docker exec -it postgres-with-oracle psql -U postgres -d moviesdb
```

## Example Queries

### Cross-Database Query (All Three Sources)

```sql
-- Top rated movies with cast info and user ratings
SELECT
    mm.title,
    mm.budget,
    ROUND(AVG(r.rating), 2) as avg_user_rating,
    COUNT(DISTINCT r.user_id) as num_raters,
    (SELECT COUNT(*) FROM oracle_movies.cast_members
     WHERE movie_id::text = mm._id) as cast_size
FROM mongo_movies.movies mm
JOIN csv_data.ratings r ON mm._id = r.movie_id::text
WHERE mm.budget > 100000000
GROUP BY mm._id, mm.title, mm.budget
HAVING COUNT(DISTINCT r.user_id) >= 500
ORDER BY avg_user_rating DESC
LIMIT 10;
```

### Actor Performance with User Ratings

```sql
-- Best rated actors based on user ratings
SELECT
    p.name as actor_name,
    COUNT(DISTINCT cm.movie_id) as movie_count,
    ROUND(AVG(r.rating), 2) as avg_user_rating,
    COUNT(DISTINCT r.user_id) as total_raters
FROM oracle_movies.people p
JOIN oracle_movies.cast_members cm ON p.person_id = cm.person_id
JOIN csv_data.ratings r ON cm.movie_id = r.movie_id
JOIN mongo_movies.movies mm ON cm.movie_id::text = mm._id
WHERE cm."order" < 3  -- Top 3 billed actors
GROUP BY p.name
HAVING COUNT(DISTINCT cm.movie_id) >= 5
ORDER BY avg_user_rating DESC
LIMIT 20;
```

More examples in **[all-sources-queries.sql](all-sources-queries.sql)**.

## Database Schemas

### PostgreSQL Schemas

- **oracle_movies**: Foreign tables to Oracle database
- **mongo_movies**: Foreign tables to MongoDB collections
- **csv_data**: Foreign tables to CSV files

### Oracle Schema (CREDITS_USER)

```sql
movies            (movie_id PK)
people            (person_id PK, name, gender, profile_path)
cast_members      (cast_id PK, movie_id FK, person_id FK, character_name, cast_order)
crew_members      (crew_id PK, movie_id FK, person_id FK, department, job)
```

### MongoDB Schema (moviesdb)

```javascript
movies {
  _id: movie_id,
  title, budget, revenue, runtime,
  vote_average, vote_count, popularity,
  release_date, overview,
  genres: [{ id, name }],
  production_companies: [{ id, name }],
  production_countries: [{ iso_3166_1, name }]
}
```

### CSV Schema

```sql
csv_data.ratings (
    user_id INTEGER,
    movie_id INTEGER,
    rating NUMERIC(2,1),
    timestamp BIGINT
)
```

## Connection Details

### PostgreSQL (Central Hub)

- **Host**: localhost | **Port**: 5433
- **Database**: moviesdb | **User**: postgres | **Password**: postgres123

### Oracle (Direct Access)

- **Host**: localhost | **Port**: 1521
- **Service**: XEPDB1 | **User**: credits_user | **Password**: credits_pass

### MongoDB (Direct Access)

- **Host**: localhost | **Port**: 27017
- **Database**: moviesdb | **User**: admin | **Password**: admin123

## Project Structure

```
for-oracle/
├── docker-compose-postgresql.yml   # Main orchestration file
├── Dockerfile.postgres-oracle      # PostgreSQL with all FDWs
├── import_data.py                  # Oracle data import script
├── mongo_fdw.py                    # Python MongoDB FDW
├── import-foreign-schemas.sql      # Import Oracle schema
├── all-sources-queries.sql         # Example queries
├── SETUP.md                        # Setup instructions
└── postgres-init/                  # Auto-run SQL scripts
    ├── 01-install-oracle-fdw.sql
    ├── 02-install-multicorn-mongo.sql
    └── 03-install-csv-fdw.sql

for-mongo/
├── import_movies.py                # MongoDB import
└── verify_mongo.py                 # Connection test

data/
├── credits.csv                     # 182 MB
├── movies_metadata.csv             # 33 MB
└── ratings.csv                     # 677 MB (not in git)
```

## Technology Stack

- **PostgreSQL 16**: Central hub with FDW support
- **Oracle XE 21c**: Relational credits data
- **MongoDB 7**: Document-based metadata
- **Python 3.13**: Import scripts & MongoDB FDW
- **Docker Compose**: Container orchestration
- **oracle_fdw 2.6.0**: Oracle Foreign Data Wrapper
- **multicorn2**: Python FDW framework
- **file_fdw**: CSV file access

## Troubleshooting

### Check Container Status

```powershell
docker ps -a
docker compose -f docker-compose-postgresql.yml logs
```

### Test Connections

```powershell
# PostgreSQL
docker exec postgres-with-oracle psql -U postgres -d moviesdb -c "\dx"

# Oracle through PostgreSQL
docker exec postgres-with-oracle psql -U postgres -d moviesdb -c "SELECT COUNT(*) FROM oracle_movies.movies;"

# MongoDB through PostgreSQL
docker exec postgres-with-oracle psql -U postgres -d moviesdb -c "SELECT COUNT(*) FROM mongo_movies.movies;"

# CSV ratings
docker exec postgres-with-oracle psql -U postgres -d moviesdb -c "SELECT COUNT(*) FROM csv_data.ratings;"
```

### Reset Everything

```powershell
docker compose -f docker-compose-postgresql.yml down -v
docker compose -f docker-compose-postgresql.yml build --no-cache
docker compose -f docker-compose-postgresql.yml up -d
```

## License

Academic project using TMDb dataset for educational purposes.
