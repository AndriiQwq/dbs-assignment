SELECT * FROM pg_stat_user_indexes
WHERE idx_scan != 0;

SELECT * FROM pg_stat_user_indexes
WHERE idx_scan = 0;

SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public';

