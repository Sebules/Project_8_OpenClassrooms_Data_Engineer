{{config(materialized='view')}}
SELECT
    "UV" AS uv_index,
    REGEXP_REPLACE("Gust", '[^0-9\.\-]', '', 'g')::NUMERIC AS gust_mph,
    "Time"::TIME AS observation_time,
    LOWER("Wind") AS wind_direction,
    REGEXP_REPLACE("Solar", '[^0-9\.\-]', '', 'g')::NUMERIC AS solar_wm2,
    REGEXP_REPLACE("Speed", '[^0-9\.\-]', '', 'g')::NUMERIC AS speed_mph,
    REGEXP_REPLACE("Humidity", '[^0-9\.\-]', '', 'g')::NUMERIC AS humidity_pct,
    REGEXP_REPLACE("Pressure", '[^0-9\.\-]', '', 'g')::NUMERIC AS pressure_in,
    REGEXP_REPLACE("Dew_Point",'[^0-9\.\-]', '', 'g')::NUMERIC AS dew_point_f,
    REGEXP_REPLACE("Temperature", '[^0-9\.\-]', '', 'g')::NUMERIC AS temperature_f,
    REGEXP_REPLACE("Precip__Rate_", '[^0-9\.\-]', '', 'g')::NUMERIC AS precip_rate_in,
    REGEXP_REPLACE("Precip__Accum_", '[^0-9\.\-]', '', 'g')::NUMERIC AS precip_accum_in
FROM {{source('weather_data','Weather_Underground_La_Madeleine_FR')}}