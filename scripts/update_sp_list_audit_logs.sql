-- Update sp_list_audit_logs:
--   @exclude_user_id  : exclude the calling admin's own entries
--   @exclude_null_actor (default 1): hide entries with no identified user (deleted/anonymous)
--   @exclude_auth_events (default 1): hide OTP/login noise (entity_type = 'auth')
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
    @exclude_auth_events BIT            = 1
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
            -- caller-supplied filters
            (@user_id IS NULL        OR al.user_id     =  @user_id)
            AND (@exclude_user_id IS NULL OR al.user_id != @exclude_user_id)
            AND (@action IS NULL      OR al.action      =  @action)
            AND (@entity_type IS NULL OR al.entity_type =  @entity_type)
            AND (@from_date IS NULL   OR al.created_at  >= @from_date)
            AND (@to_date IS NULL     OR al.created_at  <= @to_date)
            -- exclude anonymous / deleted-user entries
            AND (@exclude_null_actor  = 0 OR al.user_id IS NOT NULL)
            -- exclude auth noise: login, OTP, session events
            AND (@exclude_auth_events = 0 OR al.entity_type <> 'auth')
    )
    SELECT *
    FROM filtered
    ORDER BY created_at DESC
    OFFSET @skip ROWS
    FETCH NEXT @limit ROWS ONLY;
END
GO
