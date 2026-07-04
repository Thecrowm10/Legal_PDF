-- Add @dept_ids filter to sp_list_audit_logs so nodal officers can scope
-- audit logs to users belonging to their designated departments.
-- Pass @dept_ids as a comma-separated string of department IDs, e.g. '1,3,7'.
-- NULL (default) means no department scoping — returns all entries (admin).
USE Legal_PDF;
GO

IF OBJECT_ID('dbo.sp_list_audit_logs', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_list_audit_logs;
GO

CREATE PROCEDURE dbo.sp_list_audit_logs
    @skip                INT            = 0,
    @limit               INT            = 20,
    @user_id             INT            = NULL,
    @action              NVARCHAR(100)  = NULL,
    @entity_type         NVARCHAR(50)   = NULL,
    @from_date           DATETIME       = NULL,
    @to_date             DATETIME       = NULL,
    @exclude_user_id     INT            = NULL,
    @exclude_null_actor  BIT            = 1,
    @exclude_auth_events BIT            = 1,
    @dept_ids            NVARCHAR(MAX)  = NULL   -- comma-separated dept IDs, e.g. '1,3,7'
AS
BEGIN
    SET NOCOUNT ON;

    WITH filtered AS (
        SELECT
            al.id,
            al.user_id,
            u.username    AS actor_username,
            u.first_name  AS actor_first_name,
            u.last_name   AS actor_last_name,
            al.action,
            al.entity_type,
            al.entity_id,
            al.details,
            al.ip_address,
            al.status,
            al.created_at,
            COUNT(*) OVER () AS total
        FROM audit_logs al
        LEFT JOIN users u ON al.user_id = u.id
        WHERE
            (@user_id IS NULL        OR al.user_id     =  @user_id)
            AND (@exclude_user_id IS NULL OR al.user_id != @exclude_user_id)
            AND (@action IS NULL      OR al.action      =  @action)
            AND (@entity_type IS NULL OR al.entity_type =  @entity_type)
            AND (@from_date IS NULL   OR al.created_at  >= @from_date)
            AND (@to_date IS NULL     OR al.created_at  <= @to_date)
            AND (@exclude_null_actor  = 0 OR al.user_id IS NOT NULL)
            AND (@exclude_auth_events = 0 OR al.entity_type <> 'auth')
            -- Department scoping: match users whose department_id is in the supplied list
            AND (
                @dept_ids IS NULL
                OR al.user_id IN (
                    SELECT u2.id
                    FROM dbo.users u2
                    WHERE CHARINDEX(
                        ',' + LTRIM(RTRIM(CAST(u2.department_id AS NVARCHAR(500)))) + ',',
                        ',' + @dept_ids + ','
                    ) > 0
                )
            )
    )
    SELECT *
    FROM filtered
    ORDER BY created_at DESC
    OFFSET @skip ROWS
    FETCH NEXT @limit ROWS ONLY;
END
GO

PRINT 'sp_list_audit_logs updated with @dept_ids department-scoping filter.';
GO
