-- 098_fix_turkish_character_encoding_mojibake.sql
-- Fix double-encoded UTF-8 / Mojibake Turkish characters across all database tables

DO $$
DECLARE
  r RECORD;
  v_sql text;
  v_count int;
BEGIN
  FOR r IN 
    SELECT c.table_schema, c.table_name, c.column_name
    FROM information_schema.columns c
    JOIN information_schema.tables t 
      ON c.table_schema = t.table_schema AND c.table_name = t.table_name
    WHERE c.data_type IN ('text', 'character varying')
      AND t.table_type = 'BASE TABLE'
      AND c.table_schema NOT IN ('pg_catalog', 'information_schema')
  LOOP
    -- Check if column contains any double-encoded characters
    v_sql := format(
      'SELECT COUNT(*) FROM %I.%I WHERE %I ~ ''(ÅŸ|Åž|Ä±|Ä°|ÄŸ|Äž|Ã¼|Ãœ|Ã¶|Ã–|Ã§|Ã‡)''',
      r.table_schema, r.table_name, r.column_name
    );
    EXECUTE v_sql INTO v_count;
    
    IF v_count > 0 THEN
      v_sql := format(
        'UPDATE %I.%I SET %I = replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(%I,
          ''ÅŸ'', ''ş''), ''Åž'', ''Ş''), ''Ä±'', ''ı''), ''Ä°'', ''İ''), ''ÄŸ'', ''ğ''), ''Äž'', ''Ğ''), ''Ã¼'', ''ü''), ''Ãœ'', ''Ü''), ''Ã¶'', ''ö''), ''Ã–'', ''Ö''), ''Ã§'', ''ç''), ''Ã‡'', ''Ç'')
         WHERE %I ~ ''(ÅŸ|Åž|Ä±|Ä°|ÄŸ|Äž|Ã¼|Ãœ|Ã¶|Ã–|Ã§|Ã‡)''',
        r.table_schema, r.table_name, r.column_name, r.column_name, r.column_name
      );
      EXECUTE v_sql;
    END IF;
  END LOOP;
END;
$$;
