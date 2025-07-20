

DO $$
BEGIN
    PERFORM sp_reset_test_data();

    TRUNCATE TABLE combats, combat_players, combat_logs, game_items;

    -- Create a new combat
    INSERT INTO combats (id, rounds_count)
    VALUES
    (1, 1);

    -- Add combat players, enter combat
    PERFORM sp_enter_combat(1, 3);
    -- combat_players contains unique character_id and combat_id!!!

    -- Check combat log, combat players list
    IF (SELECT 1 FROM combat_logs WHERE combat_id = 1 AND character_id = 3 AND event_msg_type = 'success' AND action = 'enter_combat') THEN
        RAISE NOTICE 'Logged successfully.';
    ELSE
        RAISE EXCEPTION 'Log fail.';
    END IF;

    IF (SELECT 1 FROM combat_players WHERE combat_id = 1 AND character_id = 3) THEN
        RAISE NOTICE 'Combat player added to the combat players list.';
    ELSE
        RAISE EXCEPTION 'Combat player not added.';
    END IF;

    RAISE NOTICE 'TEST PASSED';
end;
$$;

SELECT * FROM combat_players;

