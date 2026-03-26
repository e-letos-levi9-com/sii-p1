// Create database and user for movies application
db = db.getSiblingDB("moviesdb");

db.createUser({
  user: "movies_user",
  pwd: "movies_pass",
  roles: [
    {
      role: "readWrite",
      db: "moviesdb",
    },
  ],
});

// Create collections with validation
db.createCollection("movies", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["id", "title"],
      properties: {
        id: {
          bsonType: "int",
          description: "Movie ID - required",
        },
        title: {
          bsonType: "string",
          description: "Movie title - required",
        },
        original_title: {
          bsonType: "string",
        },
        budget: {
          bsonType: ["int", "double"],
        },
        revenue: {
          bsonType: ["int", "double"],
        },
        runtime: {
          bsonType: ["int", "double"],
        },
        release_date: {
          bsonType: "string",
        },
        vote_average: {
          bsonType: ["int", "double"],
        },
        vote_count: {
          bsonType: "int",
        },
      },
    },
  },
});

db.createCollection("production_companies");
db.createCollection("genres");
db.createCollection("countries");

// Create indexes for better query performance
db.movies.createIndex({ id: 1 }, { unique: true });
db.movies.createIndex({ title: 1 });
db.movies.createIndex({ release_date: -1 });
db.movies.createIndex({ "genres.id": 1 });
db.movies.createIndex({ "production_companies.id": 1 });
db.movies.createIndex({ vote_average: -1 });
db.movies.createIndex({ revenue: -1 });

db.production_companies.createIndex({ id: 1 }, { unique: true });
db.production_companies.createIndex({ name: 1 });

db.genres.createIndex({ id: 1 }, { unique: true });
db.genres.createIndex({ name: 1 });

db.countries.createIndex({ iso_3166_1: 1 }, { unique: true });

print("Database and collections created successfully!");
