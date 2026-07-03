-- ============================================================
-- Adds nodal_officer role and updates sp_list_users to support
-- optional department-scoped filtering.
--
-- Hierarchy:
--   super_admin → admin → nodal_officer → approver → user
--
-- Nodal officer can manage users within their own department only.
-- Admin/super_admin manage users across all departments.
-- ============================================================

USE Legal_PDF;
GO

-- ─────────────────────────────────────────────
-- 1. Seed nodal_officer role
-- ─────────────────────────────────────────────

IF NOT EXISTS (SELECT 1 FROM dbo.roles WHERE name = 'nodal_officer')
    INSERT INTO dbo.roles (name, description)
    VALUES ('nodal_officer', 'Manages users within their own department');
GO

-- ─────────────────────────────────────────────
-- 2. sp_list_users  — add optional @department_id filter
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_list_users
    @skip            INT = 0,
    @limit           INT = 100,
    @exclude_user_id INT = NULL,
    @department_id   INT = NULL    -- NULL = all departments (admin); set for nodal_officer
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        u.id, u.username, u.email, u.hashed_password, u.is_active,
        u.first_name, u.last_name,
        u.mobile_number, u.must_change_password,
        u.role_id,       r.name  AS role_name,       r.description AS role_description,
        u.department_id, d.name  AS department_name,  d.description AS department_description,
        u.created_at, u.updated_at,
        ll.last_login
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
    AND (@department_id   IS NULL OR u.department_id = @department_id)
    ORDER  BY u.id
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO

PRINT 'Migration add_nodal_officer_role completed successfully.';
GO
