# MongoDB Movies Dataset Import Instructions (Docker)

This directory contains scripts to import the movies.json dataset into a Docker-based MongoDB database.

## Files Created

1. **import_mongo.ps1** - Automated PowerShell import script (Windows)
2. **mongo-queries.js** - Sample MongoDB queries
3. **movies.json** - Source JSON data file

### Option 1: Using PowerShell Script (Recommended)

1. Make sure your MongoDB Docker container is running:

   ```powershell
   docker ps
   ```

2. Edit `import_mongo.ps1` and update these variables if needed:

   ```powershell
   $DOCKER_CONTAINER = "adoring_wilson"   # Your container name (from: docker ps)
   $MONGO_DB = "movies_db"                # Database name
   $MONGO_COLLECTION = "movies"           # Collection name
   ```

3. Run the script:
   ```powershell
   .\import_mongo.ps1
   ```

### Quick Queries (PowerShell)

```powershell
# Count documents
docker exec -i adoring_wilson mongosh movies_db --quiet --eval "db.movies.countDocuments({})"

# Find movies by title
docker exec -i adoring_wilson mongosh movies_db --quiet --eval "db.movies.find({ title: /Star/i }, { title: 1, year: 1 }).limit(5)"

# Find by genre
docker exec -i adoring_wilson mongosh movies_db --quiet --eval "db.movies.find({ genres: 'Drama' }, { title: 1 }).limit(5)"
```

## Database Schema

The movies collection contains documents with these fields:

- **title** (string) - Movie title
- **year** (number) - Release year
- **genres** (array) - List of genre strings
- **extract** (string) - Movie description/summary
- **thumbnail** (string) - URL to thumbnail image
- **thumbnail_width** (number) - Thumbnail width in pixels
- **thumbnail_height** (number) - Thumbnail height in pixels
- **href** (string) - External reference link
