-- =====================================================================
-- Activity 7: PostgreSQL Roles and Access Control
-- Climate & Crop Productivity Monitoring and Decision Support System
-- Run this on the project database by a superuser/owner account.
-- =====================================================================

-- 1. Create application-level roles matching the system's actual roles
CREATE ROLE app_farmer NOLOGIN;
CREATE ROLE app_admin NOLOGIN;

-- 2. Allow both roles to use the schema
GRANT USAGE ON SCHEMA public TO app_farmer, app_admin;

-- 3. Farmer role: can manage their own farms, productivity records,
--    and climate readings. Row-ownership itself is enforced in the
--    FastAPI application layer using the authenticated user's ID.
GRANT SELECT, INSERT, UPDATE ON TABLE farms TO app_farmer;
GRANT SELECT, INSERT, DELETE ON TABLE productivity_records TO app_farmer;
GRANT SELECT, INSERT ON TABLE climate_readings TO app_farmer;

-- 4. Farmers must NEVER access password reset tokens directly.
--    This table is backend-internal only.
REVOKE ALL ON TABLE password_reset_tokens FROM app_farmer;

-- 5. Admin role: broader access for system oversight, but still
--    limited — not given blanket privileges on every table.
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE farms TO app_admin;
GRANT SELECT, DELETE ON TABLE productivity_records TO app_admin;
GRANT SELECT, UPDATE ON TABLE users TO app_admin;

-- 6. Even the Admin application role should not touch reset tokens
--    directly; only backend service logic (e.g. auth.py) handles them.
REVOKE ALL ON TABLE password_reset_tokens FROM app_admin;

-- =====================================================================
-- End of Activity 7 access-control statements.
-- =====================================================================