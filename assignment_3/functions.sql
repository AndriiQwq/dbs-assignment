-- NAMING PREFIXES:
-- sp_ indicate Stored Procedures
-- f_ indicate Functions, that return a value

-- NAMING PREFIXES FOR VARIABLES:
-- p_ → function parameters
-- v_ → local variables
-- r_ → return values
-- t_ → table variables

-- OVERALL DESCRIPTION:
-- INITIAL FUNCTIONS & PROCEDURES:
-- 1. sp_cast_spell
-- 2. sp_rest_character
-- 3. sp_enter_combat
-- 4. sp_loot_item
-- 5. f_effective_spell_cost
-- 6. sp_reset_round
-- ADDITIONAL FUNCTIONS & PROCEDURES:
-- 7. sp_initialize_combat_items
-- 8. sp_init_test_data
-- 9. sp_reset_test_data
-- 10. sp_physical_attack
-- 11. sp_drop_item
-- 12. sp_wake_up_character


CREATE OR REPLACE FUNCTION sp_cast_spell(
    p_caster_id INTEGER,
    p_target_id INTEGER,
    p_spell_id INTEGER
) RETURNS VOID AS $$
BEGIN
    IF p_caster_id = p_target_id
    THEN
        RAISE EXCEPTION 'Not possible to attack yourself.';
    END IF;

    -- Validate that the caster has sufficient AP.
    IF NOT EXISTS (
        SELECT 1
        FROM characters
        WHERE id = p_caster_id AND
              action_points >= (SELECT cost FROM spells WHERE id = p_spell_id) AND
              health > 0
    ) THEN
        RAISE EXCEPTION 'Caster does not have enough AP for casting this spell or hi die.';
    END IF;

    -- Validate that the character has this spell.
    IF NOT EXISTS (
        SELECT 1
        FROM character_spells
        WHERE character_id = p_caster_id AND
              spell_id = p_spell_id
    ) THEN
        RAISE EXCEPTION 'Caster does not have this spell.';
    END IF;

    -- Validate that target has as minimum 1 HP.
    IF NOT EXISTS (
        SELECT 1
        FROM characters
        WHERE id = p_target_id AND
              health > 0
    ) THEN
        RAISE EXCEPTION 'Target is already dead.';
    END IF;

    -- Calculate the effective spell cost based on character attributes.
    -- Deduct the appropriate AP from the caster.
    -- => Update the caster's action points.
    UPDATE characters
    SET action_points = action_points - f_effective_spell_cost(p_spell_id, p_caster_id)
    WHERE id = p_caster_id;

    -- Perform a d20 roll and add the relevant attribute bonus.
    WITH d20_roll AS (
        SELECT (RANDOM() * 20 + 1)::INTEGER AS roll
    ),
    attack AS (
        SELECT
            d20.roll + ( -- character strength
            SELECT intelligence FROM characters WHERE id = p_caster_id
        ) + ( -- item bonus, example: 5(weapon, amulet, ...)
                SELECT COALESCE(SUM(modifier_value), 0)
                FROM character_equipments
                JOIN items ON character_equipments.item_id = items.id
                JOIN equipment_modifiers ON items.id = equipment_modifiers.equipment_id
                WHERE character_equipments.character_id = p_caster_id AND
                      modifier_type = 'intelligence'
                ) AS attack_strength
        FROM d20_roll d20
    ),
    target_ac AS (
        -- A𝑟𝑚𝑜𝑟𝐶𝑙𝑎𝑠𝑠 = (10+(𝐷𝑒𝑥𝑡𝑒𝑟𝑖𝑡𝑦/2)+𝐶haracter_item_bonus) * class_modifier
        SELECT
            (10 + (dexterity / 2) +(-- character_equipments bonus, example: 5(armor)
                SELECT COALESCE((SUM(modifier_value)), 0)
                FROM character_equipments
                JOIN items ON character_equipments.item_id = items.id
                JOIN equipment_modifiers ON items.id = equipment_modifiers.equipment_id
                WHERE character_equipments.character_id = p_target_id AND
                      modifier_type = 'armor'
            )) * ( -- class modifier, example: 1.2(armor scale)
                    SELECT COALESCE(SUM(modifier_value), 1)
                    FROM class_modifiers
                    WHERE class_id = (SELECT class_id FROM characters WHERE id = p_target_id) AND
                          modifier_type = 'armor'
            ) AS armor_points
        FROM characters
        WHERE id = p_target_id
    ),
        -- Compare roll result with the target’s Armor Class.
    hit AS (
        SELECT
            CASE
                WHEN attack.attack_strength > target_ac.armor_points
                    THEN TRUE
                ELSE FALSE
            END AS is_hit
        FROM attack, target_ac
    ),
    damage AS (
        -- ��𝑎𝑚𝑎𝑔𝑒 = 𝐵𝑎𝑠𝑒𝐷𝑎𝑚𝑎𝑔𝑒(1+𝐶𝑜𝑛𝑓𝑖𝑔𝑢𝑟𝑒𝑑𝐴𝑡𝑡𝑟𝑖𝑏𝑢𝑡𝑒/20),
        -- configured attribute - attribute of target character
        SELECT
            CASE
                WHEN hit.is_hit = TRUE
                    THEN ( -- Sum of all damage effects, base damage and damages
                        SELECT
                            (
                                SUM(
                                    CASE
                                        WHEN spell_configurations.effect_type = 'base_damage' THEN effect_bonus_value
                                        WHEN spell_configurations.effect_type = 'damage' THEN effect_bonus_value * (
                                            1 + (
                                                SELECT
                                                    CASE target_attribute
                                                        WHEN 'strength' THEN strength
                                                        WHEN 'dexterity' THEN dexterity
                                                        WHEN 'constitution' THEN constitution
                                                        WHEN 'intelligence' THEN intelligence
                                                        WHEN 'health' THEN health
                                                    END / 20::NUMERIC
                                                FROM characters
                                                WHERE id = p_target_id
                                            )
                                        )
                                        ELSE 0
                                    END
                                )
                            )::NUMERIC AS total_damage
                        FROM spell_configurations
                        WHERE spell_configurations.spell_id = p_spell_id AND
                              spell_configurations.effect_type IN ('base_damage', 'damage')
                    )
                ELSE 0
            END AS total_damage
        FROM hit
    ),
    health_update AS (
        -- Update the target’s Health(MIN 0 HP after damage)
        UPDATE characters
        SET health = GREATEST(health - (SELECT total_damage FROM damage), 0)
        WHERE id = p_target_id
        RETURNING health
    )
    -- Log the spell casting event in the combat log.
    INSERT INTO combat_logs (
        combat_id,
        character_id,
        character2_id,
        date,
        action,
        event_msg_type,
        round_number,
        damage,
        damage_type,
        item_id,
        spell_id
    )
    VALUES (
        (SELECT combat_id FROM combat_players WHERE character_id = p_caster_id),
        p_caster_id,
        p_target_id,
        CURRENT_TIMESTAMP,
        'cast_spell',
        CASE
            WHEN (SELECT health FROM health_update) = 0 THEN 'kill'
            WHEN (SELECT is_hit FROM hit) = TRUE THEN 'success'
            ELSE 'failure'
        END,
        (
            SELECT rounds_count
            FROM combats
            WHERE id = (SELECT combat_id FROM combat_players WHERE character_id = p_caster_id)
        ),
        (SELECT total_damage FROM damage),
        'magical',
        NULL,
        p_spell_id
    );
    -- Perform a d20 roll and add the relevant attribute bonus.
    -- Compare roll result with the target’s Armor Class.
    -- If hit: calculate damage and update the target’s Health.
    -- Log the spell casting event in the combat log.
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION sp_rest_character(
    p_character_id INTEGER
) RETURNS VOID AS $$
BEGIN
    -- Reset the character’s Health to their maximum.
    UPDATE characters
        SET health = sleep_c.max_health
    FROM sleep_characters sleep_c
    WHERE characters.id = p_character_id AND
          sleep_c.character_id = characters.id;

    -- Restore Action Points to full capacity.

    -- Using formula:
    -- M𝑎𝑥𝐴𝑐𝑡𝑖𝑜𝑛𝑃𝑜𝑖𝑛𝑡𝑠 = (𝐷𝑒𝑥𝑡𝑒𝑟𝑖𝑡𝑦 +𝐼𝑛𝑡𝑒𝑙𝑙𝑖𝑔𝑒𝑛𝑐𝑒)𝐶𝑙𝑎𝑠𝑠𝑀𝑜𝑑𝑖𝑓𝑖𝑒𝑟 (1)
    UPDATE characters
        SET action_points = (dexterity + intelligence) * class_modifiers.modifier_value
    FROM class_modifiers
    WHERE characters.id = p_character_id AND
          characters.class_id = class_modifiers.class_id AND
          class_modifiers.modifier_type = 'action_points';

    -- Optionally, log the resting action in the combat log.
    -- Initially, I didn't think to implement it.
