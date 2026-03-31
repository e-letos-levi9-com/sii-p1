from pymongo import MongoClient
import os

# Connection parameters
MONGO_HOST = os.getenv('MONGO_HOST', 'localhost')
MONGO_PORT = int(os.getenv('MONGO_PORT', '27017'))
MONGO_USER = os.getenv('MONGO_USER', 'movies_user')
MONGO_PASS = os.getenv('MONGO_PASS', 'movies_pass')
MONGO_DB = os.getenv('MONGO_DB', 'moviesdb')

def verify_mongodb():
    """Verify MongoDB connection and data"""
    
    print("="*60)
    print("MongoDB Connection Test")
    print("="*60)
    
    try:
        print(f"\nConnecting to: mongodb://{MONGO_HOST}:{MONGO_PORT}/{MONGO_DB}")
        print(f"User: {MONGO_USER}")
        
        client = MongoClient(
            host=MONGO_HOST,
            port=MONGO_PORT,
            username=MONGO_USER,
            password=MONGO_PASS,
            authSource=MONGO_DB,
            serverSelectionTimeoutMS=5000
        )
        
        # Test connection
        client.server_info()
        print("✓ Connection successful!\n")
        
        db = client[MONGO_DB]
        
        # List collections
        collections = db.list_collection_names()
        print(f"Collections found: {len(collections)}")
        for col in collections:
            print(f"  - {col}")
        
        print()
        
        # Count documents
        print("Document counts:")
        for col_name in ['movies', 'genres', 'production_companies', 'countries']:
            if col_name in collections:
                count = db[col_name].count_documents({})
                print(f"  - {col_name}: {count:,} documents")
            else:
                print(f"  - {col_name}: Collection not found")
        
        print()
        
        # Sample movie
        if 'movies' in collections:
            sample = db.movies.find_one()
            if sample:
                print("Sample movie:")
                print(f"  Title: {sample.get('title')}")
                print(f"  ID: {sample.get('id')}")
                print(f"  Release: {sample.get('release_date')}")
                print(f"  Rating: {sample.get('vote_average')}")
                if 'genres' in sample and sample['genres']:
                    genres = [g.get('name') for g in sample['genres'] if isinstance(g, dict)]
                    print(f"  Genres: {', '.join(genres)}")
        
        print()
        print("="*60)
        print("MongoDB is ready!")
        print("Run: python import_movies.py")
        print("="*60)
        
        client.close()
        return True
        
    except Exception as e:
        print(f"\n✗ Error: {e}")
        print("\nPossible issues:")
        print("1. Container not running: docker-compose up -d")
        print("2. Wrong credentials or connection details")
        print("3. Database not initialized yet (wait a few seconds)")
        return False

if __name__ == '__main__':
    verify_mongodb()
