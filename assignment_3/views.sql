-- OVERALL DESCRIPTION:
-- INITIAL VIEWS:
-- 1. v_combat_state
-- 2. v_most_damage
-- 3. v_strongest_characters
-- 4. v_combat_damage
-- 5. v_spell_statistics
-- 6. v_player_statistics
-- 7. v_most_spells_unlocked
-- 8. v_most_items_spawned_in_combat
-- 9. v_combat_log_statistics

-- Zobrazuje aktu´ alne kolo, zoznam akt´ ıvnych post´ av
--  a ich zost´avaj´ ucu AP.
CREATE OR REPLACE VIEW v_combat_state AS
WITH alive_characters AS (
    SELECT DISTINCT characters.id AS alive_character_id
    FROM characters
    JOIN combat_players ON characters.id = combat_players.character_id
    JOIN combat_logs c_log ON combat_players.combat_id = c_log.combat_id
    WHERE c_log.combat_id = 1 AND -- SET COMBAT ID !!!
          c_log.round_number = (SELECT MAX(round_number) FROM combat_logs WHERE combat_id = c_log.combat_id) AND
          characters.health > 0
)
SELECT character_game_stats_id, action_points
FROM alive_characters
JOIN characters on characters.id = alive_characters.alive_character_id;

SELECT * FROM v_combat_state;

-- Display characters by damage sorted descending
CREATE OR REPLACE VIEW v_most_damage AS
WITH damage AS (
    SELECT c_log.character_id, SUM(c_log.damage) AS total_damage
    FROM combat_logs c_log
    WHERE c_log.action = 'attack' OR c_log.action = 'cast_spell'
    GROUP BY c_log.character_id
    ORDER BY total_damage DESC
)
SELECT *
FROM damage;

SELECT * FROM v_most_damage;



CREATE OR REPLACE VIEW v_strongest_characters AS
WITH damage AS (
    SELECT c_log.character_id, SUM(c_log.damage) AS total_damage
    FROM combat_logs c_log
    WHERE c_log.action = 'attack' OR c_log.action = 'cast_spell'
    GROUP BY c_log.character_id
    ORDER BY total_damage DESC
),
rimaining_health AS (
    SELECT c_log.character2_id, SUM(c_log.damage) AS total_damage
    FROM combat_logs c_log
    WHERE c_log.action = 'attack' OR c_log.action = 'cast_spell'
    GROUP BY c_log.character2_id
    ORDER BY total_damage DESC
)
SELECT damage.character_id, damage.total_damage AS damage,
       GREATEST((SELECT MAX(entry_health) FROM combat_players WHERE combat_players.character_id = r_health.character2_id) - r_health.total_damage, 0) AS remaining_health
FROM damage
JOIN rimaining_health r_health ON damage.character_id = r_health.character2_id
ORDER BY damage.total_damage DESC, remaining_health DESC;

SELECT * FROM v_strongest_characters;



CREATE OR REPLACE VIEW v_combat_damage AS
WITH damage AS (
    SELECT c_log.combat_id, SUM(c_log.damage) AS total_damage
    FROM combat_logs c_log
    GROUP BY c_log.combat_id
    ORDER BY total_damage DESC
)
SELECT *
FROM damage;

SELECT * FROM v_combat_damage;



CREATE OR REPLACE VIEW v_spell_statistics AS
SELECT
    c_log.spell_id,
    SUM(damage) AS total_damage,
    COUNT(*) AS total_casts,
    AVG(damage) AS average_damage
FROM combat_logs c_log
JOIN spells ON c_log.spell_id = spells.id
WHERE action = 'cast_spell' AND
      event_msg_type = 'success' AND damage > 0
GROUP BY c_log.spell_id
ORDER BY total_damage DESC, total_casts DESC, average_damage DESC;

SELECT * FROM v_spell_statistics;



CREATE OR REPLACE VIEW v_player_statistics AS
SELECT
    combat_players.character_id,
    COUNT(*) AS total_combats,
    SUM(CASE WHEN combats.winner_id IS NOT NULL AND combats.winner_id = combat_players.character_id THEN 1 ELSE 0 END) AS combats_won
FROM combat_players
JOIN combats ON combats.id = combat_players.combat_id
GROUP BY combat_players.character_id;

SELECT * FROM v_player_statistics;

-- ALTER VIEW v_player_statistics RENAME COLUMN totalcombats TO total_combats;
-- ALTER VIEW v_player_statistics RENAME COLUMN combatswon TO combats_won;

-- Most used spells by characters(characters who unlocked them)
CREATE OR REPLACE VIEW v_most_spells_unlocked AS
SELECT
    spell_id,
    name,
    rarity,
    COUNT(*) AS total_unlocked
FrOM spells
JOIN public.character_spells cs on spells.id = cs.spell_id
GROUP BY spell_id, name, rarity
ORDER BY total_unlocked DESC;

SELECT * FROM v_most_spells_unlocked;

CREATE OR REPLACE VIEW v_most_items_spawned_in_combat AS
SELECT
    item_id,
    name,
    rarity,
    COUNT(*) AS total_generated
FROM items
JOIN game_items ON game_items.item_id = items.id
WHERE game_items.item_id IS NOT NULL AND
      game_items.event_type LIKE 'spawn%'
GROUP BY item_id, name, rarity
ORDER BY total_generated DESC;

SELECT * FROM v_most_items_spawned_in_combat;


CREATE OR REPLACE VIEW v_combat_log_statistics AS
SELECT
    c_log.character_id,
    COUNT(*) AS total_actions,
    SUM(CASE WHEN c_log.action = 'attack' THEN 1 ELSE 0 END) AS total_attacks,
    SUM(CASE WHEN c_log.action = 'cast_spell' THEN 1 ELSE 0 END) AS total_casts,
    SUM(CASE WHEN c_log.event_msg_type = 'kill' THEN 1 ELSE 0 END) AS total_kills,
    SUM(CASE WHEN c_log.action = 'loot_item' THEN 1 ELSE 0 END) AS total_loots,
    SUM(CASE WHEN c_log.action = 'drop_item' THEN 1 ELSE 0 END) AS total_drops
FROM combat_logs c_log
JOIN characters ON c_log.character_id = characters.id
WHERE c_log.combat_id = 1 -- SET COMBAT ID !!!
GROUP BY c_log.character_id
ORDER BY total_actions DESC, total_attacks DESC, total_casts DESC, total_loots DESC, total_drops DESC;

SELECT * FROM v_combat_log_statistics;

-- most_popular_class
-- monthly_active_users
-- most_popular_item
-- monthly_games_statistics
