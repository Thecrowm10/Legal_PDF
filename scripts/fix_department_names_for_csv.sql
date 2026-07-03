-- ============================================================
-- Fix department_name to return pipe-separated names for all
-- departments in department_id (supports single "2" and CSV "1,3").
--
-- Uses STRING_AGG so every user SP returns the full list.
--
-- Run via sqlcmd:
--   sqlcmd -S <server> -U sa -P <password> -i scripts\fix_department_names_for_csv.sql
-- ============================================================

USE Legal_PDF;
GO

-- ─────────────────────────────────────────────
-- Helper macro (inline in each SP — SQL Server
-- does not support reusable scalar subqueries
-- across stored procedures easily).
--
-- department_name  : pipe-separated names in CSV order
-- department_description : description of the first dept
-- ─────────────────────────────────────────────

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
        u.role_id, r.name AS role_name, r.description AS role_description,
        (SELECT STRING_AGG(d2.name, '|') WITHIN GROUP (ORDER BY TRY_CAST(TRIM(s.value) AS INT))
         FROM   STRING_SPLIT(ISNULL(u.department_id, ''), ',') s
         INNER  JOIN dbo.departments d2 ON d2.id = TRY_CAST(TRIM(s.value) AS INT)
         WHERE  LEN(TRIM(s.value)) > 0) AS department_name,
        (SELECT TOP 1 d2.description
         FROM   STRING_SPLIT(ISNULL(u.department_id, ''), ',') s
         INNER  JOIN dbo.departments d2 ON d2.id = TRY_CAST(TRIM(s.value) AS INT)
         WHERE  LEN(TRIM(s.value)) > 0
         ORDER  BY TRY_CAST(TRIM(s.value) AS INT)) AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles r ON r.id = u.role_id
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.id = @user_id;
END;
GO

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
        u.role_id, r.name AS role_name, r.description AS role_description,
        (SELECT STRING_AGG(d2.name, '|') WITHIN GROUP (ORDER BY TRY_CAST(TRIM(s.value) AS INT))
         FROM   STRING_SPLIT(ISNULL(u.department_id, ''), ',') s
         INNER  JOIN dbo.departments d2 ON d2.id = TRY_CAST(TRIM(s.value) AS INT)
         WHERE  LEN(TRIM(s.value)) > 0) AS department_name,
        (SELECT TOP 1 d2.description
         FROM   STRING_SPLIT(ISNULL(u.department_id, ''), ',') s
         INNER  JOIN dbo.departments d2 ON d2.id = TRY_CAST(TRIM(s.value) AS INT)
         WHERE  LEN(TRIM(s.value)) > 0
         ORDER  BY TRY_CAST(TRIM(s.value) AS INT)) AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles r ON r.id = u.role_id
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.username = @username;
END;
GO

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
        u.role_id, r.name AS role_name, r.description AS role_description,
        (SELECT STRING_AGG(d2.name, '|') WITHIN GROUP (ORDER BY TRY_CAST(TRIM(s.value) AS INT))
         FROM   STRING_SPLIT(ISNULL(u.department_id, ''), ',') s
         INNER  JOIN dbo.departments d2 ON d2.id = TRY_CAST(TRIM(s.value) AS INT)
         WHERE  LEN(TRIM(s.value)) > 0) AS department_name,
        (SELECT TOP 1 d2.description
         FROM   STRING_SPLIT(ISNULL(u.department_id, ''), ',') s
         INNER  JOIN dbo.departments d2 ON d2.id = TRY_CAST(TRIM(s.value) AS INT)
         WHERE  LEN(TRIM(s.value)) > 0
         ORDER  BY TRY_CAST(TRIM(s.value) AS INT)) AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles r ON r.id = u.role_id
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.email = @email;
END;
GO

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
        u.role_id, r.name AS role_name, r.description AS role_description,
        (SELECT STRING_AGG(d2.name, '|') WITHIN GROUP (ORDER BY TRY_CAST(TRIM(s.value) AS INT))
         FROM   STRING_SPLIT(ISNULL(u.department_id, ''), ',') s
         INNER  JOIN dbo.departments d2 ON d2.id = TRY_CAST(TRIM(s.value) AS INT)
         WHERE  LEN(TRIM(s.value)) > 0) AS department_name,
        (SELECT TOP 1 d2.description
         FROM   STRING_SPLIT(ISNULL(u.department_id, ''), ',') s
         INNER  JOIN dbo.departments d2 ON d2.id = TRY_CAST(TRIM(s.value) AS INT)
         WHERE  LEN(TRIM(s.value)) > 0
         ORDER  BY TRY_CAST(TRIM(s.value) AS INT)) AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles r ON r.id = u.role_id
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs WHERE action = 'login'
        GROUP  BY user_id
    ) ll ON ll.user_id = u.id
    WHERE u.mobile_number = @mobile_number;
END;
GO

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
        u.role_id, r.name AS role_name, r.description AS role_description,
        (SELECT STRING_AGG(d2.name, '|') WITHIN GROUP (ORDER BY TRY_CAST(TRIM(s.value) AS INT))
         FROM   STRING_SPLIT(ISNULL(u.department_id, ''), ',') s
         INNER  JOIN dbo.departments d2 ON d2.id = TRY_CAST(TRIM(s.value) AS INT)
         WHERE  LEN(TRIM(s.value)) > 0) AS department_name,
        (SELECT TOP 1 d2.description
         FROM   STRING_SPLIT(ISNULL(u.department_id, ''), ',') s
         INNER  JOIN dbo.departments d2 ON d2.id = TRY_CAST(TRIM(s.value) AS INT)
         WHERE  LEN(TRIM(s.value)) > 0
         ORDER  BY TRY_CAST(TRIM(s.value) AS INT)) AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles r ON r.id = u.role_id
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
            FROM   STRING_SPLIT(CAST(u.department_id AS NVARCHAR(MAX)), ',') AS ud
            INNER  JOIN STRING_SPLIT(@department_ids, ',') AS fd
                   ON TRIM(ud.value) = TRIM(fd.value)
            WHERE  LEN(TRIM(ud.value)) > 0
        )
    )
    ORDER  BY u.id
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO

PRINT 'All user SPs updated — department_name now returns pipe-separated names for CSV department_id.';
GO
