--Documents/cours Openclassrooms/Data Engineer/projet 8/greencoop_projet/models/staging/stg_station_meteo_infoclimat.sql
{{config(materialized='view')}}


SELECT 
    observation_date::date,
    year::integer,
    month::integer,
    day::integer
FROM {{source('weather_data','Calendar')}} raw



    


   
