

-- INITIAL CHARACTERISTICS:
DO $$
BEGIN

    -- Equipments can modification user stats, it will be handled in another function.
    -- It's not a part of the basic functions.
    RAISE NOTICE 'Formulas:';
    RAISE NOTICE 'MAX_AP = (Dexterity + Constitution) * ClassModifier(''action_points'')';
    RAISE NOTICE 'E𝑓𝑓𝑒𝑐𝑡𝑖𝑣𝑒𝐶𝑜𝑠𝑡 = 𝐵𝑎𝑠𝑒𝐶𝑜𝑠𝑡 * 𝐶𝑎𝑡𝑒𝑔𝑜𝑟𝑦.𝑀𝑜𝑑𝑖𝑓𝑖𝑒𝑟(1 − 𝑆𝑒𝑙𝑒𝑐𝑡𝑒𝑑𝐴𝑡𝑡𝑟𝑖𝑏𝑢𝑡𝑒/100)(1 − 𝐼𝑡𝑒𝑚𝑀𝑜𝑑𝑖𝑓𝑖𝑒𝑟𝑠)';

    -- INITIAL CHARACTERISTICS:
    RAISE NOTICE '
    INITIAL CHARACTERISTICS:

    Caster: Mage
    ID: 2 | Constitution: 5 | Dexterity: 8 | Strength: 4 | Health: 60 | Intelligence: 12
    Equipment:
      Shield (ID: 2) - ''Steel Shield'' | Weight: 7 | Type: Armor | Rarity: Rare | Bonus: +4
    Character Spells:
      Fireball (ID: 1) | Category: 1 | Cost: 10 | Rarity: Common
      Ice Spike (ID: 2) | Category: 2 | Cost: 15 | Rarity: Rare
    Spell Configurations:
      Fireball (S_ID: 1) | Base Damage: 20 | Scaling: Strength
      Ice Spike (S_ID: 2) | Base Damage: 25 | Scaling: Intelligence

    Caster: Paladin
    ID: 4 | Role: A holy knight | Constitution: 12 | Dexterity: 6 | Strength: 8 | Health: 80 | Intelligence: 8
    Equipment:
      Accessory (ID: 4, 500) - Ring Storage | Weight: 1 | Type: Accessory | Rarity: Epic | Inventory Bonus: +3
    Character Spells:
      Spell IDs: (5, 4, 4) - ''Paladin''
                 (6, 4, 3)
      Lightning Bolt (ID: 3) | Cost: 20 | Rarity: Epic
      Dark Wave (ID: 4) | Cost: 8 | Rarity: Uncommon
    Spell Configurations:
      Lightning Bolt (S_ID: 3) | Base Damage: 30 | Scaling: Strength
      Dark Wave (S_ID: 4) | Base Damage: 15 | Scaling: Strength
    Bonus Damage:
      ID: 6, 3 | Damage Type: Constitution-based | Value: 10 | Applied to target constitution
    ';
end;
$$;

-- Perform test
-- 2 attack 4 with spell_id 1
DO $$
DECLARE
    input RECORD;
    output RECORD;
    cost NUMERIC;
