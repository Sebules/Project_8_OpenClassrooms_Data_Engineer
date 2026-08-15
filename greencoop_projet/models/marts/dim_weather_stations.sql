--Documents/cours Openclassrooms/Data Engineer/projet 8/greencoop_projet/models/marts/dim_weather_stations.sql
{{ config(
    materialized = 'table',
       
    post_hook = [
                
        "CREATE INDEX IF NOT EXISTS idx_dim_weather_stations_station_id
        ON {{this}} (station_id)",
        
        "CREATE INDEX IF NOT EXISTS idx_dim_weather_stations_city
        ON {{this}} (city)",
        
        "CREATE INDEX IF NOT EXISTS idx_dim_weather_stations_station_type
        ON {{this}} (station_type)",
    
        "ALTER TABLE {{this}} DROP CONSTRAINT IF EXISTS chk_station_type",
        "ALTER TABLE {{this}}
        ADD CONSTRAINT chk_station_type
        CHECK (station_type IN ('amateur','officielle'))",
    
        "ALTER TABLE {{this}} DROP CONSTRAINT IF EXISTS chk_dim_weather_latitude",
        "ALTER TABLE {{this}}
        ADD CONSTRAINT chk_dim_weather_latitude
        CHECK (latitude BETWEEN -90 AND 90)",
    
        "ALTER TABLE {{this}} DROP CONSTRAINT IF EXISTS chk_dim_weather_longitude",
        "ALTER TABLE {{this}}
        ADD CONSTRAINT chk_dim_weather_longitude
        CHECK (longitude BETWEEN -180 AND 180)"
    
    ]
) }}

SELECT
    station_id,
    station_name,
    latitude,
    longitude,
    elevation,
    city,
    state,
    hardware,
    software,
    'amateur' AS station_type
FROM {{ ref('metadonnees_stations_amateurs') }}

UNION ALL

SELECT
    station_id,
    CONCAT(station_name,'_',type) AS station_name,
    latitude,
    longitude,
    elevation,
    station_name AS city,
    null::integer AS state,
    null::varchar AS hardware,
    null::varchar AS software,
    'officielle' AS station_type
FROM {{ ref('stg_station_meteo_infoclimat') }}