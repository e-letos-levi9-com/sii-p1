import os

import pandas as pd
from sqlalchemy import create_engine
import streamlit as st


st.set_page_config(page_title="SIA P4 Dashboard", layout="wide")
st.title("SIA - P4 REST & Web UIX Dashboard")


def get_engine():
    host = os.getenv("PGHOST", "localhost")
    port = os.getenv("PGPORT", "5433")
    dbname = os.getenv("PGDATABASE", "moviesdb")
    user = os.getenv("PGUSER", "postgres")
    password = os.getenv("PGPASSWORD", "postgres123")
    
    connection_string = f"postgresql://{user}:{password}@{host}:{port}/{dbname}"
    return create_engine(connection_string)


def load_df(sql: str) -> pd.DataFrame:
    engine = get_engine()
    return pd.read_sql_query(sql, engine)


st.info(f"Connecting to database: localhost:5433/moviesdb")

try:
    with st.spinner('Loading data...'):
        df_budget_runtime = load_df(
        "SELECT budget_bucket, runtime_bucket, movie_count, avg_user_rating, avg_roi_percent "
        "FROM integration_model.av_budget_runtime_rollup "
        "WHERE budget_bucket IS NOT NULL AND runtime_bucket IS NOT NULL"
    )

        df_language_decade = load_df(
            "SELECT language, release_decade, movie_count, avg_user_rating, avg_roi_percent "
            "FROM integration_model.av_language_decade_cube "
            "WHERE language IS NOT NULL AND release_decade IS NOT NULL"
        )

        df_top_actors = load_df(
            "SELECT actor_rank, actor_name, movie_count, avg_user_rating, avg_roi_percent "
            "FROM integration_model.av_top_actors "
            "ORDER BY actor_rank LIMIT 20"
        )
    
    st.success(f"Data loaded successfully!")

    c1, c2, c3 = st.columns(3)
    c1.metric("Rows Budget/Runtime", int(len(df_budget_runtime)))
    c2.metric("Rows Language/Decade", int(len(df_language_decade)))
    c3.metric("Top Actors", int(len(df_top_actors)))

    st.subheader("Report: Budget vs Runtime")
    st.dataframe(df_budget_runtime, use_container_width=True)
    st.bar_chart(df_budget_runtime.set_index("budget_bucket")["movie_count"])

    st.subheader("Report: Language vs Decade")
    st.dataframe(df_language_decade, use_container_width=True)

    st.subheader("Top Actors")
    st.dataframe(df_top_actors, use_container_width=True)
    st.bar_chart(df_top_actors.set_index("actor_name")["avg_user_rating"])

except Exception as exc:
    st.error(f"Database/UI error: {exc}")
    st.info("Verifica daca view-urile din P3 au fost create si conexiunea PostgreSQL este disponibila.")
    
    # Show detailed error information
    import traceback
    with st.expander("Show detailed error"):
        st.code(traceback.format_exc())
