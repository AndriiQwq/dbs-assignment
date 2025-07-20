-- Clean up the database
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'assignment_3';

DROP DATABASE assignment_3;
CREATE DATABASE assignment_3;

DROP TABLE IF EXISTS
    users,
    classes,
    item_types,
    equipment_categories,
    spell_categories,
    spells,
    items,
    equipments,
    equipment_modifiers,
    character_game_stats,
    characters,
    combats,
    game_items,
    item_storages,
    sleep_characters,
    inventories,
    character_equipments,
    character_spells,
    combat_players,
    combat_logs,
    spell_configurations,
    class_modifiers,
    users_characters
CASCADE;

TRUNCATE TABLE
    users,
    classes,
    item_types,
    equipment_categories,
    spell_categories,
    spells,
    items,
    equipments,
    equipment_modifiers,
    character_game_stats,
    characters,
    combats,
    game_items,
    item_storages,
    sleep_characters,
    inventories,
    character_equipments,
    character_spells,
    combat_players,
    combat_logs,
    spell_configurations,
    class_modifiers,
    users_characters
CASCADE;
