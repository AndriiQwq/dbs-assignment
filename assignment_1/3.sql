WITH player_records_sorted_by_game_id AS (
    SELECT player1_id, player2_id, event_msg_type, score, event_number
    FROM play_records
    WHERE game_id = {{game_id}} -- {{game_id}} 21701185
),
game_players AS (
    SELECT DISTINCT player_id
    FROM (
        SELECT UNNEST(ARRAY[player1_id, player2_id]) AS player_id
        FROM player_records_sorted_by_game_id
    ) sb
    WHERE player_id IS NOT NULL
),
players_missed_shots AS (
    SELECT
        player_id,
        COUNT(*) AS missed_shots
    FROM player_records_sorted_by_game_id pr
    JOIN game_players ON player1_id = player_id
    WHERE event_msg_type = 'FIELD_GOAL_MISSED' and player1_id = player_id
    GROUP BY player_id
)
,
points_mades_prepared AS (
  SELECT prsbgi.player1_id as player1_id,
         prsbgi.score,
         prsbgi.event_msg_type,
         LAG(prsbgi.score) OVER (ORDER BY prsbgi.event_number) AS prev_score_margin_first_player
  FROM player_records_sorted_by_game_id prsbgi
  WHERE player1_id IS NOT NULL
    and event_msg_type IN ('FIELD_GOAL_MADE', 'FREE_THROW')
    and score IS NOT NULL
),
points_mades AS (
  SELECT
    player1_id,
    SUM (
        CASE WHEN
                (
                 prev_score_margin_first_player IS NULL
                 and ABS(
                          (CAST(SPLIT_PART(score, ' - ', 1) as INTEGER)) -
                          (CAST(SPLIT_PART(score, ' - ', 2) as INTEGER))
                     ) = 2
                )
            THEN 1
            WHEN
                prev_score_margin_first_player IS NOT NULL
                and (ABS(
                        ABS(
                                (CAST(SPLIT_PART(score, ' - ', 1) as INTEGER)) -
                                (CAST(SPLIT_PART(prev_score_margin_first_player, ' - ', 1) as INTEGER))
                        )
                            -
                        ABS(
                                (CAST(SPLIT_PART(score, ' - ', 2) as INTEGER)) -
                                (CAST(SPLIT_PART(prev_score_margin_first_player, ' - ', 2) as INTEGER))
                        )
                     )
                ) = 2
            THEN 1
            ELSE 0
        END
    ) as "2PM",
        SUM (
        CASE WHEN
                (
                 prev_score_margin_first_player IS NULL
                 and ABS(
                          (CAST(SPLIT_PART(score, ' - ', 1) as INTEGER)) -
                          (CAST(SPLIT_PART(score, ' - ', 2) as INTEGER))
                     ) = 3
                )
            THEN 1
            WHEN
                prev_score_margin_first_player IS NOT NULL
                and (ABS(
                        ABS(
                                (CAST(SPLIT_PART(score, ' - ', 1) as INTEGER)) -
                                (CAST(SPLIT_PART(prev_score_margin_first_player, ' - ', 1) as INTEGER))
                        )
                            -
                        ABS(
                                (CAST(SPLIT_PART(score, ' - ', 2) as INTEGER)) -
                                (CAST(SPLIT_PART(prev_score_margin_first_player, ' - ', 2) as INTEGER))
                        )
                     )
                ) = 3
            THEN 1
            ELSE 0
        END
    ) as "3PM"

  FROM points_mades_prepared
  GROUP BY player1_id
),
free_throws AS (
    SELECT
        player1_id,
        SUM (
            CASE
                WHEN event_msg_type = 'FREE_THROW'
                    and score IS NOT NULL THEN 1
                ELSE 0
            END
        ) as FTM,
        SUM (
            CASE
                WHEN event_msg_type = 'FREE_THROW'
                     and score IS NULL THEN 1
                ELSE 0
            END
        ) as missed_free_throws
    FROM player_records_sorted_by_game_id
    WHERE player1_id IS NOT NULL -- and event_msg_type = 'FREE_THROW' -- delete some records lines
    GROUP BY player1_id
)
SELECT
    player.id,
    player.first_name,
    player.last_name,
    COALESCE("2PM", 0) * 2 + COALESCE("3PM", 0) * 3 + COALESCE(FTM, 0) as points,
    COALESCE("2PM", 0) as "2PM",
    COALESCE("3PM", 0) as "3PM",
    COALESCE(missed_shots, 0) as missed_shots,
    COALESCE(
            ROUND(
                ((COALESCE("2PM", 0) + COALESCE("3PM", 0))::numeric /
                    NULLIF((COALESCE("2PM", 0) + COALESCE("3PM", 0) + COALESCE(missed_shots, 0)), 0)) * 100, -- to cast to rational you can use 100.0 or use ::numeric, in this case we cast COALESCE("3PM", 0))::numeric so we don't need to cast 100 to 100.0, due to postgre cast it by mul(100, a.x) = 100.0 * a.x
            2),
    0) as shooting_percentage,
    FTM,
    missed_free_throws,
    COALESCE(
            ROUND(
                (COALESCE(FTM, 0)::numeric /
                   NULLIF((COALESCE(FTM, 0) + COALESCE(missed_free_throws, 0)), 0)) * 100,
            2),
    0) as FT_percentage
FROM free_throws
LEFT JOIN players player ON player.id = free_throws.player1_id
LEFT JOIN points_mades ON points_mades.player1_id = free_throws.player1_id
LEFT JOIN players_missed_shots ON players_missed_shots.player_id = free_throws.player1_id
ORDER BY points DESC, shooting_percentage DESC, player.id ASC;
-- records_sorted_by_game_id
-- ORDER BY missed_shots DESC, player_id ASC;

-- select * from play_records where score IS NOT NULL ORDER BY game_id, event_number limit 50;
