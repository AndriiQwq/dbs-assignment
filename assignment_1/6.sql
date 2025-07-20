WITH plyaer_id as (
    SELECT id
    FROM players
    WHERE first_name = '{{first_name}}' AND last_name = '{{last_name}}'
    LIMIT 1
),
player_games as (
    SELECT DISTINCT
        game_id

    FROM play_records
    WHERE player1_id = (SELECT id FROM plyaer_id)
       OR player2_id = (SELECT id FROM plyaer_id)
),
selected_player_seasons as (
    SELECT season_id
    FROM games game
    JOIN player_games ppr ON game.id = ppr.game_id
    WHERE season_type = 'Regular Season'
    GROUP BY season_id
    HAVING COUNT(DISTINCT game.id) >= 50
),
seasons_success as (
    SELECT
           g.season_id,
           p_game.game_id,
           SUM((
                CASE
                    WHEN event_msg_type = 'FIELD_GOAL_MADE' and player1_id = (SELECT id FROM plyaer_id) THEN 1 ELSE 0
                END
           ) * 100::numeric )/ NULLIF(
                SUM(
                    CASE
                        WHEN event_msg_type IN (
                                                'FIELD_GOAL_MADE',
                                                'FIELD_GOAL_MISSED'
                                            ) and player1_id = (SELECT id FROM plyaer_id) THEN 1 ELSE 0
                    END
                ), 0
           ) as game_success
    FROM play_records p_records
    JOIN player_games p_game on p_game.game_id = p_records.game_id
    JOIN games g ON g.id = p_records.game_id
    JOIN selected_player_seasons sps ON sps.season_id = g.season_id
    GROUP BY g.season_id, p_game.game_id
),
prepere_to_calculate_stability as (
    SELECT
        season_id,
        game_success,
        game_id,
        LAG(game_success) OVER (PARTITION BY season_id ORDER BY game_id) as prev_success
    FROM seasons_success
),
games_stability as (
    SELECT
        season_id,
        (
            SUM(
                CASE
                    WHEN prev_success IS NULL THEN 0 -- first game
                    ELSE ABS(game_success - prev_success)
                END
            )::numeric / COUNT(*) -- don't need to check for zero value, min 50 games
        ) as stability
    FROM prepere_to_calculate_stability
    GROUP BY season_id
)
SELECT season_id, ROUND(AVG(stability), 2) as stability
FROM games_stability
GROUP BY season_id -- group game stability by season
ORDER BY stability, season_id;
