import csv
import json
import ast
from pymongo import MongoClient
from datetime import datetime
import os

# MongoDB connection
MONGO_HOST = os.getenv('MONGO_HOST', 'localhost')
MONGO_PORT = int(os.getenv('MONGO_PORT', '27017'))
MONGO_USER = os.getenv('MONGO_USER', 'movies_user')
MONGO_PASS = os.getenv('MONGO_PASS', 'movies_pass')
MONGO_DB = os.getenv('MONGO_DB', 'moviesdb')

def parse_json_field(field_value):
    """Parse JSON-like field from CSV"""
    if not field_value or field_value == 'null' or field_value.strip() == '':
        return None
    try:
        # Use ast.literal_eval for Python-style dicts with single quotes
        result = ast.literal_eval(field_value)
        return result
    except (ValueError, SyntaxError):
        try:
            # Fallback to JSON parsing
            return json.loads(field_value)
        except json.JSONDecodeError:
            return None

def safe_int(value):
    """Safely convert to int"""
    if not value or value == '' or value == 'null':
        return None
    try:
        return int(float(value))
    except (ValueError, TypeError):
        return None

def safe_float(value):
    """Safely convert to float"""
    if not value or value == '' or value == 'null':
        return None
    try:
        return float(value)
    except (ValueError, TypeError):
        return None

def safe_bool(value):
    """Safely convert to boolean"""
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.lower() in ('true', 'yes', '1')
    return bool(value)