END;
$$ LANGUAGE plpgsql;


--  Popis: Zaregistruje postavu do prebiehaj´ ucej bojovej rel´ acie a inicializuje
--  parametre ˇ specifick´e pre boj, ako je aktu´ alny AP a ˇ c´ ıslo kola.
CREATE OR REPLACE FUNCTION sp_enter_combat(
    p_combat_id INTEGER,
    p_character_id INTEGER
) RETURNS VOID AS $$
BEGIN
    -- rounds count will be stored in the combat table in the rounds_count column
    -- using and updating with each next round(rc++)

    -- Insert a new record associating the character with the combat session.
    INSERT INTO combat_players (combat_id, character_id, entry_health)
    VALUES (p_combat_id, p_character_id, (SELECT health FROM characters WHERE id = p_character_id));

    -- Initialize the character’s AP and starting round.
    UPDATE characters
        SET action_points = (dexterity + intelligence) *
        CASE
            WHEN class_modifiers.modifier_type = 'action_points' THEN class_modifiers.modifier_value
            ELSE 1
        END
    FROM class_modifiers
    WHERE characters.id = p_character_id AND
          characters.class_id = class_modifiers.class_id;

    -- Log the character’s entry into combat.
    INSERT INTO combat_logs (
        combat_id,
        character_id,
        date,
        action,
        event_msg_type,
        round_number
    )
    VALUES (
        p_combat_id,
        p_character_id,
        CURRENT_TIMESTAMP,
        'enter_combat',
        'success',
        (
            SELECT rounds_count
            FROM combats
            WHERE id = p_combat_id
         )
    );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION sp_loot_item(
    p_combat_id INTEGER,
    p_character_id INTEGER,
    p_item_id INTEGER
) RETURNS VOID AS $$
BEGIN
    -- Check that the item is available in the combat area.
    IF NOT EXISTS (
        SELECT 1
        FROM game_items
        WHERE item_id = p_item_id AND character_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Item is not available in the combat area.';
    END IF;

    -- Verify the character’s current inventory weight and maximum capacity.
    -- M𝑎𝑥𝐼𝑛𝑣𝑒𝑛𝑡𝑜𝑟𝑦𝑊𝑒𝑖𝑔ℎ𝑡 = (𝑆𝑡𝑟𝑒𝑛𝑔𝑡ℎ +𝐶𝑜𝑛𝑠𝑡𝑖𝑡𝑢𝑡𝑖𝑜𝑛)𝐶𝑙𝑎𝑠𝑠𝐼𝑛𝑣𝑒𝑛𝑡𝑜𝑟𝑦𝑀𝑜𝑑𝑖𝑓𝑖𝑒𝑟 + equipment_modifiers
    -- class_modifiers must contain the modifier type 'inventory'
    IF (
        WITH max_inventory_weight AS (
            SELECT
                (strength + constitution) * COALESCE(c_modifiers.modifier_value, 1) +
                COALESCE(SUM(e_modifiers.modifier_value), 0) AS max_weight
            FROM characters
            LEFT JOIN class_modifiers c_modifiers ON c_modifiers.class_id = characters.class_id
                AND c_modifiers.modifier_type = 'inventory'
            LEFT JOIN character_equipments ON character_equipments.character_id = p_character_id
            LEFT JOIN items ON character_equipments.item_id = items.id
            LEFT JOIN equipment_modifiers e_modifiers ON items.id = e_modifiers.equipment_id
                AND e_modifiers.modifier_type = 'inventory'
            WHERE characters.id = p_character_id
            GROUP BY characters.strength, characters.constitution, c_modifiers.modifier_value
        ),
        current_inventory_weight AS (
            SELECT COALESCE(SUM(items.weight), 0) AS weight
            FROM inventories
            JOIN items ON inventories.item_id = items.id
            JOIN character_equipments c_equipments ON items.id = c_equipments.item_id
            WHERE inventories.character_id = p_character_id AND
                  c_equipments.character_id = p_character_id
        ),
        taken_item_weight AS (
            SELECT items.weight AS weight
            FROM game_items
            JOIN items ON game_items.item_id = items.id
            WHERE game_items.item_id = p_item_id AND
                  game_items.character_id IS NULL
            LIMIT 1
        ),
        is_free_space AS (
            SELECT
                CASE
                    WHEN
                        (SELECT weight FROM current_inventory_weight) +
                        (SELECT weight FROM taken_item_weight) <=
                        (SELECT max_weight FROM max_inventory_weight)
                        THEN TRUE
                    ELSE FALSE
                END AS is_space
        )
        SELECT is_space
        FROM is_free_space
        WHERE is_space = TRUE
    ) THEN
        -- Add the item into the character’s inventory.
        INSERT INTO inventories (character_id, item_id)
        VALUES (p_character_id, p_item_id);

        -- Remove the item on the battlefield.
        UPDATE game_items
        SET character_id = p_character_id,
            event_type = CASE
                WHEN event_type = 'spawn' THEN 'spawn & pickup'
                WHEN event_type = 'drop' THEN 'drop & pickup'
                ELSE 'pickup'
            END
        WHERE id = ( -- update only one item without character_id
            SELECT id
            FROM game_items
            WHERE item_id = p_item_id AND character_id IS NULL
            LIMIT 1
        );

        -- Log adding the item into the character’s inventory.
        INSERT INTO combat_logs (
            combat_id,
            character_id,
            date,
            action,
            event_msg_type,
            round_number,
            item_id
        )
        VALUES (
            p_combat_id,
            p_character_id,
            CURRENT_TIMESTAMP,
            'loot_item',
            'success',
            (
                SELECT rounds_count
                FROM combats
                WHERE id = p_combat_id
            ),
            p_item_id
        );
    ELSE
        RAISE EXCEPTION 'Inventory is full or item is too heavy.';
    END IF;

    -- Check that the item is available in the combat area.
    -- Verify the character’s current inventory weight and maximum capacity.
    -- If within limits, add the item to the character’s inventory and remove it from the combat area.
    -- Log the looting event.
END;
$$ LANGUAGE plpgsql;


-- Part of first function
CREATE OR REPLACE FUNCTION f_effective_spell_cost(
    p_spell_id INTEGER,
    p_caster_id INTEGER
) RETURNS NUMERIC AS $$
DECLARE
    v_effective_cost NUMERIC;
BEGIN
    -- Compute effective cost using a formula such as:
    -- v_effective_cost := BaseCost * (1- (SelectedAttribute / 100));

-- E𝑓𝑓𝑒𝑐𝑡𝑖𝑣𝑒𝐶𝑜𝑠𝑡 = 𝐵𝑎𝑠𝑒𝐶𝑜𝑠𝑡 * 𝐶𝑎𝑡𝑒𝑔𝑜𝑟𝑦.𝑀𝑜𝑑𝑖𝑓𝑖𝑒𝑟(1 − 𝑆𝑒𝑙𝑒𝑐𝑡𝑒𝑑𝐴𝑡𝑡𝑟𝑖𝑏𝑢𝑡𝑒/100)(1 − 𝐼𝑡𝑒𝑚𝑀𝑜𝑑𝑖𝑓𝑖𝑒𝑟𝑠) (2)
    -- Where:
    -- BaseCostCategory.Modifier is the base cost of the spell.
    -- SelectedAttribute is the attribute of the character that affects the spell.
    -- ItemModifiers are the modifiers from the character's equipped items.
    WITH character_item_modifiers_bonus AS (
        SELECT COALESCE(SUM(modifier_value), 0) AS total_modifier
        FROM character_equipments
        JOIN items ON character_equipments.item_id = items.id
        JOIN equipment_modifiers ON items.id = equipment_modifiers.equipment_id
        WHERE character_equipments.character_id = p_caster_id AND
              modifier_type = 'action_points'
    ),
    spell_cost AS (
        SELECT cost
        FROM spells
        WHERE id = p_spell_id
    ),
    selected_attribute AS (
        SELECT intelligence
        FROM characters
        WHERE id = p_caster_id
    ),
    character_class_bonus AS (
        SELECT COALESCE(SUM(modifier_value), 1) AS m_value
        FROM class_modifiers
        JOIN characters ON class_modifiers.class_id = characters.class_id
        WHERE characters.id = p_caster_id AND
              class_modifiers.modifier_type = 'action_points'
    )
    SELECT
        (
            s_cost.cost::NUMERIC * ccb.m_value::NUMERIC * (1 - (s_atribut.intelligence::NUMERIC / 100)) * (1 - cim_bonus.total_modifier::NUMERIC / 100)
        )AS effective_cost
    INTO v_effective_cost
    FROM spell_cost s_cost, selected_attribute s_atribut, character_item_modifiers_bonus cim_bonus, character_class_bonus ccb;

    IF v_effective_cost IS NULL
    THEN
        RAISE EXCEPTION 'Effective cost calculation failed.';
    ELSE
        RETURN v_effective_cost;
    END IF;
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION sp_reset_round(
    p_combat_id INTEGER
) RETURNS VOID AS $$
BEGIN
    -- Loop through all characters in the combat session.
    -- Reset the combat session’s round counter.
    UPDATE characters
        SET action_points = (dexterity + intelligence) * class_modifiers.modifier_value
    FROM class_modifiers
    JOIN combat_players c_player ON c_player.character_id = character_id
    WHERE characters.id = c_player.character_id AND
          characters.class_id = class_modifiers.class_id AND
          class_modifiers.modifier_type = 'action_points';

    -- Increment the combat’s round counter.
    UPDATE combats
        SET rounds_count = rounds_count + 1
    WHERE id = p_combat_id;

    -- Log the round reset event.
    INSERT INTO combat_logs (
        combat_id,
        character_id,
        date,
        action,
        event_msg_type,
        round_number
    )
    VALUES (
        p_combat_id,
        NULL,
        CURRENT_TIMESTAMP,
        'reset_round',
        'success',
        (
            SELECT rounds_count
            FROM combats
            WHERE id = p_combat_id
        )
    );
    -- Loop through all characters in the combat session.
    -- Reset each character’s Action Points to their maximum.
    -- Increment the combat’s round counter.
    -- Log the round reset event.
END;
$$ LANGUAGE plpgsql;

select * FROM combat_logs;


CREATE OR REPLACE FUNCTION sp_initialize_combat_items(
    p_combat_id INTEGER
) RETURNS VOID AS $$
DECLARE
    v_player_count INTEGER;
BEGIN
    -- Need value of count of players in this combat
    SELECT COUNT(*) INTO v_player_count
    FROM combat_players
    WHERE combat_id = p_combat_id;

    -- Calculate counts of items rarity to add to the combat area
    -- Item types: common, uncommon, rare, epic, legendary

    -- Calculate the number of items based on the rarity, number of players and random factor.

    INSERT INTO game_items (item_id, combat_id, event_type)
    SELECT
        (SELECT id FROM items WHERE rarity = 'common' ORDER BY RANDOM() LIMIT 1),
        p_combat_id,
        'spawn'
    FROM GENERATE_SERIES(1, CAST(ROUND(v_player_count * (RANDOM() * 1.0 + 0.5)) AS INTEGER));

    INSERT INTO game_items (item_id, combat_id, event_type)
    SELECT
        (SELECT id FROM items WHERE rarity = 'uncommon' ORDER BY RANDOM() LIMIT 1),
        p_combat_id,
        'spawn'
    FROM GENERATE_SERIES(1, CAST(ROUND(v_player_count / 2) AS INTEGER))
    WHERE RANDOM() < 0.5;

    INSERT INTO game_items (item_id, combat_id, event_type)
    SELECT
        (SELECT id FROM items WHERE rarity = 'rare' ORDER BY RANDOM() LIMIT 1),
        p_combat_id,
        'spawn'
    FROM GENERATE_SERIES(1, LEAST(ROUND(v_player_count * 0.3), 2))
    WHERE RANDOM() < 0.3;

    INSERT INTO game_items (item_id, combat_id, event_type)
    SELECT
        (SELECT id FROM items WHERE rarity = 'epic' ORDER BY RANDOM() LIMIT 1),
        p_combat_id,
        'spawn'
    FROM GENERATE_SERIES(1, v_player_count)
    WHERE RANDOM() < 0.03;

    INSERT INTO game_items (item_id, combat_id, event_type)
    SELECT
        (SELECT id FROM items WHERE rarity = 'legendary' ORDER BY RANDOM() LIMIT 1),
        p_combat_id,
        'spawn'
    FROM GENERATE_SERIES(1, v_player_count)
    WHERE RANDOM() < 0.005;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION sp_physical_attack
(
    p_attacker_id INTEGER,
    p_target_id INTEGER
) RETURNS VOID AS $$
BEGIN
    -- attack
    -- write combat log

    IF NOT EXISTS (
        SELECT 1
        FROM characters
        WHERE id = p_attacker_id AND
              health > 0
    ) THEN
        RAISE EXCEPTION 'Attacker is already dead.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM characters
        WHERE id = p_target_id AND
              health > 0
    ) THEN
        RAISE EXCEPTION 'Target is already dead.';
    END IF;

    IF p_attacker_id = p_target_id
    THEN
        RAISE EXCEPTION 'Not possible to attack yourself.';
    END IF;

    WITH damage AS (
        SELECT
            (strength + COALESCE(
                    (
                        SELECT equipment_modifiers.modifier_value
                        FROM character_equipments
                        JOIN equipment_modifiers on item_id = equipment_id
                        WHERE character_id = p_attacker_id AND
                              equipment_modifiers.modifier_type = 'strength'
                    )
                , 0)
            ) AS total_damage
        FROM characters
        WHERE id = p_attacker_id
    ),
    target_ac AS (
        -- A𝑟𝑚𝑜𝑟𝐶𝑙𝑎𝑠𝑠 = (10+(𝐷𝑒𝑥𝑡𝑒𝑟𝑖𝑡𝑦/2)+𝐶haracter_item_bonus) * class_modifier
        SELECT
            (10 + (dexterity / 2) +(-- character_equipments bonus, example: 5(armor)
                SELECT COALESCE((SUM(modifier_value)), 0)
                FROM character_equipments
                JOIN items ON character_equipments.item_id = items.id
                JOIN equipment_modifiers ON items.id = equipment_modifiers.equipment_id
                WHERE character_equipments.character_id = p_target_id AND
                      modifier_type = 'armor'
            )) * ( -- class modifier, example: 1.2(armor scale)
                    SELECT COALESCE(SUM(modifier_value), 1)
                    FROM class_modifiers
                    WHERE class_id = (SELECT class_id FROM characters WHERE id = p_target_id) AND
                          modifier_type = 'armor'
            ) AS armor_points
        FROM characters
        WHERE id = p_target_id
    ), -- 20% of armor points - damage
    total_damage AS (
        SELECT GREATEST((SELECT total_damage FROM damage) - ((SELECT armor_points FROM target_ac) * 0.2), 0) AS d
    ),
    health_update AS (
        -- Update the target’s Health(MIN 0 HP after damage)
        UPDATE characters
        SET health = GREATEST(health - (SELECT d FROM total_damage), 0)
        WHERE id = p_target_id
        RETURNING health
    )
    -- Log the attack event in the combat log.
    INSERT INTO combat_logs (
        combat_id,
        character_id,
        character2_id,
        date,
        action,
        event_msg_type,
        round_number,
        damage,
        damage_type
    )
    VALUES (
        (SELECT combat_id FROM combat_players WHERE character_id = p_attacker_id),
        p_attacker_id,
        p_target_id,
        CURRENT_TIMESTAMP,
        'attack',
        CASE
            WHEN (SELECT health FROM health_update) = 0 THEN 'kill'
            WHEN (SELECT d FROM total_damage) = 0 THEN 'miss'
            WHEN (SELECT d FROM total_damage) > 0 THEN 'success'
            ELSE 'failure'
        END,
        (
            SELECT rounds_count
            FROM combats
            WHERE id = (SELECT combat_id FROM combat_players WHERE character_id = p_attacker_id)
        ),
        (SELECT d FROM total_damage),
        'physical'
    );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION sp_drop_item
