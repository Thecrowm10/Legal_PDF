-- Add review_comments column to pdf_document_department_links
-- and update sp_review_department_link to store it.

USE Legal_PDF;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.pdf_document_department_links')
      AND name = 'review_comments'
)
    ALTER TABLE dbo.pdf_document_department_links
        ADD review_comments NVARCHAR(1000) NULL;
GO

CREATE OR ALTER PROCEDURE dbo.sp_review_department_link
    @link_id         INT,
    @action          NVARCHAR(20),   -- 'approved' | 'rejected'
    @reviewed_by     INT,
    @review_comments NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.pdf_document_department_links
    SET
        status          = @action,
        reviewed_by     = @reviewed_by,
        reviewed_at     = GETDATE(),
        review_comments = @review_comments
    WHERE id = @link_id;
END;
GO

PRINT 'review_comments column and updated SP applied.';
GO
