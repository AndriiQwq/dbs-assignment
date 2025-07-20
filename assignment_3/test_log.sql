-- Add data to the log

-- caster (id, name, constitution, dexterity, strength, health, intelligence)
-- (2, 'Mage', 5, 8, 4, 60, 12),
-- Equipment: shield(id:2) 'Steel Shield', weight:7, type_id:2, 'rare', 'armor' + 4
-- character_spells:
-- (1, category: 1, 'Fireball', cost: 10, 'common'),
-- (2, category: 2, 'Ice Spike', cost: 15, 'rare'),
-- spell_configurations:
-- (1, s_id: 1, 'base_damage', value: 20, 'strength'),
-- (2, s_id: 2, 'base_damage', value: 25, 'intelligence'),

-- caster (id, name, constitution, dexterity, strength, health, intelligence)
-- (4, 'Paladin', 'A holy knight', 12, 6, 8, 80, 8),
-- Equipment: (4, 500, 'accessory');
-- (500, 'Ring Storage', 1, 4, 'epic'); inventory + 3 ((3, 'inventory', 3))
-- character_spells:
--     (5, 4, 4),-- 'Paladin'
--     (6, 4, 3);
--     (3, 3, 'Lightning Bolt', 20, 'epic'),
--     (4, 4, 'Dark Wave', 8, 'uncommon'),
--     (3, 3, 'base_damage', 30, 'strength'),
--     (4, 4, 'base_damage', 15, 'strength'),
-- BONUS damage: (6, 3, 'damage', value: 10, 'constitution') based on target constitution

DO $$
DECLARE

BEGIN
    PERFORM sp_reset_test_data();

