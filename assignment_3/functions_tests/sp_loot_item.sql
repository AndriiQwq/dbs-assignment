

DO $$
BEGIN
    PERFORM sp_reset_test_data();

    TRUNCATE TABLE combats, combat_players, combat_logs, game_items CASCADE;
    TRUNCATE TABLE inventories;

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

    -- Initialize combat items
    PERFORM sp_initialize_combat_items(1);

    INSERT INTO combat_logs (
         combat_id, character_id, character2_id,
         action, event_msg_type, round_number,
         damage, damage_type, spell_id
    )
    VALUES
    (1, 2, 1, 'cast_spell', 'success', 1, 25, 'magical', 1),
    (1, 3, 2, 'cast_spell', 'failure', 1, 0, 'magical' , 2);


    -- Actually P2 and P3 do their actions, and P1 want to loot item 1

    -- Character 1 loot item 1
    PERFORM sp_loot_item(1, 1, 1);

    -- Check the result of the loot item

    -- Check game area items
    IF (SELECT 1 FROM game_items WHERE combat_id = 1 AND item_id = 1 AND character_id = 1 AND event_type IN ('spawn & pickup', 'drop & pickup', 'pickup')) THEN
        RAISE NOTICE 'Item was looted by character successfully.';
    ELSE
        RAISE EXCEPTION 'Loot item fail.';
    END IF;

    -- Check inventory of character 1
    IF (SELECT 1 FROM inventories WHERE character_id = 1 AND item_id = 1) THEN
        RAISE NOTICE 'Item was added to inventory successfully.';
    ELSE
        RAISE EXCEPTION 'Item adding to inventory fail.';
    END IF;

    -- Check combat logs
    IF (SELECT 1 FROM combat_logs WHERE combat_id = 1 AND character_id = 1 AND event_msg_type = 'success' AND action = 'loot_item') THEN
        RAISE NOTICE 'Loot was logged successfully.';
    ELSE
        RAISE EXCEPTION 'Log fail.';
    END IF;

    RAISE NOTICE 'TEST PASSED';
end;
$$;

SELECT * FROM game_items;
SELECT * from inventories;
SELECT * FROM item_storages;

