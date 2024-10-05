-- Create a role for anonymous access
CREATE ROLE web_anon NOLOGIN;

COMMIT;

-- Grant usage on the public schema to the web_anon role
GRANT USAGE ON SCHEMA public TO web_anon;

-- Grant SELECT on all tables in the public schema to web_anon
GRANT
SELECT
    ON ALL TABLES IN SCHEMA public TO web_anon;

-- Ensure future tables will have SELECT permission for web_anon
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT
SELECT
    ON TABLES TO web_anon;

-- Create a sample table (if you don't have one)
CREATE TABLE
    public.items (
        id SERIAL PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT
    );

-- Insert sample data
INSERT INTO
    public.items (name, description)
VALUES
    ('Item 1', 'Description for item 1'),
    ('Item 2', 'Description for item 2');