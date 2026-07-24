-- Documents/cours Openclassrooms/Data Engineer/projet 8/greencoop_projet/models/intermediate/int_weather_observations_unified.sql
WITH wu_be AS (
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
    FROM {{ ref('stg_Weather_Underground_Ichtegem_BE') }}
),

wu_fr AS (
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
    FROM {{ ref('stg_Weather_Underground_La_Madeleine_FR') }}
),

infoclimat AS (
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
    FROM {{ ref('stg_station_meteo_infoclimat_observation') }}
)

SELECT * FROM wu_be
UNION ALL
SELECT * FROM wu_fr
UNION ALL
SELECT * FROM infoclimat