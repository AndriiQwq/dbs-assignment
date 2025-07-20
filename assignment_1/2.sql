WITH season_games as (
    SELECT DISTINCT
        id as game_id
    FROM games
    WHERE season_id = '{{season_id}}'
),
season_play_records as (  -- UPDATE IN FUTURE, REPLECE * WITH NEDDED COLUMNS
    SELECT
        game_id,
        player1_id,
        player2_id,
        player1_team_id,
        player2_team_id,
        score,
        event_msg_type
    FROM play_records
    WHERE game_id IN (SELECT game_id FROM season_games)
--         and event_msg_type IN ('FREE_THROW', 'FIELD_GOAL_MADE', 'FIELD_GOAL_MISSED', 'REBOUND')
),
players_with_teams as (
    SELECT DISTINCT
        players_with_teams.player_id,
        players_with_teams.team_id
    FROM (
        SELECT
            UNNEST(ARRAY[player1_id, player2_id]) AS player_id,
            UNNEST(ARRAY[player1_team_id, player2_team_id]) AS team_id
        FROM season_play_records
        WHERE player1_id IS NOT NULL OR player2_id IS NOT NULL
    ) AS players_with_teams
    WHERE players_with_teams.player_id IS NOT NULL AND players_with_teams.team_id IS NOT NULL
),
players_with_count_of_teams as (
    SELECT
        player_id,
        COUNT(DISTINCT team_id) as count_of_team_changes
    FROM players_with_teams
    GROUP BY player_id
),
top_5_players as (
    SELECT
        player_id as player_id
--         ,count_of_team_changes -- for testign
    FROM players_with_count_of_teams
    ORDER BY count_of_team_changes DESC--, player_id ASC
    LIMIT 5
),
player_statistics as (
    SELECT
        top_5_players.player_id,
        pwt.team_id,
        COUNT(DISTINCT game_id) as games,
        SUM(
            CASE
                WHEN event_msg_type = 'FIELD_GOAL_MADE' AND player1_id = top_5_players.player_id THEN 2
                WHEN event_msg_type = 'FREE_THROW' AND score IS NOT NULL AND player1_id = top_5_players.player_id THEN 1
                ELSE 0
            END
        ) as points,
        SUM(
            CASE
                WHEN event_msg_type = 'FIELD_GOAL_MADE' AND player2_id = top_5_players.player_id THEN 1
                ELSE 0
            END
        ) AS assists
    FROM top_5_players
    JOIN season_play_records spr ON spr.player1_id = top_5_players.player_id OR spr.player2_id = top_5_players.player_id
    JOIN players_with_teams pwt ON
        top_5_players.player_id = pwt.player_id
        AND (
            (spr.player1_id = pwt.player_id AND spr.player1_team_id = pwt.team_id) OR
            (spr.player2_id = pwt.player_id AND spr.player2_team_id = pwt.team_id)
        )
    WHERE event_msg_type IN ('FREE_THROW', 'FIELD_GOAL_MADE', 'FIELD_GOAL_MISSED', 'REBOUND')
    GROUP BY top_5_players.player_id, pwt.team_id
)
SELECT
     player_id,
     first_name,
     last_name,
     team_id,
     team.full_name,
     ROUND(points::numeric / games, 2) as PPG, -- we should not need to test games for zero value
     ROUND(assists::numeric / games, 2) as APG,
     games
FROM player_statistics
JOIN players player on player.id = player_id
JOIN teams team on team.id = team_id
ORDER BY player_id ASC, team_id ASC;









