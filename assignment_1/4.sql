WITH season_games as (
    SELECT game.id as game_id
    FROM games game
    WHERE game.season_id =  '{{season_id}}' --'22018' {{season_id}}
),
all_season_games_players as (
    SELECT DISTINCT player_id
    FROM (
        SELECT UNNEST(ARRAY[player1_id, player2_id]) as player_id
        FROM play_records p_record
        JOIN season_games sg ON sg.game_id = p_record.game_id
         ) as sb
    WHERE player_id IS NOT NULL
),
game_info as (
    SELECT
        player_id,
        p_record.event_msg_type,
        p_record.score,
        s_game.game_id,
        player2_id,
        player1_id
    FROM season_games s_game
    JOIN play_records p_record ON p_record.game_id = s_game.game_id and p_record.event_msg_type IN ('REBOUND', 'FIELD_GOAL_MADE', 'FREE_THROW')
    JOIN all_season_games_players p_player ON p_player.player_id = p_record.player1_id or p_player.player_id = p_record.player2_id
--     WHERE p_record.event_msg_type IN ('REBOUND', 'FIELD_GOAL_MADE', 'FREE_THROW')
),
triple_double_count as (
    SELECT
           g_info.player_id,
           g_info.game_id,
           SUM(
               CASE
                   WHEN
                        g_info.event_msg_type = 'REBOUND' and
                        player1_id = g_info.player_id
                   THEN 1 ELSE 0
               END
           ) as rebounds,
           SUM(
                CASE
                     WHEN g_info.event_msg_type = 'FIELD_GOAL_MADE' and
                          player1_id = g_info.player_id
                     THEN 2
                     WHEN g_info.event_msg_type = 'FREE_THROW' and
                          g_info.score IS NOT NULL and
                          player1_id = g_info.player_id
                     THEN 1 ELSE 0
                END
           ) as points,
            SUM(
                CASE
                    WHEN g_info.event_msg_type = 'FIELD_GOAL_MADE' and
                         player2_id = g_info.player_id
                    THEN 1 ELSE 0
                END
            ) AS assists
    FROM game_info g_info
--     WHERE player_id = 201566
    GROUP BY g_info.player_id, g_info.game_id
--     ORDER BY player_id, game_id
),
columns as (
    SELECT
        player_id,
        game_id,
        (
            CASE
                WHEN assists >= 10 and points >= 10 and rebounds >= 10 THEN 1
                ELSE 0
            END
            ) as triple_game
    FROM triple_double_count
) ,
steak_calculation as (
    SELECT
        player_id,
        game_id,
        SUM(
            CASE
                WHEN triple_game = 1 THEN 0
                ELSE 1
            END
        ) OVER (PARTITION BY player_id ORDER BY  game_id) as grouped_value
    FROM columns
),
streak_groups AS (
    SELECT
        *,
        CASE
            WHEN grouped_value = 0 THEN 0
            ELSE ROW_NUMBER() OVER (PARTITION BY player_id, grouped_value ORDER BY  game_id) - 1
        END as result
    FROM steak_calculation
)
SELECT DISTINCT
    player_id,
    MAX(result) OVER (PARTITION BY player_id) as max_strike
FROM streak_groups
GROUP BY player_id, result
HAVING MAX(result) > 0
ORDER BY max_strike DESC, player_id;

-- 0 1
-- 1 1
-- 1 1
-- 0 2
-- 0 3
-- 0 4
-- 1 4
-- 1 4
-- 1 4
-- 1 4
-- 0 5
-- >>> (5x4)-- = 4x4
