# Oracle TMDB Dataset Import Instructions (Docker)

This directory contains scripts to create Oracle tables and import TMDB 5000 dataset into a Docker-based Oracle database.

## Files Created

1. **oracle-data.sql** - Creates the database tables (movies and credits)
2. **load_movies.ctl** - SQL\*Loader control file for movies CSV
3. **load_credits.ctl** - SQL\*Loader control file for credits CSV
4. **import_oracle.ps1** - Automated PowerShell script (Windows)

## Quick Start

### Option 1: Using PowerShell Script (Recommended)

1. Make sure your Oracle Docker container is running:

   ```powershell
   docker ps
   ```

2. Edit `import_oracle.ps1` and update these variables:

   ```powershell
   $DOCKER_CONTAINER = "laughing_taussig"  # Your container name (from docker ps)
   $ORACLE_USER = "system"                 # Usually 'system'
   $ORACLE_PASSWORD = "oracle"             # Your password
   $ORACLE_SID = "XEPDB1"                  # For gvenzl/oracle-xe use XEPDB1
   ```

3. Run the script:
   ```powershell
   .\import_oracle.ps1
   ```

## Table Structure

### MOVIES Table

- **id** (NUMBER, PRIMARY KEY) - Movie identifier
- **budget** (NUMBER) - Production budget
- **revenue** (NUMBER) - Total revenue
- **title** (VARCHAR2) - Movie title
- **overview** (CLOB) - Movie description
- **genres** (CLOB) - JSON array of genres
- **keywords** (CLOB) - JSON array of keywords
- **release_date** (DATE) - Release date
- And more...

### CREDITS Table

- **movie_id** (NUMBER, PRIMARY KEY, FK) - References movies(id)
- **title** (VARCHAR2) - Movie title
- **cast** (CLOB) - JSON array of cast members
- **crew** (CLOB) - JSON array of crew members

## Logs

After running, check these log files for any errors:

- `load_movies.log` - Movies import log
- `load_credits.log` - Credits import log

Logs are generated inside the container at `/tmp/` and copied back to your local directory by the automated scripts.

## Check data

echo "SELECT COUNT(\*) FROM movies;" | docker exec -i laughing_taussig sqlplus -S system/oracle@XEPDB1

echo "SELECT COUNT(\*) FROM credits;" | docker exec -i laughing_taussig sqlplus -S system/oracle@XEPDB1
