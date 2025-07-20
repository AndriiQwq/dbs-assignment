
-- Test resting character parameters
DO $$
BEGIN
    -- Let's say that the character play combat and stay with 1 hp and 0ap
    UPDATE characters
    SET action_points = 0, health = 1
    WHERE id = 2;

    -- Reset character
    PERFORM sp_rest_character(2);

    -- Test result
    -- XP => MAX_HP
    -- AP => (dexterity + intelligence) * class_modifiers.modifier_value
    -- class_modifiers not set for 'action_points'
    -- class_modifiers for 'dexterity' or 'intelligence' does not implement/exist
    -- AP => (8 + 12) = 19
    IF (SELECT action_points FROM characters WHERE id = 2) = 19 AND
         (SELECT health FROM characters WHERE id = 2) = 60
        THEN RAISE NOTICE 'TEST PASSED';
    ELSE
        RAISE EXCEPTION 'TEST FAILED';
    END IF;
end;
$$;

select * from characters;