--     -- Reset characters
--     PERFORM sp_rest_character(1);
--     PERFORM sp_rest_character(2);
--     PERFORM sp_rest_character(3);

    TRUNCATE TABLE combats, combat_players, combat_logs, game_items CASCADE;

    -- Create a new combat
    INSERT INTO combats (id, rounds_count)
    VALUES (1, 1);

    -- Create combat players
    PERFORM sp_enter_combat(1, 1);
    PERFORM sp_enter_combat(1, 2);
    PERFORM sp_enter_combat(1, 4);

    -- Create combat items. AFTER entering players into combat!!!
    PERFORM sp_initialize_combat_items(1);

    -- Perform actions
    PERFORM sp_physical_attack(1, 2);
    PERFORM sp_cast_spell(2, 1, 2);
    PERFORM sp_cast_spell(4, 2, 4);

    -- Reset round
    PERFORM sp_reset_round(1);

    -- Perform actions
    BEGIN PERFORM sp_cast_spell(1, 2, 1);
    EXCEPTION WHEN OTHERS THEN NULL; -- When error occurred, do nothing
    END;
    BEGIN PERFORM sp_physical_attack(2, 4);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    BEGIN PERFORM sp_cast_spell(4, 1, 4);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- Reset round
    PERFORM sp_reset_round(1);

    -- Perform actions
    BEGIN PERFORM sp_physical_attack(1, 2);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    BEGIN PERFORM sp_cast_spell(2, 4, 2);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    BEGIN PERFORM sp_cast_spell(4, 1, 4);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- Reset round
    PERFORM sp_reset_round(1);

    -- Perform actions
    BEGIN PERFORM sp_physical_attack(1, 4);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    BEGIN PERFORM sp_cast_spell(2, 4, 2);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    BEGIN PERFORM sp_cast_spell(4, 1, 4);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- Reset round
    PERFORM sp_reset_round(1);

    -- Perform actions
    BEGIN PERFORM sp_physical_attack(1, 2);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    BEGIN PERFORM sp_cast_spell(2, 4, 3);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    BEGIN PERFORM sp_physical_attack(4, 2);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- Reset round
    PERFORM sp_reset_round(1);

    -- Perform actions
    BEGIN PERFORM sp_physical_attack(1, 2);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    BEGIN PERFORM sp_physical_attack(2, 1);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    BEGIN PERFORM sp_physical_attack(4, 2);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;


    -- Reset round
    PERFORM sp_reset_round(1);

    -- Perform actions
    BEGIN PERFORM sp_physical_attack(1, 4);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    BEGIN PERFORM sp_physical_attack(2, 4);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    BEGIN PERFORM sp_physical_attack(4, 1);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- Reset round
    PERFORM sp_reset_round(1);

    -- Perform actions
    BEGIN PERFORM sp_physical_attack(1, 4);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    BEGIN PERFORM sp_physical_attack(2, 4);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    BEGIN PERFORM sp_physical_attack(4, 1);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- Reset round
    PERFORM sp_reset_round(1);

    -- Perform actions
    BEGIN PERFORM sp_physical_attack(1, 4);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    BEGIN PERFORM sp_physical_attack(2, 4);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    BEGIN PERFORM sp_physical_attack(4, 1);
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- Reset round
    PERFORM sp_reset_round(1);

    -- Try to get items to their(characters) inventories
    BEGIN
        IF (SELECT health FROM characters WHERE id = 1) > 0 THEN
            PERFORM sp_loot_item(1, 1, 1);
        end if;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    BEGIN
        IF (SELECT health FROM characters WHERE id = 2) > 0 THEN
            PERFORM sp_loot_item(1, 2, 1);
        end if;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    BEGIN
        IF (SELECT health FROM characters WHERE id = 4) > 0 THEN
            PERFORM sp_loot_item(1, 4, 1);
        end if;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    -- Reset round
    PERFORM sp_reset_round(1);

    -- Try to drop items from their inventories
    BEGIN
        IF (SELECT health FROM characters WHERE id = 1) > 0 THEN
            PERFORM sp_drop_item(1, 1, 1);
        END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    BEGIN
        IF (SELECT health FROM characters WHERE id = 2) > 0 THEN
            PERFORM sp_drop_item(1, 2, 1);
        END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    BEGIN
        IF (SELECT health FROM characters WHERE id = 4) > 0 THEN
            PERFORM sp_drop_item(1, 4, 1);
        END IF;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;

    FOR _ IN 1..20 LOOP
        -- Check if game is over(2 characters are dead)
        IF (SELECT health FROM characters WHERE id = 1) + (SELECT health FROM characters WHERE id = 2) + (SELECT health FROM characters WHERE id = 4)
               IN
           ((SELECT health FROM characters WHERE id = 1),(SELECT health FROM characters WHERE id = 2), (SELECT health FROM characters WHERE id = 4))
            THEN EXIT;
        END IF;

        -- Reset round
        PERFORM sp_reset_round(1);

        -- Perform actions
    BEGIN PERFORM sp_physical_attack(1, (CASE WHEN RANDOM() < 0.5 THEN 2 ELSE 4 END));
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        BEGIN PERFORM sp_physical_attack(2, (CASE WHEN RANDOM() < 0.5 THEN 1 ELSE 4 END));
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
        BEGIN PERFORM sp_physical_attack(4, (CASE WHEN RANDOM() < 0.5 THEN 1 ELSE 2 END));
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
    END LOOP;

    -- We have a winner, set winner_id in combat
    UPDATE combats
    SET winner_id = (SELECT id FROM characters WHERE health > 0 AND id IN (1, 2, 4) LIMIT 1)
    WHERE id = 1;

    -- Now you can check log, items, game_items, characters tables

    -- check views to see views of current state of game
    -- check v_combat_damage, v_spell_statistics, v_player_statistics and other views
END;
$$;


-- See combat_logs and characters tables!!!
SELECT * FROM combat_logs;
SELECT * FROM game_items;
SELECT * FROM characters;

SELECT sp_physical_attack(1, 2);
SELECT sp_cast_spell(2, 1, 2);
SELECT sp_reset_test_data();



