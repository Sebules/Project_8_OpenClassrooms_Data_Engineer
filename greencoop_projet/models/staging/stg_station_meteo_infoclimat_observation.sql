-- Documents/cours Openclassrooms/Data Engineer/projet 8/greencoop_projet/models/staging/stg_station_meteo_infoclimat_observation.sql
{{config(materialized='view')}}

SELECT 
    station.key AS station_id,
    (obs.value ->> 'dh_utc')::timestamp AS observation_time,
    (obs.value ->> 'temperature')::numeric AS temperature_c,
    (obs.value ->> 'pression')::numeric AS pressure_hpa,
    (obs.value ->> 'humidite')::numeric AS humidity_pct,
    (obs.value ->> 'point_de_rosee')::numeric AS dew_point_c,
    (obs.value ->> 'vent_moyen')::numeric AS wind_speed_kmh,
    (obs.value ->> 'vent_rafales')::numeric AS wind_gust_kmh,
    (obs.value ->> 'vent_direction')::numeric AS wind_direction_deg,
    (obs.value ->> 'pluie_3h')::numeric AS precip_accum_mm,
    (obs.value ->> 'pluie_1h')::numeric AS precip_rate_mm
FROM  {{source('weather_data','station_meteo_infoclimat')}} raw
CROSS JOIN LATERAL jsonb_each(raw.hourly) AS station(key,value) -- hourly est un dictionnaire. jsonb_each permet d'ouvrir le dictionnaire; On a ensuite un tableau
CROSS JOIN LATERAL jsonb_array_elements(station.value) AS obs(value) -- jsonb_array_elements permet de récupérer chaque élément du tableau station.
WHERE station.key != '_params' -- nécessaire car il y a une clé '_params' dans le tableau mais qui est vide. Cela crée des erreurs.