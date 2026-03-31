import os
from typing import Any, Dict, List

import psycopg2
from psycopg2.extras import RealDictCursor
from fastapi import FastAPI, Query


app = FastAPI(title="SIA P4 REST API", version="1.0.0")


def get_conn():
    return psycopg2.connect(
        host=os.getenv("PGHOST", "localhost"),
        port=int(os.getenv("PGPORT", "5433")),
        dbname=os.getenv("PGDATABASE", "moviesdb"),
        user=os.getenv("PGUSER", "postgres"),
        password=os.getenv("PGPASSWORD", "postgres123"),
    )


def fetch_rows(sql: str, limit: int) -> List[Dict[str, Any]]:
    with get_conn() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql + " LIMIT %s", (limit,))
            rows = cur.fetchall()
    return [dict(r) for r in rows]


@app.get("/health")
def health() -> Dict[str, str]:
    return {"status": "ok"}


@app.get("/api/v1/analytics/budget-runtime")
def analytics_budget_runtime(limit: int = Query(default=100, ge=1, le=5000)):
    sql = "SELECT * FROM integration_model.av_budget_runtime_rollup"
    return fetch_rows(sql, limit)


@app.get("/api/v1/analytics/language-decade")
def analytics_language_decade(limit: int = Query(default=100, ge=1, le=5000)):
    sql = "SELECT * FROM integration_model.av_language_decade_cube"
    return fetch_rows(sql, limit)


@app.get("/api/v1/analytics/top-actors")
def analytics_top_actors(limit: int = Query(default=50, ge=1, le=5000)):
    sql = "SELECT * FROM integration_model.av_top_actors ORDER BY actor_rank"
    return fetch_rows(sql, limit)


@app.get("/api/v1/integration/movies")
def integration_movies(limit: int = Query(default=100, ge=1, le=5000)):
    sql = "SELECT * FROM integration_model.vw_movie_consolidated"
    return fetch_rows(sql, limit)
