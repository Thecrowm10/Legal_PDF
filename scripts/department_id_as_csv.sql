-- ============================================================
-- Consolidate department storage into department_id column
--
-- Nodal officers store comma-separated department IDs in the
-- existing department_id column instead of a separate table/column.
--
-- Changes:
--   1. Drop FK constraint on users.department_id
--   2. Migrate existing INT data to string representation
--   3. Alter users.department_id  INT → NVARCHAR(500)
--   4. Migrate managed_department_ids data (if column exists)
--      into department_id for nodal officer rows
--   5. Drop managed_department_ids column (if exists)
--   6. Update all user SPs — department_id param is now NVARCHAR,
--      JOIN uses TRY_CAST so single-dept users still get dept name
-- ============================================================

USE Legal_PDF;
GO

-- ─────────────────────────────────────────────────────────────
-- 1. Drop FK constraint on users.department_id
-- ─────────────────────────────────────────────────────────────

DECLARE @fk_name NVARCHAR(200);
SELECT @fk_name = name
FROM   sys.foreign_keys
WHERE  parent_object_id = OBJECT_ID('dbo.users')
  AND  name LIKE '%department%';

IF @fk_name IS NOT NULL
BEGIN
    EXEC('ALTER TABLE dbo.users DROP CONSTRAINT ' + @fk_name);
    PRINT 'Dropped FK constraint: ' + @fk_name;
END
ELSE
    PRINT 'No department FK constraint found — skipping.';
GO

-- ─────────────────────────────────────────────────────────────
-- 2. Alter department_id from INT to NVARCHAR(500)
--    SQL Server cannot alter a column in-place when other
--    constraints exist; the FK is already dropped above.
-- ─────────────────────────────────────────────────────────────

ALTER TABLE dbo.users ALTER COLUMN department_id NVARCHAR(500) NULL;
PRINT 'Altered users.department_id to NVARCHAR(500).';
GO

-- ─────────────────────────────────────────────────────────────
-- 3. Migrate managed_department_ids → department_id
--    for any nodal officer rows that already have data there.
-- ─────────────────────────────────────────────────────────────

IF EXISTS (
    SELECT 1 FROM sys.columns
    WHERE  object_id = OBJECT_ID('dbo.users') AND name = 'managed_department_ids'
)
BEGIN
    UPDATE dbo.users
    SET    department_id = managed_department_ids
    WHERE  managed_department_ids IS NOT NULL
      AND  EXISTS (
               SELECT 1 FROM dbo.roles r
               WHERE r.id = role_id AND r.name = 'nodal Officer'
           );
    PRINT 'Migrated managed_department_ids into department_id for nodal officers.';

    ALTER TABLE dbo.users DROP COLUMN managed_department_ids;
    PRINT 'Dropped managed_department_ids column.';
END
ELSE
    PRINT 'managed_department_ids column does not exist — skipping migration.';
GO

-- ─────────────────────────────────────────────────────────────
-- 4. sp_create_user
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_create_user
    @username        NVARCHAR(100),
    @email           NVARCHAR(255),
    @hashed_password NVARCHAR(255),
    @first_name      NVARCHAR(100) = NULL,
    @last_name       NVARCHAR(100) = NULL,
    @role_id         INT           = NULL,
    @department_id   NVARCHAR(500) = NULL,
    @mobile_number   NVARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @new_id INT;

    INSERT INTO dbo.users
        (username, email, hashed_password, first_name, last_name,
         role_id, department_id, mobile_number, password_changed_at)
    VALUES
        (@username, @email, @hashed_password, @first_name, @last_name,
         @role_id, @department_id, @mobile_number, GETUTCDATE());

    SET @new_id = SCOPE_IDENTITY();

    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password, u.password_changed_at,
        u.department_id,
        u.role_id,       r.name AS role_name,       r.description AS role_description,
        d.name AS department_name, d.description AS department_description,
        u.created_at, u.updated_at,
        NULL AS last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r ON r.id = u.role_id
    LEFT  JOIN dbo.departments d ON d.id = TRY_CAST(u.department_id AS INT)
    WHERE u.id = @new_id;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 5. sp_update_user
-- ─────────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_update_user
    @user_id       INT,
    @first_name    NVARCHAR(100) = NULL,
    @last_name     NVARCHAR(100) = NULL,
    @email         NVARCHAR(255) = NULL,
    @is_active     BIT           = NULL,
    @role_id       INT           = NULL,
    @department_id NVARCHAR(500) = NULL,
    @mobile_number NVARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.users
    SET
        first_name    = COALESCE(@first_name,    first_name),
        last_name     = COALESCE(@last_name,     last_name),
        email         = COALESCE(@email,         email),
        is_active     = COALESCE(@is_active,     is_active),
        role_id       = COALESCE(@role_id,       role_id),
        department_id = COALESCE(@department_id, department_id),
        mobile_number = COALESCE(@mobile_number, mobile_number),
        updated_at    = GETUTCDATE()
    WHERE id = @user_id;

    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password, u.password_changed_at,
        u.department_id,
        u.role_id,       r.name AS role_name,       r.description AS role_description,
        d.name AS department_name, d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = TRY_CAST(u.department_id AS INT)
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
        u.department_id,
        u.role_id,       r.name AS role_name,       r.description AS role_description,
        d.name AS department_name, d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = TRY_CAST(u.department_id AS INT)
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
        u.department_id,
        u.role_id,       r.name AS role_name,       r.description AS role_description,
        d.name AS department_name, d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = TRY_CAST(u.department_id AS INT)
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
        u.department_id,
        u.role_id,       r.name AS role_name,       r.description AS role_description,
        d.name AS department_name, d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = TRY_CAST(u.department_id AS INT)
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
        u.department_id,
        u.role_id,       r.name AS role_name,       r.description AS role_description,
        d.name AS department_name, d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = TRY_CAST(u.department_id AS INT)
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
--     Filter by @department_ids matches against any value in
--     u.department_id (handles both single "2" and CSV "1,3,5")
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
        u.department_id,
        u.role_id,       r.name AS role_name,       r.description AS role_description,
        d.name AS department_name, d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = TRY_CAST(u.department_id AS INT)
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
        OR EXISTS (
            SELECT 1
            FROM   STRING_SPLIT(u.department_id, ',')  AS ud
            INNER  JOIN STRING_SPLIT(@department_ids, ',') AS fd
                   ON TRIM(ud.value) = TRIM(fd.value)
            WHERE  LEN(TRIM(ud.value)) > 0
        )
    )
    ORDER  BY u.id
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO

PRINT 'Migration department_id_as_csv completed successfully.';
GO
