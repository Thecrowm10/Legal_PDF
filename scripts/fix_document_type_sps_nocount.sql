-- ============================================================
-- Fixes ResourceClosedError on sp_create_document_type and
-- sp_toggle_document_type_status by adding SET NOCOUNT ON.
-- Without it, the INSERT/UPDATE row-count is sent as a result
-- set before the SELECT, causing SQLAlchemy fetchone() to fail.
--
-- Run via sqlcmd:
--   sqlcmd -S <server> -U sa -P <password> -i scripts\fix_document_type_sps_nocount.sql
-- ============================================================

USE Legal_PDF;
GO

CREATE OR ALTER PROCEDURE dbo.sp_create_document_type
    @name        NVARCHAR(100),
    @description NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.document_types (name, description, is_active, created_at)
    VALUES (@name, @description, 1, GETUTCDATE());

    SELECT id, name, description, is_active, created_at
    FROM   dbo.document_types
    WHERE  id = SCOPE_IDENTITY();
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_toggle_document_type_status
    @type_id INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.document_types
    SET    is_active = CASE WHEN is_active = 1 THEN 0 ELSE 1 END
    WHERE  id = @type_id;

    SELECT id, name, description, is_active, created_at
    FROM   dbo.document_types
    WHERE  id = @type_id;
END;
GO

PRINT 'sp_create_document_type and sp_toggle_document_type_status fixed.';
GO
