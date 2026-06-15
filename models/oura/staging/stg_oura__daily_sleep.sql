select
    id,
    day,
    timestamp as sleep_timestamp,
    score as sleep_score,
    contributors_deep_sleep,
    contributors_efficiency,
    contributors_latency,
    contributors_rem_sleep,
    contributors_restfulness,
    contributors_timing,
    contributors_total_sleep,
    _fivetran_synced
from {{ source('oura_ring_data', 'daily_sleep') }}
where not coalesce(_fivetran_deleted, false)
