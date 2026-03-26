# Setup Instructions

Complete step-by-step guide to set up the multi-database integration project from scratch.

## Prerequisites

- **Docker Desktop** installed and running
- **Python 3.8+** installed
- **Git** (optional, if cloning repository)
- At least **10 GB** free disk space
- **CSV data files** in the `data/` directory:
  - `credits.csv` (182 MB)
  - `movies_metadata.csv` (33 MB)
  - `ratings.csv` (677 MB)

## Step-by-Step Setup

### Step 1: Build PostgreSQL Image with FDWs

Build the custom PostgreSQL image that includes Oracle FDW, MongoDB FDW (multicorn), and file FDW.

**⏱️ Time: 10-15 minutes** (downloads and compiles extensions)

```powershell
# Navigate to the for-oracle directory
cd for-oracle

# Build the PostgreSQL image with all extensions
docker compose -f docker-compose-postgresql.yml build --no-cache postgres-db
```

**What this does:**

- Installs PostgreSQL 16
- Downloads and installs Oracle Instant Client 21.15
- Compiles oracle_fdw from source
- Installs Python 3.13 and pymongo
- Compiles multicorn2 (Python FDW framework)
- Copies custom mongo_fdw.py wrapper

### Step 2: Start All Containers

Start PostgreSQL, Oracle, and MongoDB containers on a shared network.

**⏱️ Time: ~60 seconds**

```powershell
# Start all three containers
docker compose -f docker-compose-postgresql.yml up -d

# Check status
docker ps

# You should see 3 containers:
# - postgres-with-oracle (PostgreSQL)
# - oracle-credits-db (Oracle XE)
# - mongodb-movies (MongoDB)
```

**Wait for initialization:**

```powershell
# Monitor logs (Ctrl+C to exit)
docker compose -f docker-compose-postgresql.yml logs -f

# Wait for these messages:
# PostgreSQL: "database system is ready to accept connections"
# Oracle: "DATABASE IS READY TO USE!"
# MongoDB: "Waiting for connections"
```

### Step 3: Verify Container Health

```powershell
# Check all containers are healthy
docker ps --format "table {{.Names}}\t{{.Status}}"

# All should show "Up X seconds (healthy)" or "Up X seconds"
```

### Step 4: Import Oracle Data (Credits)

Import the normalized credits data into Oracle.

**⏱️ Time: 10-15 minutes** (parses and inserts 45K movies with cast/crew)

```powershell
# Make sure you're in for-oracle directory
cd for-oracle

# Run the Oracle import script
python import_data.py

# You'll see progress every 100 movies:
# Progress: 100 movies, 1234 people, 5678 cast members, 4321 crew members
# Progress: 200 movies, 2345 people, 11234 cast members, 8654 crew members
# ...
# Import complete!
```

**Expected results:**

- ✅ 45,432 movies imported
- ✅ 353,343 unique people
- ✅ 652,330 cast relationships
- ✅ 609,300 crew relationships

### Step 5: Import MongoDB Data (Movie Metadata)

Import movie metadata with budget, revenue, and ratings into MongoDB.

**⏱️ Time: 2-3 minutes**

```powershell
# Navigate to for-mongo directory
cd ..\for-mongo

# Set MongoDB credentials and run import
$env:MONGO_USER='admin'
$env:MONGO_PASS='admin123'
python import_movies.py

# You'll see:
# Connecting to MongoDB...
# Clearing existing data...
# Reading CSV file: ..\data\movies_metadata.csv
# Imported 1000 movies...
# Imported 2000 movies...
# ...
# Import Complete!
```

**Expected results:**

- ✅ 45,433 movies imported
- ✅ 20 unique genres
- ✅ 23,692 production companies
- ✅ 161 countries

### Step 6: Import Oracle Foreign Schema to PostgreSQL

Create foreign tables in PostgreSQL that point to Oracle tables.

```powershell
# Navigate back to for-oracle
cd ..\for-oracle

# Import Oracle schema
docker exec -i postgres-with-oracle psql -U postgres -d moviesdb < import-foreign-schemas.sql

# You should see:
# IMPORT FOREIGN SCHEMA
# List of foreign tables
#     Schema     |       Table
# ---------------+--------------------
#  oracle_movies | cast_members
#  oracle_movies | crew_members
#  oracle_movies | movies
#  oracle_movies | people
```

### Step 7: Verify All Data Sources

Test that all three data sources are accessible from PostgreSQL.

```powershell
# Connect to PostgreSQL
docker exec -it postgres-with-oracle psql -U postgres -d moviesdb
```

**Inside psql, run:**

```sql
-- Check installed extensions
\dx

-- Expected:
-- file_fdw, multicorn, oracle_fdw, plpgsql

-- Check schemas
\dn

-- Expected:
-- csv_data, mongo_movies, oracle_movies, public

-- Test Oracle data
SELECT COUNT(*) FROM oracle_movies.movies;
-- Expected: 19900 (movies that have cast/crew data)

-- Test MongoDB data
SELECT COUNT(*) FROM mongo_movies.movies;
-- Expected: 45433

-- Test CSV ratings
SELECT COUNT(*) FROM csv_data.ratings;
-- Expected: 26024289

-- Exit psql
\q
```

