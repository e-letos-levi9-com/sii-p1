# ============================================================================
# Oracle Import Script for TMDB Dataset (PowerShell)
# For Docker-based Oracle Database
# ============================================================================

Write-Host "Starting TMDB Oracle import..." -ForegroundColor Green
Write-Host ""

# Set Oracle Docker container details - EDIT THESE
$DOCKER_CONTAINER = "laughing_taussig"  # Your Oracle container name (from: docker ps)
$ORACLE_USER = "system"                  # Default: system
$ORACLE_PASSWORD = "oracle"              # Your Oracle password
$ORACLE_SID = "XEPDB1"                   # For gvenzl/oracle-xe use XEPDB1
$ORACLE_CONNECTION = "$ORACLE_USER/$ORACLE_PASSWORD@$ORACLE_SID"

# Change to script directory
Set-Location $PSScriptRoot

# Check if container is running
Write-Host "Checking Oracle container..." -ForegroundColor Yellow
$containerRunning = docker ps --filter "name=$DOCKER_CONTAINER" --format "{{.Names}}"
if (-not $containerRunning) {
    Write-Host "Error: Container '$DOCKER_CONTAINER' is not running!" -ForegroundColor Red
    Write-Host "Start it with: docker start $DOCKER_CONTAINER" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "Container is running." -ForegroundColor Green
Write-Host ""

# Copy files to Docker container
Write-Host "Copying files to Docker container..." -ForegroundColor Yellow
docker cp oracle-data.sql "${DOCKER_CONTAINER}:/tmp/"
docker cp load_movies.ctl "${DOCKER_CONTAINER}:/tmp/"
docker cp load_credits.ctl "${DOCKER_CONTAINER}:/tmp/"
docker cp oracle/tmdb_5000_movies.csv "${DOCKER_CONTAINER}:/tmp/"
docker cp oracle/tmdb_5000_credits.csv "${DOCKER_CONTAINER}:/tmp/"
Write-Host "Files copied successfully." -ForegroundColor Green
Write-Host ""

Write-Host "Step 1: Creating tables..." -ForegroundColor Yellow
docker exec -i $DOCKER_CONTAINER sqlplus -S $ORACLE_CONNECTION "@/tmp/oracle-data.sql"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: SQLPlus returned exit code $LASTEXITCODE (this may be due to harmless DROP errors)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 2: Loading movies data..." -ForegroundColor Yellow
docker exec -i $DOCKER_CONTAINER sqlldr $ORACLE_CONNECTION control=/tmp/load_movies.ctl log=/tmp/load_movies.log
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error loading movies data. Check load_movies.log for details." -ForegroundColor Red
}

Write-Host ""
Write-Host "Step 3: Loading credits data..." -ForegroundColor Yellow
docker exec -i $DOCKER_CONTAINER sqlldr $ORACLE_CONNECTION control=/tmp/load_credits.ctl log=/tmp/load_credits.log
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error loading credits data. Check load_credits.log for details." -ForegroundColor Red
}

Write-Host ""
Write-Host "Step 4: Copying log files back..." -ForegroundColor Yellow
docker cp "${DOCKER_CONTAINER}:/tmp/load_movies.log" . 2>$null
docker cp "${DOCKER_CONTAINER}:/tmp/load_credits.log" . 2>$null

Write-Host ""
Write-Host "Import completed!" -ForegroundColor Green
Write-Host "Check the log files for any errors:" -ForegroundColor Cyan
Write-Host "  - load_movies.log" -ForegroundColor White
Write-Host "  - load_credits.log" -ForegroundColor White
Write-Host ""

# Display row counts
Write-Host "Verifying data..." -ForegroundColor Yellow
$sqlQuery = "SET HEADING OFF; SELECT 'Movies loaded: ' || COUNT(*) FROM movies; SELECT 'Credits loaded: ' || COUNT(*) FROM credits; EXIT;"
$sqlQuery | docker exec -i $DOCKER_CONTAINER sqlplus -S $ORACLE_CONNECTION

Write-Host ""
Read-Host "Press Enter to exit"