(
    p_combat_id INTEGER,
    p_character_id INTEGER,
    p_item_id INTEGER
) RETURNS VOID AS $$
DECLARE
    is_was_looted bool;
BEGIN
    -- Check that the character has the item in their inventory.
    IF NOT EXISTS (
        SELECT 1
        FROM inventories
        WHERE character_id = p_character_id AND inventories.item_id = p_item_id
    ) THEN
        RAISE EXCEPTION 'Character does not have this item.';
    END IF;

    DELETE FROM inventories
    WHERE character_id = p_character_id AND
          item_id = p_item_id;

    SELECT
        CASE
            WHEN COUNT(*) > 0 THEN TRUE
            ELSE FALSE
        END
    INTO is_was_looted
    FROM game_items
    WHERE combat_id = p_combat_id AND
        item_id = p_item_id AND
        character_id = p_character_id;

    IF is_was_looted = TRUE
    THEN
        -- Update item status for item on the combat area.
        UPDATE game_items
        SET character_id = NULL,
            event_type = CASE
                WHEN event_type = 'spawn & pickup' THEN 'spawn'
                WHEN event_type = 'drop & pickup' THEN 'drop'
                ELSE 'drop'
            END
        WHERE combat_id = p_combat_id AND
              item_id = p_item_id AND
              character_id = p_character_id;
    ELSE
        -- Add the item to the combat area.
        INSERT INTO game_items (item_id, combat_id, event_type)
        VALUES (p_item_id, p_combat_id, 'drop');
    end if;

    -- Log the item drop event.
    INSERT INTO combat_logs (
        combat_id,
        character_id,
        date,
        action,
        event_msg_type,
        round_number,
        item_id
    )
    VALUES (
        p_combat_id,
        p_character_id,
        CURRENT_TIMESTAMP,
        'drop_item',
        'success',
        (
            SELECT rounds_count
            FROM combats
            WHERE id = p_combat_id
        ),
        p_item_id
    );
