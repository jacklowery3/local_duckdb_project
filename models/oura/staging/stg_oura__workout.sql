select
    id,
    day,
    activity,
    calories,
    distance,
    start_datetime,
    end_datetime,
    intensity,
    label,
    source,
    round(
        extract(epoch from (end_datetime - start_datetime)) / 60.0,
        1
    ) as duration_minutes,
    _fivetran_synced
from {{ source('oura_ring_data', 'workout') }}
where not coalesce(_fivetran_deleted, false)
