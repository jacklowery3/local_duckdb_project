with activity as (
    select * from {{ ref('stg_oura__daily_activity') }}
),

readiness as (
    select * from {{ ref('stg_oura__daily_readiness') }}
),

sleep as (
    select * from {{ ref('stg_oura__daily_sleep') }}
),

stress as (
    select * from {{ ref('stg_oura__daily_stress') }}
),

final as (
    select
        coalesce(a.day, r.day, sl.day, st.day)    as day,

        -- scores
        a.activity_score,
        r.readiness_score,
        sl.sleep_score,
        round(
            (coalesce(a.activity_score, 0)
             + coalesce(r.readiness_score, 0)
             + coalesce(sl.sleep_score, 0))
            / nullif(
                (a.activity_score is not null)::int
                + (r.readiness_score is not null)::int
                + (sl.sleep_score is not null)::int,
                0
            ),
            1
        )                                           as avg_score,

        -- activity
        a.steps,
        a.active_calories,
        a.total_calories,
        a.high_activity_time,
        a.medium_activity_time,
        a.sedentary_time,

        -- readiness
        r.temperature_deviation,
        r.contributors_hrv_balance,
        r.contributors_resting_heart_rate,
        r.contributors_recovery_index,

        -- sleep
        sl.contributors_deep_sleep,
        sl.contributors_rem_sleep,
        sl.contributors_efficiency,
        sl.contributors_restfulness,

        -- stress
        st.stress_high,
        st.recovery_high,
        st.day_summary as stress_summary

    from activity a
    full outer join readiness r  on r.day  = a.day
    full outer join sleep    sl  on sl.day = coalesce(a.day, r.day)
    full outer join stress   st  on st.day = coalesce(a.day, r.day, sl.day)
)

select * from final
order by day desc