BEGIN
    PERFORM sp_reset_test_data();

    SELECT * INTO input FROM characters WHERE id = 2;
    RAISE NOTICE 'Character 2 parameters before casting: %s.
        Where hp: % and ap: %', input, input.health, input.action_points;
    cost := input.action_points; -- Save cost first AP;
    SELECT * INTO input FROM characters WHERE id = 4;
    RAISE NOTICE 'Character 4 parameters before casting: %s.
        Where hp: % and ap: %', input, input.health, input.action_points;

    -- Character 2 performs a spell on character 4
    RAISE NOTICE 'CASTING SPELL, P1 CASTS SPELL ON P2(SPELL_ID: 1)';
    PERFORM sp_cast_spell(2, 4, 1);

    SELECT * INTO output FROM characters WHERE id = 2;
    RAISE NOTICE 'Character 2 parameters after casting: %s.
        Where hp: % and ap: %', output, output.health, output.action_points;
    cost := cost - output.action_points; -- Update cost using new AP value;
    SELECT * INTO output FROM characters WHERE id = 4;
    RAISE NOTICE 'Character 4 parameters after casting: %s.
        Where hp: % and ap: %', output, output.health, output.action_points;

    RAISE NOTICE '----------------------------------------------';
    RAISE NOTICE 'Total AP cost(player1): %', cost;
    RAISE NOTICE 'Total damage: %', input.health - output.health;
    RAISE NOTICE '----------------------------------------------';

    -- Check answer
    -- CHECK COST f_effective_spell_cost(1, 2) IN f_effective_spell_cost TEST
    -- DAMAGE = BaseCost(20) * (1 - Intelligence(12)/100) * (1 - EquipmentModifier('strength')(NOT SET(DEFAULT = 1)))
    IF cost != 9 OR input.health - output.health != 20 THEN
        IF input.health - output.health = 0 OR cost = 9 THEN
            RAISE NOTICE 'TEST PASSED';
        ELSE
            RAISE EXCEPTION 'TEST FAILED';
        END IF;
    ELSE
        RAISE NOTICE 'TEST PASSED';
    END IF;
END;
$$;


-- Revenge, 4 attacks 2 with spell_id 3
-- OUTPUT 0 OR 42, IF SPELL => TARGET(42), else 0

-- Perform test
DO $$
DECLARE
    input RECORD;
    output RECORD;
    cost NUMERIC;
BEGIN
    PERFORM sp_reset_test_data();

    SELECT * INTO input FROM characters WHERE id = 4;
    RAISE NOTICE 'Character 4 parameters before casting: %s.
        Where hp: % and ap: %', input, input.health, input.action_points;
    cost := input.action_points; -- Save cost first AP;
    SELECT * INTO input FROM characters WHERE id = 2;
    RAISE NOTICE 'Character 2 parameters before casting: %s.
        Where hp: % and ap: %', input, input.health, input.action_points;

    -- Character 2 performs a spell on character 4
    RAISE NOTICE 'CASTING SPELL, P1 CASTS SPELL ON P2(SPELL_ID: 1)';
    PERFORM sp_cast_spell(4, 2, 3);

    SELECT * INTO output FROM characters WHERE id = 4;
    RAISE NOTICE 'Character 4 parameters after casting: %s.
        Where hp: % and ap: %', output, output.health, output.action_points;
    cost := cost - output.action_points; -- Update cost using new AP value;
    SELECT * INTO output FROM characters WHERE id = 2;
    RAISE NOTICE 'Character 2 parameters after casting: %s.
        Where hp: % and ap: %', output, output.health, output.action_points;

    RAISE NOTICE '----------------------------------------------';
    RAISE NOTICE 'Total AP cost(player1): %', cost;
    RAISE NOTICE 'Total damage: %', input.health - output.health;
    RAISE NOTICE '----------------------------------------------';

    -- Check answer
    -- BaseCost * ClassModifier('action_points') * (1 - Intelligence/100) * (1 - EquipmentModifier('action_points'))
    -- COST(AP) = 20 * 1.2 * (1 - 8/100) * (1-0/100) ~ 22
    -- BaseDamage + SUM(BonusDamage * (1 + targetConstitution/20))
    -- DAMAGE = 30 + (10 * (1 + 5/20)) ~ 42(42.5=>42)
    IF cost != 22 OR input.health - output.health != 42 THEN
        IF input.health - output.health = 0 OR cost = 22 THEN
            RAISE NOTICE 'TEST PASSED';
        ELSE
            RAISE EXCEPTION 'TEST FAILED';
        END IF;
    ELSE
        RAISE NOTICE 'TEST PASSED';
    END IF;
END;
$$;


SELECT * FROM characters;
