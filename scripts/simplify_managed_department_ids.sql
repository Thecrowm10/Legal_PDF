-- ============================================================
-- Simplify Nodal Officer Managed Departments
--
-- Replaces the nodal_officer_departments junction table with a
-- plain comma-separated column on the users table.
-- This makes registration a single API call.
--
-- Changes:
--   1. Add    : users.managed_department_ids NVARCHAR(500)
--   2. Migrate: existing junction-table rows → comma-separated string
--   3. Drop   : nodal_officer_departments table + its two SPs
--   4. Update : sp_create_user  — accepts @managed_department_ids
--   5. Update : sp_update_user  — accepts @managed_department_ids
--   6. Update : all user-getter SPs — return managed_department_ids
--              (replaces the managed_departments_json subquery)
--
-- Run via sqlcmd:
--   sqlcmd -S <server> -U sa -P <pass> -i scripts\simplify_managed_department_ids.sql
-- ============================================================

USE Legal_PDF;
GO

-- ─────────────────────────────────────────────────────────────
-- 1. Add managed_department_ids column
-- ─────────────────────────────────────────────────────────────

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE  object_id = OBJECT_ID('dbo.users') AND name = 'managed_department_ids'
)
BEGIN
    ALTER TABLE dbo.users ADD managed_department_ids NVARCHAR(500) NULL;
    PRINT 'Column managed_department_ids added to users.';
END
ELSE
    PRINT 'Column managed_department_ids already exists — skipping ADD.';
GO

-- ─────────────────────────────────────────────────────────────
-- 2. Migrate existing junction-table data
--    Converts rows in nodal_officer_departments into a
--    comma-separated string and writes it back to users.
-- ─────────────────────────────────────────────────────────────

IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'nodal_officer_departments')
BEGIN
    UPDATE u
    SET    u.managed_department_ids = agg.ids
    FROM   dbo.users u
    INNER  JOIN (
        SELECT   user_id,
                 STRING_AGG(CAST(department_id AS NVARCHAR(10)), ',')
                     WITHIN GROUP (ORDER BY department_id) AS ids
        FROM     dbo.nodal_officer_departments
        GROUP BY user_id
    ) agg ON agg.user_id = u.id;

    PRINT 'Migrated nodal_officer_departments rows into users.managed_department_ids.';
END
GO

-- ─────────────────────────────────────────────────────────────
-- 3. Drop obsolete SPs and junction table
-- ─────────────────────────────────────────────────────────────

IF OBJECT_ID('dbo.sp_get_nodal_officer_departments', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_get_nodal_officer_departments;
    PRINT 'Dropped sp_get_nodal_officer_departments.';
END
GO

IF OBJECT_ID('dbo.sp_set_nodal_officer_departments', 'P') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.sp_set_nodal_officer_departments;
    PRINT 'Dropped sp_set_nodal_officer_departments.';
END
GO

IF EXISTS (SELECT 1 FROM sys.tables WHERE name = 'nodal_officer_departments')
BEGIN
    DROP TABLE dbo.nodal_officer_departments;
    PRINT 'Dropped nodal_officer_departments table.';
END
GO

-- ─────────────────────────────────────────────────────────────
-- 4. sp_create_user — accept and store managed_department_ids
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_create_user
    @username                NVARCHAR(100),
    @email                   NVARCHAR(255),
    @hashed_password         NVARCHAR(255),
    @first_name              NVARCHAR(100) = NULL,
    @last_name               NVARCHAR(100) = NULL,
    @role_id                 INT           = NULL,
    @department_id           INT           = NULL,
    @mobile_number           NVARCHAR(20)  = NULL,
    @managed_department_ids  NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @new_id INT;

    INSERT INTO dbo.users
        (username, email, hashed_password, first_name, last_name,
         role_id, department_id, mobile_number,
         managed_department_ids, password_changed_at)
    VALUES
        (@username, @email, @hashed_password, @first_name, @last_name,
         @role_id, @department_id, @mobile_number,
         @managed_department_ids, GETUTCDATE());

    SET @new_id = SCOPE_IDENTITY();

    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password, u.password_changed_at,
        u.managed_department_ids,
        u.role_id,       r.name AS role_name,       r.description AS role_description,
        u.department_id, d.name AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        NULL AS last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r ON r.id = u.role_id
    LEFT  JOIN dbo.departments d ON d.id = u.department_id
    WHERE u.id = @new_id;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 5. sp_update_user — accept and update managed_department_ids
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_update_user
    @user_id                 INT,
    @first_name              NVARCHAR(100) = NULL,
    @last_name               NVARCHAR(100) = NULL,
    @email                   NVARCHAR(255) = NULL,
    @is_active               BIT           = NULL,
    @role_id                 INT           = NULL,
    @department_id           INT           = NULL,
    @mobile_number           NVARCHAR(20)  = NULL,
    @managed_department_ids  NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.users
    SET
        first_name             = COALESCE(@first_name,             first_name),
        last_name              = COALESCE(@last_name,              last_name),
        email                  = COALESCE(@email,                  email),
        is_active              = COALESCE(@is_active,              is_active),
        role_id                = COALESCE(@role_id,                role_id),
        department_id          = COALESCE(@department_id,          department_id),
        mobile_number          = COALESCE(@mobile_number,          mobile_number),
        managed_department_ids = COALESCE(@managed_department_ids, managed_department_ids),
        updated_at             = GETUTCDATE()
    WHERE id = @user_id;

    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password, u.password_changed_at,
        u.managed_department_ids,
        u.role_id,       r.name AS role_name,       r.description AS role_description,
        u.department_id, d.name AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = u.department_id
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.id = @user_id;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 6. sp_get_user_by_id
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_id
    @user_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password, u.password_changed_at,
        u.managed_department_ids,
        u.role_id,       r.name AS role_name,       r.description AS role_description,
        u.department_id, d.name AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = u.department_id
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.id = @user_id;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 7. sp_get_user_by_username
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_username
    @username NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password, u.password_changed_at,
        u.managed_department_ids,
        u.role_id,       r.name AS role_name,       r.description AS role_description,
        u.department_id, d.name AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = u.department_id
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.username = @username;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 8. sp_get_user_by_email
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_email
    @email NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password, u.password_changed_at,
        u.managed_department_ids,
        u.role_id,       r.name AS role_name,       r.description AS role_description,
        u.department_id, d.name AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = u.department_id
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.email = @email;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 9. sp_get_user_by_mobile
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_mobile
    @mobile_number NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password, u.password_changed_at,
        u.managed_department_ids,
        u.role_id,       r.name AS role_name,       r.description AS role_description,
        u.department_id, d.name AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = u.department_id
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.mobile_number = @mobile_number;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 10. sp_list_users
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_list_users
    @skip            INT           = 0,
    @limit           INT           = 100,
    @exclude_user_id INT           = NULL,
    @department_ids  NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password, u.password_changed_at,
        u.managed_department_ids,
        u.role_id,       r.name AS role_name,       r.description AS role_description,
        u.department_id, d.name AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = u.department_id
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.roles r2
        WHERE  r2.id = u.role_id AND r2.name = 'super_admin'
    )
    AND (@exclude_user_id IS NULL OR u.id <> @exclude_user_id)
    AND (
        @department_ids IS NULL
        OR u.department_id IN (
            SELECT CAST(TRIM(value) AS INT)
            FROM   STRING_SPLIT(@department_ids, ',')
            WHERE  LEN(TRIM(value)) > 0
        )
    )
    ORDER  BY u.id
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO

PRINT 'Migration simplify_managed_department_ids completed successfully.';
GO