def import_movies_from_csv(csv_path):
    """Import movies from CSV to MongoDB"""
    
    print("Connecting to MongoDB...")
    client = MongoClient(
        host=MONGO_HOST,
        port=MONGO_PORT,
        username=MONGO_USER,
        password=MONGO_PASS,
        authSource='admin'  # Root user authenticates against admin database
    )
    
    db = client[MONGO_DB]
    movies_collection = db['movies']
    companies_collection = db['production_companies']
    genres_collection = db['genres']
    countries_collection = db['countries']
    
    # Clear existing data
    print("Clearing existing data...")
    movies_collection.delete_many({})
    companies_collection.delete_many({})
    genres_collection.delete_many({})
    countries_collection.delete_many({})
    
    # Track unique companies, genres, and countries
    companies_set = {}
    genres_set = {}
    countries_set = {}
    
    print(f"Reading CSV file: {csv_path}")
    movies = []
    skipped = 0
    
    with open(csv_path, 'r', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        
        for idx, row in enumerate(reader, 1):
            try:
                movie_id = safe_int(row.get('id'))
                if not movie_id:
                    skipped += 1
                    continue
                
                # Parse complex fields
                genres = parse_json_field(row.get('genres')) or []
                production_companies = parse_json_field(row.get('production_companies')) or []
                production_countries = parse_json_field(row.get('production_countries')) or []
                spoken_languages = parse_json_field(row.get('spoken_languages')) or []
                belongs_to_collection = parse_json_field(row.get('belongs_to_collection'))
                
                # Track unique entities for normalization
                for genre in genres:
                    if isinstance(genre, dict) and 'id' in genre:
                        genres_set[genre['id']] = genre
                
                for company in production_companies:
                    if isinstance(company, dict) and 'id' in company:
                        companies_set[company['id']] = company
                
                for country in production_countries:
                    if isinstance(country, dict) and 'iso_3166_1' in country:
                        countries_set[country['iso_3166_1']] = country
                
                # Build movie document (use movie_id as _id to avoid duplicates)
                movie_doc = {
                    '_id': movie_id,  # Use movie_id as MongoDB _id for uniqueness
                    'id': movie_id,
                    'title': row.get('title', ''),
                    'original_title': row.get('original_title', ''),
                    'original_language': row.get('original_language'),
                    'overview': row.get('overview'),
                    'tagline': row.get('tagline'),
                    'homepage': row.get('homepage'),
                    'imdb_id': row.get('imdb_id'),
                    'status': row.get('status'),
                    'adult': safe_bool(row.get('adult')),
                    'video': safe_bool(row.get('video')),
                    'budget': safe_int(row.get('budget')),
                    'revenue': safe_int(row.get('revenue')),
                    'runtime': safe_float(row.get('runtime')),
                    'popularity': safe_float(row.get('popularity')),
                    'vote_average': safe_float(row.get('vote_average')),
                    'vote_count': safe_int(row.get('vote_count')),
                    'release_date': row.get('release_date') if row.get('release_date') else None,
                    'poster_path': row.get('poster_path'),
                    
                    # Embedded documents
                    'genres': genres,
                    'production_companies': production_companies,
                    'production_countries': production_countries,
                    'spoken_languages': spoken_languages,
                    'belongs_to_collection': belongs_to_collection,
                    
                    # Metadata
                    'imported_at': datetime.utcnow()
                }
                
                # Remove None values to save space
                movie_doc = {k: v for k, v in movie_doc.items() if v is not None}
                
                movies.append(movie_doc)
                
                # Batch insert every 1000 movies
                if len(movies) >= 1000:
                    try:
                        # ordered=False allows continued insertion even if some fail
                        movies_collection.insert_many(movies, ordered=False)
                        print(f"Imported {idx} movies...")
                    except Exception as e:
                        # Handle duplicate key errors
                        if hasattr(e, 'details') and 'writeErrors' in e.details:
                            inserted = e.details.get('nInserted', 0)
                            print(f"Imported {idx} movies (skipped {len(movies) - inserted} duplicates)...")
                        else:
                            print(f"Error at {idx}: {e}")
                    movies = []
                    
            except Exception as e:
                print(f"Error processing row {idx}: {e}")
                skipped += 1
                continue
        
        # Insert remaining movies
        if movies:
            try:
                movies_collection.insert_many(movies, ordered=False)
            except Exception as e:
                if hasattr(e, 'details') and 'writeErrors' in e.details:
                    inserted = e.details.get('nInserted', 0)
                    print(f"Final batch: Inserted {inserted}, skipped {len(movies) - inserted} duplicates")
                else:
                    print(f"Error in final batch: {e}")
    
    print(f"\nImporting normalized collections...")
    
    # Insert unique genres
    if genres_set:
        try:
            genres_list = [{'_id': g['id'], **g} for g in genres_set.values()]
            genres_collection.insert_many(genres_list, ordered=False)
            print(f"Imported {len(genres_set)} unique genres")
        except Exception as e:
            print(f"Genres: Some duplicates skipped")
    
    # Insert unique production companies
    if companies_set:
        try:
            companies_list = [{'_id': c['id'], **c} for c in companies_set.values()]
            companies_collection.insert_many(companies_list, ordered=False)
            print(f"Imported {len(companies_set)} unique production companies")
        except Exception as e:
            print(f"Companies: Some duplicates skipped")
    
    # Insert unique countries
    if countries_set:
        try:
            countries_list = [{'_id': c['iso_3166_1'], **c} for c in countries_set.values()]
            countries_collection.insert_many(countries_list, ordered=False)
            print(f"Imported {len(countries_set)} unique countries")
        except Exception as e:
            print(f"Countries: Some duplicates skipped")
    
    total_movies = movies_collection.count_documents({})
    
    print("\n" + "="*60)
    print("Import Complete!")
    print("="*60)
    print(f"Total movies imported: {total_movies}")
    print(f"Skipped rows: {skipped}")
    print(f"Unique genres: {len(genres_set)}")
    print(f"Unique production companies: {len(companies_set)}")
    print(f"Unique countries: {len(countries_set)}")
    print("="*60)
    
    client.close()

if __name__ == '__main__':
    csv_path = os.path.join('..', 'data', 'movies_metadata.csv')
    
    if not os.path.exists(csv_path):
        print(f"Error: CSV file not found at {csv_path}")
        print("Please ensure movies_metadata.csv is in the data folder")
        exit(1)
    
    try:
        import_movies_from_csv(csv_path)
    except Exception as e:
        print(f"Error: {e}")
        print("\nMake sure:")
        print("1. MongoDB container is running (docker-compose up -d)")
        print("2. pymongo is installed (pip install pymongo)")
