import csv
import json
import ast
import oracledb
import os
from collections import defaultdict

# Database connection parameters
DB_USER = os.getenv('DB_USER', 'credits_user')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'credits_pass')
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_PORT = os.getenv('DB_PORT', '1521')
DB_SERVICE = os.getenv('DB_SERVICE', 'XEPDB1')

def get_connection():
    """Create and return database connection"""
    dsn = f"{DB_HOST}:{DB_PORT}/{DB_SERVICE}"
    connection = oracledb.connect(
        user=DB_USER,
        password=DB_PASSWORD,
        dsn=dsn
    )
    return connection

def parse_json_field(field_value):
    """Parse JSON field, handling None and malformed data"""
    if not field_value or field_value == 'null' or field_value.strip() == '':
        return []
    try:
        # The CSV uses Python-style dicts with single quotes
        # Use ast.literal_eval which handles single quotes properly
        result = ast.literal_eval(field_value)
        return result if isinstance(result, list) else []
    except (ValueError, SyntaxError) as e:
        # Fallback: try JSON parsing
        try:
            return json.loads(field_value)
        except json.JSONDecodeError:
            print(f"Error parsing field: {e}")
            print(f"Value: {field_value[:200]}...")
            return []

def import_credits_data(csv_file_path):
    """Import credits data from CSV into Oracle database"""
    
    print("Connecting to database...")
    conn = get_connection()
    cursor = conn.cursor()
    
    # Track unique people to avoid duplicates
    people_cache = {}
    
    print("Reading CSV file...")
    with open(csv_file_path, 'r', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        
        movie_count = 0
        cast_count = 0
        crew_count = 0
        
        for row in reader:
            try:
                movie_id = int(row['id'])
                cast_data = parse_json_field(row['cast'])
                crew_data = parse_json_field(row['crew'])
                
                # Insert movie
                try:
                    cursor.execute(
                        "INSERT INTO movies (movie_id) VALUES (:1)",
                        [movie_id]
                    )
                    movie_count += 1
                except oracledb.IntegrityError:
                    # Movie already exists
                    pass
                
                # Process cast
                for cast_member in cast_data:
                    person_id = cast_member.get('id')
                    if not person_id:
                        continue
                    
                    # Insert person if not exists
                    if person_id not in people_cache:
                        try:
                            cursor.execute(
                                """INSERT INTO people (person_id, name, gender, profile_path) 
                                   VALUES (:1, :2, :3, :4)""",
                                [
                                    person_id,
                                    cast_member.get('name', 'Unknown'),
                                    cast_member.get('gender', 0),
                                    cast_member.get('profile_path')
                                ]
                            )
                            people_cache[person_id] = True
                        except oracledb.IntegrityError:
                            # Person already exists
                            people_cache[person_id] = True
                    
                    # Insert cast member
                    try:
                        cursor.execute(
                            """INSERT INTO cast_members 
                               (movie_id, person_id, character_name, credit_id, cast_order)
                               VALUES (:1, :2, :3, :4, :5)""",
                            [
                                movie_id,
                                person_id,
                                cast_member.get('character'),
                                cast_member.get('credit_id'),
                                cast_member.get('order', 999)
                            ]
                        )
                        cast_count += 1
                    except Exception as e:
                        print(f"Error inserting cast: {e}")
                
                # Process crew
                for crew_member in crew_data:
                    person_id = crew_member.get('id')
                    if not person_id:
                        continue
                    
                    # Insert person if not exists
                    if person_id not in people_cache:
                        try:
                            cursor.execute(
                                """INSERT INTO people (person_id, name, gender, profile_path) 
                                   VALUES (:1, :2, :3, :4)""",
                                [
                                    person_id,
                                    crew_member.get('name', 'Unknown'),
                                    crew_member.get('gender', 0),
                                    crew_member.get('profile_path')
                                ]
                            )
                            people_cache[person_id] = True
                        except oracledb.IntegrityError:
                            # Person already exists
                            people_cache[person_id] = True
                    
                    # Insert crew member
                    try:
                        cursor.execute(
                            """INSERT INTO crew_members 
                               (movie_id, person_id, department, job, credit_id)
                               VALUES (:1, :2, :3, :4, :5)""",
                            [
                                movie_id,
                                person_id,
                                crew_member.get('department'),
                                crew_member.get('job'),
                                crew_member.get('credit_id')
                            ]
                        )
                        crew_count += 1
                    except Exception as e:
                        print(f"Error inserting crew: {e}")
                
                # Commit every 100 movies
                if movie_count % 100 == 0:
                    conn.commit()
                    print(f"Progress: {movie_count} movies, {len(people_cache)} people, "
                          f"{cast_count} cast members, {crew_count} crew members")
                    
            except Exception as e:
                print(f"Error processing movie {row.get('id', 'unknown')}: {e}")
                continue
        
        # Final commit
        conn.commit()
        print("\n" + "="*60)
        print(f"Import completed!")
        print(f"Total movies: {movie_count}")
        print(f"Total unique people: {len(people_cache)}")
        print(f"Total cast entries: {cast_count}")
        print(f"Total crew entries: {crew_count}")
        print("="*60)
    
    cursor.close()
    conn.close()

if __name__ == '__main__':
    csv_path = os.path.join('..', 'data', 'credits.csv')
    
    if not os.path.exists(csv_path):
        print(f"Error: CSV file not found at {csv_path}")
        print("Please ensure credits.csv is in the data folder")
        exit(1)
    
    try:
        import_credits_data(csv_path)
    except oracledb.Error as e:
        print(f"Database error: {e}")
        print("\nMake sure:")
        print("1. Oracle container is running (docker-compose up -d)")
        print("2. Database is ready (wait ~30 seconds after starting)")
        print("3. Connection parameters are correct")
    except Exception as e:
        print(f"Error: {e}")
