

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(32) UNIQUE NOT NULL,
    password VARCHAR(50) NOT NULL,
    register_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN DEFAULT TRUE NOT NULL,
    last_login TIMESTAMP,
    CONSTRAINT username_length CHECK (LENGTH(username) >= 3) -- ?
);


CREATE TABLE classes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(32) NOT NULL,
    description VARCHAR(255) NOT NULL,
    default_strength INTEGER NOT NULL CHECK (default_strength >= 0), -- can not be negative value
    default_dexterity INTEGER NOT NULL CHECK (default_dexterity >= 0),
    default_constitution INTEGER NOT NULL CHECK (default_constitution >= 0),
    default_intelligence INTEGER NOT NULL CHECK (default_intelligence >= 0),
    default_health INTEGER NOT NULL CHECK (default_health > 0)
);


CREATE TABLE item_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(20) NOT NULL UNIQUE,
    description VARCHAR(255) NOT NULL
);


CREATE TABLE equipment_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(20) NOT NULL UNIQUE,
    description VARCHAR(255) NOT NULL
);


CREATE TABLE spell_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(20) NOT NULL UNIQUE,
    description VARCHAR(255) NOT NULL
);



CREATE TABLE spells (
    id SERIAL PRIMARY KEY,
    spell_category_id INTEGER NOT NULL REFERENCES spell_categories(id) ON DELETE CASCADE,
    name VARCHAR(32) NOT NULL,
    cost INTEGER NOT NULL CHECK (cost >= 0),
    rarity VARCHAR(16) NOT NULL CHECK (rarity IN ( -- define types for rarity
        'common', 'uncommon', 'rare', 'epic', 'legendary'
    ))
);


CREATE TABLE items (
    id SERIAL PRIMARY KEY,
    name VARCHAR(32) NOT NULL,
    weight INTEGER NOT NULL CHECK (weight >= 0),
    item_type_id INTEGER NOT NULL REFERENCES item_types(id) ON DELETE SET NULL,
    rarity VARCHAR(16) NOT NULL CHECK (rarity IN (
        'common', 'uncommon', 'rare', 'epic', 'legendary'
    ))
);


CREATE TABLE equipments (
    id SERIAL PRIMARY KEY,
    item_id INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    equipment_category_id INTEGER NOT NULL REFERENCES equipment_categories(id) ON DELETE SET NULL
);


CREATE TABLE equipment_modifiers (
    id SERIAL PRIMARY KEY,
    equipment_id INTEGER NOT NULL REFERENCES equipments(id) ON DELETE CASCADE,
    modifier_type VARCHAR(20) NOT NULL CHECK (modifier_type IN (
        'strength', 'dexterity', 'constitution',
        'intelligence', 'health',
        'armor', 'inventory', 'action_points'
    )),
    modifier_value NUMERIC NOT NULL
);


CREATE TABLE character_game_stats (
    id SERIAL PRIMARY KEY,
    total_combats INTEGER DEFAULT 0 CHECK (total_combats >= 0),
    total_wins INTEGER DEFAULT 0 CHECK (total_wins >= 0),
    total_losses INTEGER DEFAULT 0 CHECK (total_losses >= 0)
);


CREATE TABLE characters (
    id SERIAL PRIMARY KEY,
    class_id INTEGER NOT NULL REFERENCES classes(id) ON DELETE SET NULL,
    strength INTEGER NOT NULL CHECK (strength >= 0),
    dexterity INTEGER NOT NULL CHECK (dexterity >= 0),
    constitution INTEGER NOT NULL CHECK (constitution >= 0),
    intelligence INTEGER NOT NULL CHECK (intelligence >= 0),
    health INTEGER NOT NULL CHECK (health >= 0),
    action_points INTEGER, --
--     armor_points INTEGER, -- calculated in battle
    character_game_stats_id INTEGER NOT NULL UNIQUE REFERENCES character_game_stats(id) ON DELETE CASCADE
);


CREATE TABLE combats (
    id SERIAL PRIMARY KEY,
    date TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    rounds_count INTEGER NOT NULL CHECK (rounds_count >= 0),
    winner_id INTEGER REFERENCES characters(id) ON DELETE SET NULL
);


CREATE TABLE game_items (
    id SERIAL PRIMARY KEY,
    item_id INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    combat_id INTEGER NOT NULL REFERENCES combats(id) ON DELETE CASCADE,
    character_id INTEGER REFERENCES characters(id) ON DELETE SET NULL,
    event_type VARCHAR(20) NOT NULL CHECK (event_type IN (
        'spawn', 'pickup', 'drop',
        'drop & pickup', 'spawn & pickup'
    ))
);


CREATE TABLE item_storages (
    id SERIAL PRIMARY KEY,
    item_id INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE
);


CREATE TABLE sleep_characters (
    id SERIAL PRIMARY KEY,
    character_id INTEGER REFERENCES characters(id) ON DELETE CASCADE,
    max_health INTEGER NOT NULL CHECK (max_health > 0),
    wake_up_time TIMESTAMP,
    last_sleep_time TIMESTAMP
);


CREATE TABLE inventories (
    id SERIAL PRIMARY KEY,
    character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    item_id INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE
);


