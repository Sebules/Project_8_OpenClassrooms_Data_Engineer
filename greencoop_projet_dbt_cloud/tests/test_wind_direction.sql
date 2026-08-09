SELECT *
FROM {{ref('fact_weather_observations')}}
WHERE wind_direction_deg < 0 OR wind_direction_deg > 360