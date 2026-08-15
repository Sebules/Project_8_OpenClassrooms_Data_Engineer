--Documents/cours Openclassrooms/Data Engineer/projet 8/greencoop_projet/models/marts/dim_time.sql
{{ config(
    materialized = 'table',
       
    post_hook = [
                
        "CREATE INDEX IF NOT EXISTS idx_dim_time_observation_time
        ON {{this}} (observation_time)"
    ]
) }}

SELECT
    observation_time::time,
    hour,
    minute
FROM {{ref('time_data')}}