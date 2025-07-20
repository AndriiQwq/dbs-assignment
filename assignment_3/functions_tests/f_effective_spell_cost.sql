

-- BaseCost  = 10
-- class_modifiers = 1 NOT SET
-- Selected_attribute = 12 (Intelligence)
-- >>> 10 * (1 - 0.12) = 8.8

-- EffectiveCost=10×(1−0.12)=10×0.88=8.8

-- Perform test
DO $$
DECLARE
    cost NUMERIC;
BEGIN
    PERFORM sp_reset_test_data();

    cost := f_effective_spell_cost(1, 2);

    IF cost != 8.8 THEN
        RAISE EXCEPTION 'TEST FAILED';
    ELSE
        RAISE NOTICE 'TEST PASSED';
    END IF;
END;
$$;









