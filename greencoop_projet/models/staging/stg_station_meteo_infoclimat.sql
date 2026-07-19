{{config(materialized='view')}}
select
    station.key as station_id,
    (obs.value ->> 'dh_utc')::timestamp as observation_datetime,
    (obs.value ->> 'temperature')::numeric as temperature_c,
    (obs.value ->> 'pression')::numeric as pressure_hpa,
    (obs.value ->> 'humidite')::numeric as humidity_pct,
    (obs.value ->> 'point_de_rosee')::numeric as dew_point_c,
    (obs.value ->> 'vent_moyen')::numeric as wind_speed_kmh,
    (obs.value ->> 'vent_rafales')::numeric as wind_gust_kmh,
    (obs.value ->> 'vent_direction')::numeric as wind_direction_deg,
    (obs.value ->> 'pluie_3h')::numeric as precip_3h_mm,
    (obs.value ->> 'pluie_1h')::numeric as precip_1h_mm
from {{source('weather_data','station_meteo_infoclimat')}} raw
cross join lateral jsonb_each(raw.hourly) as station(key, value)
cross join lateral jsonb_array_elements(station.value) as obs(value)
where station.key != '_params'