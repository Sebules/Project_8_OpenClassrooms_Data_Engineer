--Documents/cours Openclassrooms/Data Engineer/projet 8/greencoop_projet/models/staging/stg_Weather_Underground_Ichtegem_BE.sql
{{config(materialized='view')}}

SELECT
    'IICHTE19' as station_id, -- injection de l'identifiant de la station
    "UV" AS uv_index,
    -- Rafales : mph -> km/h
    ROUND(REGEXP_REPLACE("Gust", '[^0-9\.\-]', '', 'g')::NUMERIC * 1.60934, 2)  AS wind_gust_kmh,
    "Date"::date AS observation_date,
    "Time"::time AS observation_time,
    -- Vent: passage des valeurs en degrés par cohérence avec les données officielles
    CASE LOWER("Wind")
        WHEN 'north' THEN 0
        WHEN 'nne'   THEN 22.5
        WHEN 'ne'    THEN 45
        when 'ene'   THEN 67.5
        WHEN 'east'  THEN 90
        WHEN 'ese'   THEN 112.5
        WHEN 'se'    THEN 135
        WHEN 'sse'   THEN 157.5
        WHEN 'south' THEN 180
        WHEN 'ssw'   THEN 202.5
        WHEN 'sw'    THEN 225
        WHEN 'wsw'   THEN 247.5
        WHEN 'west'  THEN 270
        WHEN 'wnw'   THEN 292.5
        WHEN 'nw'    THEN 315
        WHEN 'nnw'   THEN 337.5
    ELSE null
    END
    AS wind_direction_deg,
    REGEXP_REPLACE("Solar", '[^0-9\.\-]', '', 'g')::NUMERIC AS solar_wm2,
    -- Vitesse vent : mph -> km/h (×1.60934)
    ROUND(REGEXP_REPLACE("Speed", '[^0-9\.\-]', '', 'g')::NUMERIC * 1.60934, 2) AS wind_speed_kmh,
    -- Humidité déjà en pourcentage
    REGEXP_REPLACE("Humidity", '[^0-9\.\-]', '', 'g')::NUMERIC AS humidity_pct,
    -- Pression : inHg → hPa (×33.8639)
    ROUND(REGEXP_REPLACE("Pressure", '[^0-9\.\-]', '', 'g')::NUMERIC * 33.8639, 2) AS pressure_hPa,
    -- Point de rosée : °F -> °C
    ROUND((REGEXP_REPLACE("Dew_Point",'[^0-9\.\-]', '', 'g')::NUMERIC - 32) * 5.0/9.0, 2) AS dew_point_c,
    -- Température : °F -> °C
    ROUND((REGEXP_REPLACE("Temperature", '[^0-9\.\-]', '', 'g')::NUMERIC - 32) * 5.0/9.0, 2) AS temperature_c,
    -- Précipitations : inch -> mm (×25.4)
    ROUND(REGEXP_REPLACE("Precip__Rate_", '[^0-9\.\-]', '', 'g')::NUMERIC * 25.4, 2) AS precip_rate_mm,
    ROUND(REGEXP_REPLACE("Precip__Accum_", '[^0-9\.\-]', '', 'g')::NUMERIC * 25.4, 2) AS precip_accum_mm
    
FROM {{ source('weather_data','Weather_Underground_Ichtegem_BE') }}