CREATE TABLE character_equipments (
    id SERIAL PRIMARY KEY,
    character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    item_id INTEGER NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    slot_type VARCHAR(10) NOT NULL CHECK (slot_type IN (
        'head', 'chest', 'legs',
        'weapon', 'shield', 'accessory'
    )),
    UNIQUE (character_id, slot_type)
);


CREATE TABLE character_spells (
    id SERIAL PRIMARY KEY,
    character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    spell_id INTEGER NOT NULL REFERENCES spells(id) ON DELETE CASCADE,
    UNIQUE (character_id, spell_id)
);


CREATE TABLE combat_players (
    id SERIAL PRIMARY KEY,
    combat_id INTEGER NOT NULL REFERENCES combats(id) ON DELETE CASCADE,
    character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    entry_health INTEGER NOT NULL CHECK (entry_health > 0),
    UNIQUE (combat_id, character_id)
);


CREATE TABLE combat_logs (
    id SERIAL PRIMARY KEY,
    combat_id INTEGER NOT NULL REFERENCES combats(id) ON DELETE CASCADE,
    character_id INTEGER REFERENCES characters(id) ON DELETE SET NULL,
    character2_id INTEGER REFERENCES characters(id) ON DELETE SET NULL,
    date TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    action VARCHAR(20) NOT NULL CHECK (action IN (
        'attack', 'use_item', 'cast_spell', -- use_item - actually not in use
        'loot_item', 'drop_item',
        'enter_combat', --'leave_combat',
        'reset_round'
    )),
    event_msg_type VARCHAR(20) NOT NULL CHECK (event_msg_type IN (
        'success', 'failure', 'kill',
        'critical_hit', 'miss' -- Actually does not in use
    )),
    round_number INTEGER NOT NULL CHECK (round_number >= 0),
    damage INTEGER CHECK (damage >= 0),
    damage_type VARCHAR(16) CHECK (damage_type IN (
       'physical', 'magical'
    )),
    item_id INTEGER REFERENCES items(id) ON DELETE SET NULL,
    spell_id INTEGER REFERENCES spells(id) ON DELETE SET NULL
);


CREATE TABLE spell_configurations (
    id SERIAL PRIMARY KEY,
    spell_id INTEGER NOT NULL REFERENCES spells(id) ON DELETE CASCADE,
    effect_type VARCHAR(16) NOT NULL CHECK (effect_type IN (
        'base_damage', 'damage' -- , 'heal', 'buff', 'debuff' -- actually use only base_damage and damage
    )),
    effect_bonus_value INTEGER NOT NULL,
    target_attribute VARCHAR(16) NOT NULL CHECK (target_attribute IN (
        'strength', 'dexterity', 'constitution',
        'intelligence', 'health'
    ))
);


CREATE TABLE class_modifiers (
    id SERIAL PRIMARY KEY,
    class_id INTEGER NOT NULL REFERENCES classes(id) ON DELETE CASCADE,
    modifier_type VARCHAR(16) NOT NULL CHECK (modifier_type IN (
--         'strength', 'dexterity', 'constitution', -- actually not in use
--         'intelligence', 'health',
        'armor', 'inventory', 'action_points'
    )),
    modifier_value NUMERIC NOT NULL,
    UNIQUE(class_id, modifier_type)
);


CREATE TABLE users_characters (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    UNIQUE (user_id, character_id)
);

-- INDEXES
CREATE INDEX idx_characters_class_id ON characters (class_id);
-- CREATE INDEX idx_characters_health ON characters (health);
CREATE INDEX idx_character_spells_character_id ON character_spells (character_id);
CREATE INDEX idx_character_spells_spell_id ON character_spells (spell_id);
CREATE INDEX idx_character_equipments_character_id ON character_equipments (character_id);
CREATE INDEX idx_equipment_modifiers_equipment_id ON equipment_modifiers (equipment_id);
CREATE INDEX idx_equipment_modifiers_modifier_type ON equipment_modifiers (modifier_type);
CREATE INDEX idx_class_modifiers_class_id ON class_modifiers (class_id);
CREATE INDEX idx_class_modifiers_modifier_type ON class_modifiers (modifier_type);
CREATE INDEX idx_spell_configurations_spell_id ON spell_configurations (spell_id);
CREATE INDEX idx_spell_configurations_effect_type ON spell_configurations (effect_type);
CREATE INDEX idx_combat_players_combat_id ON combat_players (combat_id);
CREATE INDEX idx_combat_players_character_id ON combat_players (character_id);
CREATE INDEX idx_game_items_item_id ON game_items (item_id);
CREATE INDEX idx_game_items_character_id ON game_items (character_id);
CREATE INDEX idx_inventories_character_id ON inventories (character_id);
CREATE INDEX idx_items_rarity ON items (rarity);
CREATE INDEX idx_sleep_characters_character_id ON sleep_characters (character_id);
CREATE INDEX idx_combat_logs_combat_id ON combat_logs (combat_id);
CREATE INDEX idx_combat_logs_character_id ON combat_logs (character_id);
CREATE INDEX idx_combat_logs_date ON combat_logs (date);