### Step 8: Run Example Cross-Database Queries

Test joining data from all three sources.

```powershell
# Connect to PostgreSQL
docker exec -it postgres-with-oracle psql -U postgres -d moviesdb
```

**Example query:**

```sql
-- Top rated movies with cast and user ratings
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

**More examples:** See [all-sources-queries.sql](all-sources-queries.sql)

## Verification Checklist

✅ All 3 containers running and healthy  
✅ Oracle has 45,432 movies with cast/crew data  
✅ MongoDB has 45,433 movies with metadata  
✅ PostgreSQL can query all three sources  
✅ Cross-database joins work successfully  
✅ CSV ratings accessible (26M+ records)

## What Was Created

### Docker Containers

| Container            | Image            | Port  | Purpose                     |
| -------------------- | ---------------- | ----- | --------------------------- |
| postgres-with-oracle | Custom build     | 5433  | Central query hub with FDWs |
| oracle-credits-db    | gvenzl/oracle-xe | 1521  | Normalized credits data     |
| mongodb-movies       | mongo:7          | 27017 | Movie metadata documents    |

### PostgreSQL Extensions

- **oracle_fdw**: Connects to Oracle database
- **multicorn**: Python-based FDW framework
- **file_fdw**: Direct CSV file access

### Schemas in PostgreSQL

- **oracle_movies**: 6 foreign tables (movies, people, cast_members, crew_members, and views)
- **mongo_movies**: 4 foreign tables (movies, genres, production_companies, countries)
- **csv_data**: 1 foreign table + 1 view (ratings, ratings_with_date)

## Common Issues & Solutions

### Issue: PostgreSQL container exits immediately

**Solution:**

```powershell
# Check logs
docker logs postgres-with-oracle

# Usually means initialization script failed
# Rebuild and restart:
docker compose -f docker-compose-postgresql.yml down -v
docker compose -f docker-compose-postgresql.yml build --no-cache
docker compose -f docker-compose-postgresql.yml up -d
```

### Issue: Oracle data import fails

**Solution:**

```powershell
# Make sure Oracle is fully initialized
docker logs oracle-credits-db | Select-String "DATABASE IS READY"

# Wait 60 seconds after starting, then retry:
python import_data.py
```

### Issue: MongoDB authentication failed

**Solution:**

```powershell
# Set environment variables
$env:MONGO_USER='admin'
$env:MONGO_PASS='admin123'

# Test connection
docker exec mongodb-movies mongosh -u admin -p admin123 --authenticationDatabase admin --eval "db.adminCommand('ping')"

# Should return: { ok: 1 }
```

### Issue: Foreign tables show 0 rows

**Solution:**

```powershell
# Check if Oracle data was imported
docker exec oracle-credits-db sqlplus -s credits_user/credits_pass@XEPDB1 @- <<EOF
SELECT COUNT(*) FROM movies;
EXIT;
EOF

# Check if MongoDB has data
docker exec mongodb-movies mongosh -u admin -p admin123 --authenticationDatabase admin moviesdb --eval "db.movies.countDocuments({})"

# Re-import if needed (see Step 4 and 5)
```

### Issue: CSV ratings not accessible

**Solution:**

```powershell
# Check if CSV file is mounted
docker exec postgres-with-oracle ls -lh /data/ratings.csv

# If not found, recreate container:
docker compose -f docker-compose-postgresql.yml up -d --force-recreate postgres-db
```

## Starting Fresh

If you want to completely reset and start over:

```powershell
# Stop and remove all containers and volumes
docker compose -f docker-compose-postgresql.yml down -v

# Remove the PostgreSQL image to force rebuild
docker rmi for-oracle-postgres-db

# Follow setup steps from Step 1
```

## Next Steps

After successful setup:

1. **Explore data**: Browse the schemas and tables in pgAdmin or DBeaver
2. **Run queries**: Try the examples in [all-sources-queries.sql](all-sources-queries.sql)
3. **Build dashboards**: Connect BI tools like Tableau or Power BI to PostgreSQL
4. **Develop apps**: Use PostgreSQL as a unified API to all three data sources

## Performance Tips

- **Materialized views**: Create for frequently-accessed cross-database queries
- **Indexes**: Already exist on foreign keys in Oracle
- **Query pushdown**: Use WHERE clauses that PostgreSQL can push to source databases
- **Limit results**: Always use LIMIT when exploring large datasets

## Support

For issues, check:

- Container logs: `docker logs <container_name>`
- PostgreSQL logs: `docker exec postgres-with-oracle psql -U postgres -d moviesdb -c "SELECT * FROM pg_stat_activity;"`
- Oracle alert log: `docker exec oracle-credits-db cat /opt/oracle/diag/rdbms/xe/XE/trace/alert_XE.log`
