SELECT *
FROM {{ref('fact_weather_observations')}}
WHERE humidity_pct<0 OR humidity_pct>100