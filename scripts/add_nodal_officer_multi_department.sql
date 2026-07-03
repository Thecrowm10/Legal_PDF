-- ============================================================
-- Nodal Officer Multi-Department Support
--
-- A nodal officer can now manage one or more departments.
-- Managed departments are stored in a separate junction table.
-- The user's own department_id column is unchanged (it still
-- represents the department the user *belongs to*).
--
-- Changes:
--   1. New table  : nodal_officer_departments
--   2. New SPs    : sp_get_nodal_officer_departments
--                   sp_set_nodal_officer_departments
--   3. Updated SPs: all user-getter SPs gain managed_departments_json
--                   sp_list_users @department_id → @department_ids (multi)
-- ============================================================

USE Legal_PDF;
GO

-- ─────────────────────────────────────────────
-- 1. Junction table
-- ─────────────────────────────────────────────

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'nodal_officer_departments')
CREATE TABLE dbo.nodal_officer_departments (
    id            INT IDENTITY(1,1) PRIMARY KEY,
    user_id       INT NOT NULL REFERENCES dbo.users(id)       ON DELETE CASCADE,
    department_id INT NOT NULL REFERENCES dbo.departments(id) ON DELETE CASCADE,
    created_at    DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    CONSTRAINT UQ_nodal_officer_dept UNIQUE (user_id, department_id)
);
GO

-- ─────────────────────────────────────────────
-- 2. sp_get_nodal_officer_departments
--    Returns full department rows for a given user.
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_nodal_officer_departments
    @user_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT d.id, d.name, d.description
    FROM   dbo.nodal_officer_departments nd
    INNER  JOIN dbo.departments d ON d.id = nd.department_id
    WHERE  nd.user_id = @user_id
    ORDER  BY d.name;
END;
GO

-- ─────────────────────────────────────────────
-- 3. sp_set_nodal_officer_departments
--    Replaces ALL managed departments for a user.
--    Pass NULL or empty string to clear.
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_set_nodal_officer_departments
    @user_id        INT,
    @department_ids NVARCHAR(MAX) = NULL    -- comma-separated IDs, e.g. '1,3,5'
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM dbo.nodal_officer_departments WHERE user_id = @user_id;
    IF @department_ids IS NOT NULL AND LEN(TRIM(@department_ids)) > 0
    BEGIN
        INSERT INTO dbo.nodal_officer_departments (user_id, department_id)
        SELECT @user_id, CAST(TRIM(value) AS INT)
        FROM   STRING_SPLIT(@department_ids, ',')
        WHERE  LEN(TRIM(value)) > 0;
    END;
END;
GO

-- ─────────────────────────────────────────────
-- Helper subquery used in every user-getter SP.
-- Returns a JSON array of managed departments,
-- e.g. [{"id":1,"name":"Finance","description":"..."}]
-- NULL when the user has no managed departments.
-- ─────────────────────────────────────────────

-- ─────────────────────────────────────────────
-- 4. sp_get_user_by_id  (updated)
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_id
    @user_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name, u.mobile_number,
        u.must_change_password, u.password_changed_at,
        u.role_id,       r.name AS role_name,       r.description AS role_description,
        u.department_id, d.name AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        (SELECT nd.department_id AS id, dep.name, dep.description
         FROM   dbo.nodal_officer_departments nd
         INNER  JOIN dbo.departments dep ON dep.id = nd.department_id
         WHERE  nd.user_id = u.id
         FOR JSON PATH) AS managed_departments_json
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r ON r.id = u.role_id
    LEFT  JOIN dbo.departments d ON d.id = u.department_id
    WHERE u.id = @user_id;
END;
GO

-- ─────────────────────────────────────────────
-- 5. sp_get_user_by_username  (updated)
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_username
    @username NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name, u.mobile_number,
        u.must_change_password, u.password_changed_at,
        u.role_id,       r.name AS role_name,       r.description AS role_description,
        u.department_id, d.name AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        (SELECT nd.department_id AS id, dep.name, dep.description
         FROM   dbo.nodal_officer_departments nd
         INNER  JOIN dbo.departments dep ON dep.id = nd.department_id
         WHERE  nd.user_id = u.id
         FOR JSON PATH) AS managed_departments_json
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r ON r.id = u.role_id
    LEFT  JOIN dbo.departments d ON d.id = u.department_id
    WHERE u.username = @username;
END;
GO

-- ─────────────────────────────────────────────
-- 6. sp_get_user_by_email  (updated)
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_email
    @email NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name, u.mobile_number,
        u.must_change_password, u.password_changed_at,
        u.role_id,       r.name AS role_name,       r.description AS role_description,
        u.department_id, d.name AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        (SELECT nd.department_id AS id, dep.name, dep.description
         FROM   dbo.nodal_officer_departments nd
         INNER  JOIN dbo.departments dep ON dep.id = nd.department_id
         WHERE  nd.user_id = u.id
         FOR JSON PATH) AS managed_departments_json
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r ON r.id = u.role_id
    LEFT  JOIN dbo.departments d ON d.id = u.department_id
    WHERE u.email = @email;
END;
GO

-- ─────────────────────────────────────────────
-- 7. sp_get_user_by_mobile  (updated)
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_user_by_mobile
    @mobile_number NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name, u.mobile_number,
        u.must_change_password, u.password_changed_at,
        u.role_id,       r.name AS role_name,       r.description AS role_description,
        u.department_id, d.name AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        (SELECT nd.department_id AS id, dep.name, dep.description
         FROM   dbo.nodal_officer_departments nd
         INNER  JOIN dbo.departments dep ON dep.id = nd.department_id
         WHERE  nd.user_id = u.id
         FOR JSON PATH) AS managed_departments_json
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r ON r.id = u.role_id
    LEFT  JOIN dbo.departments d ON d.id = u.department_id
    WHERE u.mobile_number = @mobile_number;
END;
GO

-- ─────────────────────────────────────────────
-- 8. sp_list_users  (updated)
--    @department_id replaced with @department_ids
--    (comma-separated, e.g. '1,3,5').
--    NULL = no department filter (admin/super_admin).
--    Empty string = filter matches nothing (nodal
--    officer with no assigned departments).
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_list_users
    @skip            INT          = 0,
    @limit           INT          = 100,
    @exclude_user_id INT          = NULL,
    @department_ids  NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name, u.mobile_number, u.must_change_password,
        u.role_id,       r.name  AS role_name,       r.description AS role_description,
        u.department_id, d.name  AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login,
        (SELECT nd.department_id AS id, dep.name, dep.description
         FROM   dbo.nodal_officer_departments nd
         INNER  JOIN dbo.departments dep ON dep.id = nd.department_id
         WHERE  nd.user_id = u.id
         FOR JSON PATH) AS managed_departments_json
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = u.department_id
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs
        WHERE  action = 'login'
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

PRINT 'Migration add_nodal_officer_multi_department completed successfully.';
GO
