-- ============================================================
-- Ensures sp_list_users excludes super Admin role users
-- and the currently logged-in user (@exclude_user_id).
--
-- Safe to run on any schema version — uses TRY_CAST so it
-- works whether department_id is INT or NVARCHAR.
--
-- Run via sqlcmd:
--   sqlcmd -S <server> -U sa -P <password> -i scripts\fix_sp_list_users_exclusions.sql
-- ============================================================

USE Legal_PDF;
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
        u.role_id,       r.name AS role_name,       r.description AS role_description,
        d.name AS department_name, d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
    FROM  dbo.users u
    LEFT  JOIN dbo.roles       r  ON r.id  = u.role_id
    LEFT  JOIN dbo.departments d  ON d.id  = TRY_CAST(u.department_id AS INT)
    LEFT  JOIN (
        SELECT user_id, MAX(logged_at) AS last_login
        FROM   dbo.user_login_logs
        WHERE  action = 'login'
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

PRINT 'sp_list_users updated — super Admin and current user now excluded.';
GO