END;
$$ LANGUAGE plpgsql;

-- SELECT * from inventories;
-- select * from sp_drop_item(1, 2, 3);
-- SELECT * from game_items;
-- SELECT * from combat_logs;

CREATE OR REPLACE FUNCTION sp_wake_up_character(
    p_character_id INTEGER
) RETURNS VOID AS $$
BEGIN

    -- Update health and manage sleep characters
    WITH health_update AS (
        SELECT
            c.id AS character_id,
            LEAST(
                sc.max_health,
                c.health + (5 * 60) * EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - sc.last_sleep_time)) / 60
            ) AS new_health
        FROM characters c
        JOIN sleep_characters sc ON sc.character_id = c.id
        WHERE c.id = p_character_id
    )
    UPDATE characters -- Update character's health
    SET health = hu.new_health
    FROM health_update hu
    WHERE characters.id = hu.character_id
      AND characters.id = p_character_id;

    DELETE FROM sleep_characters
    WHERE character_id = p_character_id AND
        character_id IN (
          SELECT character_id
          FROM combat_players
          WHERE character_id = p_character_id
        );

    -- Restore Action Points to full capacity.
    UPDATE characters
        SET action_points = (dexterity + intelligence) * class_modifiers.modifier_value
    FROM class_modifiers
    WHERE characters.id = p_character_id AND
          characters.class_id = class_modifiers.class_id AND
          class_modifiers.modifier_type = 'action_points';

END;
$$ LANGUAGE plpgsql;





