-- Documents/cours Openclassrooms/Data Engineer/projet 8/greencoop_projet/models/marts/fact_weather_observations.sql

{{ config(materialized='table',
    
    post_hook=[

        "ALTER TABLE {{this}}
        ADD CONSTRAINT pk_fact_weather_observations
        PRIMARY KEY (station_id, observation_date, observation_time)",
        
        "ALTER TABLE {{this}}
        ADD CONSTRAINT fk_fact_weather_observations_weather_station
        FOREIGN KEY (station_id)
        REFERENCES {{ref('dim_weather_stations')}} (station_id)",

        "CREATE INDEX IF NOT EXISTS idx_fact_weather_observations_observation_time
        ON {{this}} (observation_time)",

        "CREATE INDEX IF NOT EXISTS idx_fact_weather_observations_observation_date
        ON {{this}} (observation_date)",
    
        "ALTER TABLE {{this}}
        ADD CONSTRAINT chk_fact_weather_observations_humidity
        CHECK (humidity_pct IS NULL OR humidity_pct BETWEEN 0 AND 100 )",
    
        "ALTER TABLE {{this}}
        ADD CONSTRAINT chk_fact_weather_observations_wind_direction
        CHECK (wind_direction_deg IS NULL OR wind_direction_deg BETWEEN 0 AND 360)",
    
        "ALTER TABLE {{this}}
        ADD CONSTRAINT chk_fact_weather_observations_pressure
        CHECK (pressure_hpa IS NULL OR pressure_hpa BETWEEN 800 AND 1100)",
    
        "ALTER TABLE {{this}}
        ADD CONSTRAINT chk_fact_weather_observations_precipitation
        CHECK (
            (precip_rate_mm IS NULL OR precip_rate_mm >= 0)
            AND
            (precip_accum_mm IS NULL OR precip_accum_mm >= 0)
        )",
    
        "ALTER TABLE {{this}}
        ADD CONSTRAINT chk_fact_weather_observations_wind_speed
        CHECK (
            (wind_speed_kmh IS NULL OR wind_speed_kmh >= 0)
            AND
            (wind_gust_kmh IS NULL OR wind_gust_kmh >= 0)
        )"
    ]
) }}

SELECT
    station_id,
    observation_date,
    observation_time,
    temperature_c,
    dew_point_c,
    pressure_hpa,
    humidity_pct,
    wind_speed_kmh, 
    wind_gust_kmh,
    wind_direction_deg,
    precip_rate_mm,
    precip_accum_mm
FROM {{ ref('int_weather_observations_unified') }}