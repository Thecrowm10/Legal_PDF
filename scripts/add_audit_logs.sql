-- ============================================================
-- Audit Logging
--
-- Tracks all significant user actions across the system:
-- authentication, document management, user management.
-- ============================================================

USE Legal_PDF;
GO

-- ─────────────────────────────────────────────
-- 1. Table
-- ─────────────────────────────────────────────

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'audit_logs')
CREATE TABLE dbo.audit_logs (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    user_id     INT          NULL REFERENCES dbo.users(id) ON DELETE SET NULL,
    action      NVARCHAR(50) NOT NULL,    -- e.g. login, pdf_created, user_updated
    entity_type NVARCHAR(50) NOT NULL,    -- auth | user | pdf
    entity_id   INT          NULL,        -- FK to the affected record (pdf_id, user_id, etc.)
    details     NVARCHAR(MAX) NULL,       -- JSON payload with action-specific context
    ip_address  NVARCHAR(45) NULL,        -- IPv4 or IPv6
    status      NVARCHAR(10) NOT NULL DEFAULT 'success',  -- success | failure
    created_at  DATETIME2    NOT NULL DEFAULT GETUTCDATE()
);
GO

-- ─────────────────────────────────────────────
-- 2. Indexes for common query patterns
-- ─────────────────────────────────────────────

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_audit_logs_user_id' AND object_id = OBJECT_ID('dbo.audit_logs'))
    CREATE INDEX IX_audit_logs_user_id ON dbo.audit_logs(user_id, created_at DESC);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_audit_logs_action' AND object_id = OBJECT_ID('dbo.audit_logs'))
    CREATE INDEX IX_audit_logs_action  ON dbo.audit_logs(action, created_at DESC);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_audit_logs_entity' AND object_id = OBJECT_ID('dbo.audit_logs'))
    CREATE INDEX IX_audit_logs_entity  ON dbo.audit_logs(entity_type, entity_id, created_at DESC);
GO

-- ─────────────────────────────────────────────
-- 3. sp_create_audit_log
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_create_audit_log
    @user_id     INT          = NULL,
    @action      NVARCHAR(50),
    @entity_type NVARCHAR(50),
    @entity_id   INT          = NULL,
    @details     NVARCHAR(MAX) = NULL,
    @ip_address  NVARCHAR(45) = NULL,
    @status      NVARCHAR(10) = 'success'
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.audit_logs (user_id, action, entity_type, entity_id, details, ip_address, status)
    VALUES (@user_id, @action, @entity_type, @entity_id, @details, @ip_address, @status);
END;
GO

-- ─────────────────────────────────────────────
-- 4. sp_list_audit_logs
--    Returns paginated rows with actor username.
--    COUNT(*) OVER() provides total without a
--    second round-trip.
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_list_audit_logs
    @skip        INT          = 0,
    @limit       INT          = 20,
    @user_id     INT          = NULL,
    @action      NVARCHAR(50) = NULL,
    @entity_type NVARCHAR(50) = NULL,
    @from_date   DATETIME2    = NULL,
    @to_date     DATETIME2    = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        COUNT(*) OVER ()   AS total,
        al.id,
        al.user_id,
        u.username         AS actor_username,
        u.first_name       AS actor_first_name,
        u.last_name        AS actor_last_name,
        al.action,
        al.entity_type,
        al.entity_id,
        al.details,
        al.ip_address,
        al.status,
        al.created_at
    FROM  dbo.audit_logs al
    LEFT  JOIN dbo.users u ON u.id = al.user_id
    WHERE (@user_id     IS NULL OR al.user_id     = @user_id)
    AND   (@action      IS NULL OR al.action      = @action)
    AND   (@entity_type IS NULL OR al.entity_type = @entity_type)
    AND   (@from_date   IS NULL OR al.created_at  >= @from_date)
    AND   (@to_date     IS NULL OR al.created_at  <= @to_date)
    ORDER  BY al.created_at DESC
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO

PRINT 'Migration add_audit_logs completed successfully.';
GO
