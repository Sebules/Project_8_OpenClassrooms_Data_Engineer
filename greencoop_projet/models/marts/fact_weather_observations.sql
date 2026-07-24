-- Documents/cours Openclassrooms/Data Engineer/projet 8/greencoop_projet/models/marts/fact_weather_observations.sql

{{ config(materialized='table') }}

SELECT
    station_id,
    observation_time,
    temperature_c,
    dew_point_c,
    pressure_hpa,
    humidity_pct,
    wind_speed_kmh, 
    wind_gust_kmh,
    wind_direction_deg,
    precip_rate_mm,
    precip_accum_mm
FROM {{ ref('int_weather_observations_unified') }}