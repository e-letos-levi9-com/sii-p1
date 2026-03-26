import oracledb
import os

# Database connection parameters
DB_USER = os.getenv('DB_USER', 'credits_user')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'credits_pass')
DB_HOST = os.getenv('DB_HOST', 'localhost')
DB_PORT = os.getenv('DB_PORT', '1521')
DB_SERVICE = os.getenv('DB_SERVICE', 'XEPDB1')

def verify_database():
    """Verify the database connection and schema"""
    
    print("="*60)
    print("Oracle Database Connection Test")
    print("="*60)
    
    try:
        dsn = f"{DB_HOST}:{DB_PORT}/{DB_SERVICE}"
        print(f"\nConnecting to: {dsn}")
        print(f"User: {DB_USER}")
        
        connection = oracledb.connect(
            user=DB_USER,
            password=DB_PASSWORD,
            dsn=dsn
        )
        
        print("✓ Connection successful!\n")
        
        cursor = connection.cursor()
        
        # Check tables
        print("Checking tables...")
        cursor.execute("""
            SELECT table_name 
            FROM user_tables 
            ORDER BY table_name
        """)
        
        tables = cursor.fetchall()
        if tables:
            print(f"✓ Found {len(tables)} tables:")
            for table in tables:
                print(f"  - {table[0]}")
        else:
            print("✗ No tables found!")
        
        print()
        
        # Check views
        print("Checking views...")
        cursor.execute("""
            SELECT view_name 
            FROM user_views 
            ORDER BY view_name
        """)
        
        views = cursor.fetchall()
        if views:
            print(f"✓ Found {len(views)} views:")
            for view in views:
                print(f"  - {view[0]}")
        else:
            print("✗ No views found!")
        
        print()
        
        # Count records
        print("Checking data...")
        for table in ['MOVIES', 'PEOPLE', 'CAST_MEMBERS', 'CREW_MEMBERS']:
            try:
                cursor.execute(f"SELECT COUNT(*) FROM {table}")
                count = cursor.fetchone()[0]
                print(f"  - {table}: {count:,} records")
            except:
                print(f"  - {table}: Error reading table")
        
        print()
        print("="*60)
        print("Database is ready for data import!")
        print("Run: python import_data.py")
        print("="*60)
        
        cursor.close()
        connection.close()
        
        return True
        
    except oracledb.Error as e:
        error, = e.args
        print(f"\n✗ Database error: {error.message}")
        print("\nPossible issues:")
        print("1. Container not running: docker ps")
        print("2. Still initializing: wait 30-60 seconds")
        print("3. Wrong credentials or connection details")
        return False
    except Exception as e:
        print(f"\n✗ Error: {e}")
        return False

if __name__ == '__main__':
    verify_database()
