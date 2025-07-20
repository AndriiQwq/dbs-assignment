
DO $$
BEGIN
    PERFORM sp_reset_test_data();

    TRUNCATE TABLE combats, combat_players, combat_logs, game_items;

    -- Create a new combat
    INSERT INTO combats (id, rounds_count)
    VALUES
    (1, 1);

    -- Add combat players
    INSERT INTO combat_players (combat_id, character_id, entry_health)
    VALUES
    (1, 1, 100),
    (1, 2, 60),
    (1, 3, 80);

    -- Add random logical combat logs
    INSERT INTO combat_logs (
         combat_id, character_id, character2_id,
         action, event_msg_type, round_number,
         damage, damage_type, spell_id
    )
    VALUES
    (1, 1, 2, 'attack', 'success', 1, 20, 'physical', NULL),
    (1, 2, 1, 'cast_spell', 'success', 1, 25, 'magical', 1),
    (1, 3, 2, 'cast_spell', 'failure', 1, 0, 'magical' , 2);

    PERFORM sp_reset_round(1);

    -- Check the result of the reset round in the combat
    IF (SELECT 1 FROM combat_logs WHERE combat_id = 1 AND round_number = 2 AND action = 'reset_round') THEN -- add check time?
        RAISE NOTICE 'Round was logged successfully.';
    ELSE
        RAISE EXCEPTION 'Round log fail.';
    END IF;

    IF (SELECT 1 FROM combats WHERE id = 1 AND rounds_count = 2) THEN
        RAISE NOTICE 'Combat round was updated successfully.';
    ELSE
        RAISE EXCEPTION 'Combat fail to update round.';
    END IF;

    RAISE NOTICE 'TEST PASSED';
end;
$$;

-- CHECK ROUND COUNT AND COMBAT LOG
SELECT * FROM combat_logs;
SELECT * FROM combats;


