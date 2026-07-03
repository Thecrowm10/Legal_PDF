-- ============================================================
-- Fix department display for nodal officers (CSV department_id)
--
-- All user SPs now use OUTER APPLY + STRING_AGG to resolve
-- department names for both single-dept and CSV-dept users.
-- department_name is returned as pipe-separated names so Python
-- can split them back into individual Department objects.
-- e.g. department_id='1,2' → department_name='Dept A|Dept B'
-- ============================================================

USE Legal_PDF;
GO

-- ─────────────────────────────────────────────────────────────
-- 1. sp_create_user
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
        COALESCE(d.name, csv_depts.pipe_names)          AS department_name,
        COALESCE(d.description, N'')                    AS department_description,
        u.created_at, u.updated_at,
        NULL AS last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r ON r.id = u.role_id
    LEFT  JOIN dbo.departments d ON d.id = TRY_CAST(u.department_id AS INT)
    OUTER APPLY (
        SELECT STRING_AGG(d2.name, '|') WITHIN GROUP (ORDER BY d2.id) AS pipe_names
        FROM   STRING_SPLIT(u.department_id, ',') s
        JOIN   dbo.departments d2 ON d2.id = TRY_CAST(TRIM(s.value) AS INT)
        WHERE  LEN(TRIM(s.value)) > 0
    ) csv_depts
    WHERE u.id = @new_id;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 2. sp_update_user
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
        COALESCE(d.name, csv_depts.pipe_names)          AS department_name,
        COALESCE(d.description, N'')                    AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = TRY_CAST(u.department_id AS INT)
    OUTER APPLY (
        SELECT STRING_AGG(d2.name, '|') WITHIN GROUP (ORDER BY d2.id) AS pipe_names
        FROM   STRING_SPLIT(u.department_id, ',') s
        JOIN   dbo.departments d2 ON d2.id = TRY_CAST(TRIM(s.value) AS INT)
        WHERE  LEN(TRIM(s.value)) > 0
    ) csv_depts
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.id = @user_id;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 3. sp_get_user_by_id
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
        COALESCE(d.name, csv_depts.pipe_names)          AS department_name,
        COALESCE(d.description, N'')                    AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = TRY_CAST(u.department_id AS INT)
    OUTER APPLY (
        SELECT STRING_AGG(d2.name, '|') WITHIN GROUP (ORDER BY d2.id) AS pipe_names
        FROM   STRING_SPLIT(u.department_id, ',') s
        JOIN   dbo.departments d2 ON d2.id = TRY_CAST(TRIM(s.value) AS INT)
        WHERE  LEN(TRIM(s.value)) > 0
    ) csv_depts
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.id = @user_id;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 4. sp_get_user_by_username
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
        COALESCE(d.name, csv_depts.pipe_names)          AS department_name,
        COALESCE(d.description, N'')                    AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = TRY_CAST(u.department_id AS INT)
    OUTER APPLY (
        SELECT STRING_AGG(d2.name, '|') WITHIN GROUP (ORDER BY d2.id) AS pipe_names
        FROM   STRING_SPLIT(u.department_id, ',') s
        JOIN   dbo.departments d2 ON d2.id = TRY_CAST(TRIM(s.value) AS INT)
        WHERE  LEN(TRIM(s.value)) > 0
    ) csv_depts
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.username = @username;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 5. sp_get_user_by_email
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
        COALESCE(d.name, csv_depts.pipe_names)          AS department_name,
        COALESCE(d.description, N'')                    AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = TRY_CAST(u.department_id AS INT)
    OUTER APPLY (
        SELECT STRING_AGG(d2.name, '|') WITHIN GROUP (ORDER BY d2.id) AS pipe_names
        FROM   STRING_SPLIT(u.department_id, ',') s
        JOIN   dbo.departments d2 ON d2.id = TRY_CAST(TRIM(s.value) AS INT)
        WHERE  LEN(TRIM(s.value)) > 0
    ) csv_depts
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.email = @email;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 6. sp_get_user_by_mobile
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
        COALESCE(d.name, csv_depts.pipe_names)          AS department_name,
        COALESCE(d.description, N'')                    AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = TRY_CAST(u.department_id AS INT)
    OUTER APPLY (
        SELECT STRING_AGG(d2.name, '|') WITHIN GROUP (ORDER BY d2.id) AS pipe_names
        FROM   STRING_SPLIT(u.department_id, ',') s
        JOIN   dbo.departments d2 ON d2.id = TRY_CAST(TRIM(s.value) AS INT)
        WHERE  LEN(TRIM(s.value)) > 0
    ) csv_depts
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.mobile_number = @mobile_number;
END;
GO

-- ─────────────────────────────────────────────────────────────
-- 7. sp_list_users
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
        COALESCE(d.name, csv_depts.pipe_names)          AS department_name,
        COALESCE(d.description, N'')                    AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = TRY_CAST(u.department_id AS INT)
    OUTER APPLY (
        SELECT STRING_AGG(d2.name, '|') WITHIN GROUP (ORDER BY d2.id) AS pipe_names
        FROM   STRING_SPLIT(u.department_id, ',') s
        JOIN   dbo.departments d2 ON d2.id = TRY_CAST(TRIM(s.value) AS INT)
        WHERE  LEN(TRIM(s.value)) > 0
    ) csv_depts
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.roles r2
        WHERE  r2.id = u.role_id AND r2.name = 'super Admin'
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

PRINT 'fix_dept_display completed — all user SPs updated with OUTER APPLY for CSV department names.';
GO
