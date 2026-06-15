select
    id,
    day,
    stress_high,
    recovery_high,
    day_summary,
    _fivetran_synced
from {{ source('oura_ring_data', 'daily_stress') }}
where not coalesce(_fivetran_deleted, false)
