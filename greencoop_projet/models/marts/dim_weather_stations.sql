--Documents/cours Openclassrooms/Data Engineer/projet 8/greencoop_projet/models/marts/dim_weather_stations.sql
{{ config(materialized='table') }}

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