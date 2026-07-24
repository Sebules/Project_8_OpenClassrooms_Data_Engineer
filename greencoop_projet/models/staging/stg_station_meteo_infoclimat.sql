--Documents/cours Openclassrooms/Data Engineer/projet 8/greencoop_projet/models/staging/stg_station_meteo_infoclimat.sql
{{config(materialized='view')}}


SELECT
    s.value ->> 'id' AS station_id,
    s.value ->> 'name' AS station_name,
    (s.value ->> 'latitude')::numeric  AS latitude,
    (s.value ->> 'longitude')::numeric AS longitude,
    (s.value ->> 'elevation')::numeric AS elevation,
    s.value ->> 'type' AS type,
    s.value -> 'license' ->> 'license' AS license  -- -> retourne du JSON et ->> retourne du texte. Ici license est un dictionnaire, il faut faire une double transformation        
FROM {{source('weather_data','station_meteo_infoclimat')}} raw
CROSS JOIN LATERAL jsonb_array_elements(raw.stations) AS s(value)




    


   
