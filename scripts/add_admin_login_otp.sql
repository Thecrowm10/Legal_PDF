-- ============================================================
-- Admin login via mobile OTP
--
-- Creates admin_login_otps table and supporting stored procedures.
-- Only users with role admin / super_admin may use this flow.
-- ============================================================

USE Legal_PDF;
GO

-- ─────────────────────────────────────────────
-- 1. Table
-- ─────────────────────────────────────────────

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'admin_login_otps')
CREATE TABLE dbo.admin_login_otps (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    user_id     INT          NOT NULL REFERENCES dbo.users(id),
    otp_hash    NVARCHAR(64) NOT NULL,
    expires_at  DATETIME2    NOT NULL,
    is_used     BIT          NOT NULL DEFAULT 0,
    created_at  DATETIME2    NOT NULL DEFAULT GETUTCDATE()
);
GO

-- ─────────────────────────────────────────────
-- 2. sp_create_admin_login_otp
--    Invalidates any existing pending OTP for
--    the user before inserting the new one.
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_create_admin_login_otp
    @user_id    INT,
    @otp_hash   NVARCHAR(64),
    @expires_at DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.admin_login_otps
    SET    is_used = 1
    WHERE  user_id = @user_id AND is_used = 0;

    INSERT INTO dbo.admin_login_otps (user_id, otp_hash, expires_at)
    VALUES (@user_id, @otp_hash, @expires_at);
END;
GO

-- ─────────────────────────────────────────────
-- 3. sp_get_valid_admin_login_otp
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_valid_admin_login_otp
    @user_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP 1 id, otp_hash, expires_at
    FROM   dbo.admin_login_otps
    WHERE  user_id   = @user_id
      AND  is_used   = 0
      AND  expires_at > GETUTCDATE()
    ORDER  BY created_at DESC;
END;
GO

-- ─────────────────────────────────────────────
-- 4. sp_mark_admin_login_otp_used
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_mark_admin_login_otp_used
    @otp_id INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.admin_login_otps
    SET    is_used = 1
    WHERE  id = @otp_id;
END;
GO

PRINT 'Migration add_admin_login_otp completed successfully.';
GO
