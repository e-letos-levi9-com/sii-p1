# ============================================================================
# MongoDB Import Script for Movies Dataset (PowerShell)
# For Docker-based MongoDB
# ============================================================================

Write-Host "Starting MongoDB movies import..." -ForegroundColor Green
Write-Host ""

# Configuration
$DOCKER_CONTAINER = "adoring_wilson"    # Your MongoDB container name (from: docker ps)
$MONGO_DB = "movies_db"                 # Database name
$MONGO_COLLECTION = "movies"            # Collection name
$JSON_FILE = "movies.json"              # Source JSON file

# Change to script directory
Set-Location $PSScriptRoot

# Check if container is running
Write-Host "Checking MongoDB container..." -ForegroundColor Yellow
$containerRunning = docker ps --filter "name=$DOCKER_CONTAINER" --format "{{.Names}}"
if (-not $containerRunning) {
    Write-Host "Error: Container '$DOCKER_CONTAINER' is not running!" -ForegroundColor Red
    Write-Host "Start it with: docker start $DOCKER_CONTAINER" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "Container is running." -ForegroundColor Green
Write-Host ""

# Check if JSON file exists
if (-not (Test-Path $JSON_FILE)) {
    Write-Host "Error: $JSON_FILE not found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Copy JSON file to container
Write-Host "Copying JSON file to Docker container..." -ForegroundColor Yellow
docker cp $JSON_FILE "${DOCKER_CONTAINER}:/tmp/"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error copying file to container!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host "File copied successfully." -ForegroundColor Green
Write-Host ""

# Import data into MongoDB
Write-Host "Importing data into MongoDB..." -ForegroundColor Yellow
Write-Host "Database: $MONGO_DB" -ForegroundColor Cyan
Write-Host "Collection: $MONGO_COLLECTION" -ForegroundColor Cyan
Write-Host ""

docker exec -i $DOCKER_CONTAINER mongoimport `
    --db=$MONGO_DB `
    --collection=$MONGO_COLLECTION `
    --file=/tmp/$JSON_FILE `
    --jsonArray `
    --drop

if ($LASTEXITCODE -ne 0) {
    Write-Host "Error importing data!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Creating indexes..." -ForegroundColor Yellow

# Create indexes for better query performance
$indexCommands = @"
db.movies.createIndex({ "title": 1 })
db.movies.createIndex({ "year": 1 })
db.movies.createIndex({ "genres": 1 })
"@

$indexCommands | docker exec -i $DOCKER_CONTAINER mongosh $MONGO_DB --quiet

Write-Host ""
Write-Host "Import completed successfully!" -ForegroundColor Green
Write-Host ""

# Display statistics
Write-Host "Verifying data..." -ForegroundColor Yellow
$countCommand = "db.movies.countDocuments({})"
$count = $countCommand | docker exec -i $DOCKER_CONTAINER mongosh $MONGO_DB --quiet --eval

Write-Host "Total movies imported: $count" -ForegroundColor Cyan
Write-Host ""

# Show sample data
Write-Host "Sample movies (first 3):" -ForegroundColor Yellow
$sampleCommand = "db.movies.find().limit(3).forEach(m => print(m.title + ' (' + m.year + ')'))"
$sampleCommand | docker exec -i $DOCKER_CONTAINER mongosh $MONGO_DB --quiet --eval

Write-Host ""
Write-Host "MongoDB Connection Info:" -ForegroundColor Cyan
Write-Host "  Host: localhost:27017" -ForegroundColor White
Write-Host "  Database: $MONGO_DB" -ForegroundColor White
Write-Host "  Collection: $MONGO_COLLECTION" -ForegroundColor White
Write-Host ""
Write-Host "To connect:" -ForegroundColor Cyan
Write-Host "  docker exec -it $DOCKER_CONTAINER mongosh $MONGO_DB" -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to exit"
