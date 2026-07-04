-- Add annotations_json column to pdf_document_department_links
-- and update sp_review_department_link to store it.

USE Legal_PDF;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.pdf_document_department_links')
      AND name = 'annotations_json'
)
    ALTER TABLE dbo.pdf_document_department_links
        ADD annotations_json NVARCHAR(MAX) NULL;
GO

CREATE OR ALTER PROCEDURE dbo.sp_review_department_link
    @link_id          INT,
    @action           NVARCHAR(20),   -- 'approved' | 'rejected'
    @reviewed_by      INT,
    @review_comments  NVARCHAR(1000) = NULL,
    @annotations_json NVARCHAR(MAX)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.pdf_document_department_links
    SET
        status            = @action,
        reviewed_by       = @reviewed_by,
        reviewed_at       = GETDATE(),
        review_comments   = @review_comments,
        annotations_json  = @annotations_json
    WHERE id = @link_id;
END;
GO

PRINT 'annotations_json column and updated SP applied.';
GO
