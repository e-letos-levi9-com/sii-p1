"""
MongoDB Foreign Data Wrapper for PostgreSQL using Multicorn2
"""
from multicorn import ForeignDataWrapper
from multicorn.utils import log_to_postgres, ERROR, WARNING, DEBUG
from pymongo import MongoClient
from bson import ObjectId
import json


class MongoFDW(ForeignDataWrapper):
    """
    MongoDB FDW using PyMongo
    """

    def __init__(self, options, columns):
        super(MongoFDW, self).__init__(options, columns)
        
        # Get connection options
        self.host = options.get('host', 'localhost')
        self.port = int(options.get('port', '27017'))
        self.database = options.get('database', 'test')
        self.collection = options.get('collection', 'test')
        self.username = options.get('username')
        self.password = options.get('password')
        
        # Store column definitions
        self.columns = columns
        
        # Build connection string
        if self.username and self.password:
            uri = f"mongodb://{self.username}:{self.password}@{self.host}:{self.port}"
        else:
            uri = f"mongodb://{self.host}:{self.port}"
        
        # Connect to MongoDB
        try:
            self.client = MongoClient(uri, serverSelectionTimeoutMS=5000)
            self.db = self.client[self.database]
            self.coll = self.db[self.collection]
        except Exception as e:
            log_to_postgres(f"Failed to connect to MongoDB: {e}", ERROR)
            raise

    def execute(self, quals, columns):
        """
        Execute query and return rows
        """
        # Build MongoDB query from PostgreSQL quals
        query = {}
        for qual in quals:
            field_name = qual.field_name
            operator = qual.operator
            value = qual.value
            
            # Map PostgreSQL operators to MongoDB operators
            if operator == '=':
                query[field_name] = value
            elif operator == '>':
                query[field_name] = {'$gt': value}
            elif operator == '>=':
                query[field_name] = {'$gte': value}
            elif operator == '<':
                query[field_name] = {'$lt': value}
            elif operator == '<=':
                query[field_name] = {'$lte': value}
            elif operator == '~~':  # LIKE
                query[field_name] = {'$regex': value.replace('%', '.*')}
        
        # Execute query
        try:
            # Only project requested columns if specified
            projection = {col: 1 for col in columns} if columns else None
            cursor = self.coll.find(query, projection)
            
            for doc in cursor:
                # Convert MongoDB document to PostgreSQL row
                row = {}
                for col_name in self.columns:
                    value = doc.get(col_name)
                    col_type = self.columns[col_name].type_name
                    
                    # Handle special cases
                    if isinstance(value, ObjectId):
                        row[col_name] = str(value)
                    elif isinstance(value, (dict, list)):
                        row[col_name] = json.dumps(value)
                    elif value is None:
                        row[col_name] = None
                    elif col_type in ['integer', 'int4', 'int2', 'bigint', 'int8']:
                        # Convert to integer, handling floats like 81.0
                        try:
                            row[col_name] = int(float(value)) if value is not None else None
                        except (ValueError, TypeError):
                            row[col_name] = None
                    elif col_type in ['numeric', 'decimal', 'real', 'double precision', 'float4', 'float8']:
                        # Convert to float
                        try:
                            row[col_name] = float(value) if value is not None else None
                        except (ValueError, TypeError):
                            row[col_name] = None
                    else:
                        row[col_name] = value
                
                yield row
                
        except Exception as e:
            log_to_postgres(f"Query execution failed: {e}", ERROR)
            raise

    def insert(self, new_values):
        """
        Insert a new document
        """
        try:
            # Convert PostgreSQL row to MongoDB document
            doc = {}
            for col_name, value in new_values.items():
                if col_name == '_id' and value:
                    # Handle _id field
                    try:
                        doc['_id'] = ObjectId(value)
                    except:
                        doc['_id'] = value
                else:
                    doc[col_name] = value
            
            result = self.coll.insert_one(doc)
            return {'_id': str(result.inserted_id)}
            
        except Exception as e:
            log_to_postgres(f"Insert failed: {e}", ERROR)
            raise

    def update(self, old_values, new_values):
        """
        Update an existing document
        """
        try:
            # Build query to find document
            query = {}
            if '_id' in old_values:
                try:
                    query['_id'] = ObjectId(old_values['_id'])
                except:
                    query['_id'] = old_values['_id']
            else:
                query = old_values
            
            # Build update document
            update_doc = {'$set': new_values}
            
            self.coll.update_one(query, update_doc)
            
        except Exception as e:
            log_to_postgres(f"Update failed: {e}", ERROR)
            raise

    def delete(self, old_values):
        """
        Delete a document
        """
        try:
            # Build query to find document
            query = {}
            if '_id' in old_values:
                try:
                    query['_id'] = ObjectId(old_values['_id'])
                except:
                    query['_id'] = old_values['_id']
            else:
                query = old_values
            
            self.coll.delete_one(query)
            
        except Exception as e:
            log_to_postgres(f"Delete failed: {e}", ERROR)
            raise
