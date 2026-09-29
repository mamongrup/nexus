-- Close the known-demo-password risk for platform sample staff accounts.
-- These accounts are useful as role examples in local development, but they
-- must not remain login-capable with a public password such as password123.
WITH demo_accounts(email) AS (
  VALUES
    ('operasyon@nexus.local'),
    ('moderator@nexus.local'),
    ('finans@nexus.local'),
    ('onboarding@nexus.local'),
    ('ai-muhendis@nexus.local'),
    ('destek@nexus.local')
),
updated AS (
  UPDATE auth.users u
     SET active = false,
         password_hash = crypt(encode(gen_random_bytes(24),'hex'), gen_salt('bf', 12)),
         failed_attempts = 0,
         locked_until = NULL
    FROM demo_accounts d
   WHERE u.email = d.email
   RETURNING u.id
)
DELETE FROM auth.sessions s
USING updated u
WHERE s.user_id = u.id;
