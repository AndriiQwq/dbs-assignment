WITH played_games_stat as (
    SELECT
           team_id,
           city,
           nickname,
           SUM( CASE WHEN home_team_id = th.team_id THEN 1
                ELSE 0 END
           ) as number_home_matches,
           SUM(
                CASE WHEN away_team_id = th.team_id THEN 1
                ELSE 0 END
           ) as number_away_matches,
          COUNT(*) as total_matches
    FROM team_history th
    JOIN games ON (games.home_team_id = th.team_id  or games.away_team_id = th.team_id )
    WHERE games.game_date BETWEEN
        MAKE_DATE(year_founded, 7, 1) and
        MAKE_DATE(CASE WHEN year_active_till = 2019 THEN 2025 ELSE year_active_till END, 6, 30)
    GROUP BY th.team_id, th.city, th.nickname, th.year_founded, th.year_active_till
)
SELECT  team_id,
        city || ' ' || nickname as team_name, -- or use concat method
        SUM(number_away_matches) as number_away_matches,
        ROUND(SUM(number_away_matches)::numeric / SUM(total_matches) * 100, 2) as percentage_away_matches,
        SUM(number_home_matches) as number_home_matches,
        ROUND(SUM(number_home_matches)::numeric / SUM(total_matches) * 100, 2) as percentage_home_matches,
        SUM(total_matches) as total_matches
FROM played_games_stat
GROUP BY team_id, city, nickname
ORDER BY team_id, team_name;


-- A 1950-74 B 75-79 A 80 - 83, A -> games in period 1950-74 and 80-83

-- 1610612740,New Orleans,Pelicans,2013,2019,7
-- 1610612740,New Orleans,Hornets,2007,2012,8
-- 1610612740,New Orleans,Hornets,2002,2004,10
-- 1610612762,New Orleans,Jazz,1974,1978,46

-- SELECT *
-- FROM played_games
