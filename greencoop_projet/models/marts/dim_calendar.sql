--Documents/cours Openclassrooms/Data Engineer/projet 8/greencoop_projet/models/marts/dim_calendar.sql
{{ config(
    materialized = 'table',
       
    post_hook = [
                
        "CREATE INDEX IF NOT EXISTS idx_dim_calendar_observation_date
        ON {{this}} (observation_date)"
    ]
) }}

SELECT
    observation_date,
    year,
    month,
    day
FROM {{ref('stg_calendar')}}