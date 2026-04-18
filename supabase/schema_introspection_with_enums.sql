-- ========================================================================
-- IMPROVED SCHEMA INTROSPECTION QUERY WITH ENUM VALUES
-- Shows all columns with their types and includes enum literal values
-- ========================================================================

SELECT 
    c.table_name,
    c.column_name,
    c.data_type,
    c.is_nullable,
    c.column_default,
    c.udt_name,
    -- Get enum values if the column is an enum type
    CASE 
        WHEN c.udt_name IN (SELECT typname FROM pg_type WHERE typtype = 'e') THEN
            STRING_AGG(e.enumlabel, ', ' ORDER BY e.enumsortorder)
        ELSE NULL
    END as enum_values
FROM 
    information_schema.columns c
LEFT JOIN 
    pg_enum e ON c.udt_name = e.enumtypid::regtype::text
    AND c.data_type = 'USER-DEFINED'
LEFT JOIN 
    pg_type t ON c.udt_name = t.typname
WHERE 
    c.table_schema = 'public'
    AND c.table_catalog = current_database()
GROUP BY 
    c.table_name,
    c.column_name,
    c.data_type,
    c.is_nullable,
    c.column_default,
    c.udt_name
ORDER BY 
    c.table_name,
    c.ordinal_position;

-- ========================================================================
-- ALTERNATIVE: Get ALL Enums in the database with their values
-- ========================================================================

SELECT 
    t.typname as enum_name,
    STRING_AGG(e.enumlabel, ', ' ORDER BY e.enumsortorder) as enum_values
FROM 
    pg_type t
JOIN 
    pg_enum e ON t.oid = e.enumtypid
WHERE 
    t.typtype = 'e'
GROUP BY 
    t.typname
ORDER BY 
    t.typname;

-- ========================================================================
-- Query to find which columns use specific enums
-- ========================================================================

SELECT DISTINCT
    c.table_name,
    c.column_name,
    c.udt_name,
    STRING_AGG(e.enumlabel, ', ' ORDER BY e.enumsortorder) as enum_values
FROM 
    information_schema.columns c
LEFT JOIN 
    pg_type t ON c.udt_name = t.typname
LEFT JOIN 
    pg_enum e ON t.oid = e.enumtypid
WHERE 
    c.table_schema = 'public'
    AND c.data_type = 'USER-DEFINED'
GROUP BY 
    c.table_name,
    c.column_name,
    c.udt_name
ORDER BY 
    c.table_name,
    c.column_name;
