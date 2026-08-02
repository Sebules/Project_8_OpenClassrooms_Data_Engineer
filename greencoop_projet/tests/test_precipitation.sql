SELECT * 
    FROM {{ref('fact_weather_observations')}}
    WHERE precip_accum_mm < 0 OR precip_rate_mm < 0