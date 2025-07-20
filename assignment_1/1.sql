-- comp two event during joining (1x2) first player table with second player table
WITH game_info as (
    SELECT
        p_record.player1_id,
        p_record.event_msg_type,
        p_record.pctimestring as period_time,
        p_record.event_number,
        p_record.period,
        p_record.game_id
    FROM play_records p_record
    WHERE game_id = {{game_id}}
)
SELECT
    p_record.player1_id,
    player.first_name,
    player.last_name,
    p_record.period,
    p_record.pctimestring as period_time
FROM game_info g_info
JOIN play_records p_record on p_record.game_id = g_info.game_id
JOIN players player ON player.id = g_info.player1_id
WHERE
    g_info.player1_id = p_record.player1_id and
    g_info.event_number = p_record.event_number - 1 and
    g_info.event_msg_type = 'REBOUND' and -- first event
    p_record.event_msg_type = 'FIELD_GOAL_MADE' and -- second event
    g_info.period = p_record.period
ORDER BY g_info.period, g_info.period_time DESC, g_info.player1_id;
