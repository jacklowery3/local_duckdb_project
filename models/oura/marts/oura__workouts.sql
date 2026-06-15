with workouts as (
    select * from {{ ref('stg_oura__workout') }}
),

final as (
    select
        id,
        day,
        activity,
        intensity,
        label,
        source,
        start_datetime,
        end_datetime,
        duration_minutes,
        calories,
        distance,
        round(distance / nullif(duration_minutes, 0), 2) as pace_per_minute
    from workouts
)

select * from final
order by start_datetime desc
