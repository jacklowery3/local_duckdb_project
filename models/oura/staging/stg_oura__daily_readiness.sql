select
    id,
    day,
    timestamp as readiness_timestamp,
    score as readiness_score,
    temperature_deviation,
    temperature_trend_deviation,
    contributors_activity_balance,
    contributors_body_temperature,
    contributors_hrv_balance,
    contributors_previous_day_activity,
    contributors_previous_night,
    contributors_recovery_index,
    contributors_resting_heart_rate,
    contributors_sleep_balance,
    _fivetran_synced
from {{ source('oura_ring_data', 'daily_readiness') }}
where not coalesce(_fivetran_deleted, false)
