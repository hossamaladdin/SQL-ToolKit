SELECT 
    local_database_name,
    role_desc,
    internal_state_desc,
    transfer_rate_bytes_per_second,
    transferred_size_bytes,
    database_size_bytes,
    percent_complete = 
        CASE 
            WHEN database_size_bytes = 0 THEN NULL
            ELSE CAST(transferred_size_bytes * 100.0 / database_size_bytes AS DECIMAL(5,2))
        END,
    start_time_utc,
    estimate_time_complete_utc,
    is_compression_enabled
FROM sys.dm_hadr_physical_seeding_stats;
