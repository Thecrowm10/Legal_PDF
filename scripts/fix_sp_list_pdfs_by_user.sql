-- ============================================================
-- Fixes sp_list_pdfs_by_user to include:
--   - d.status       (was stripped by update_sp_list_pdfs_by_user_count.sql)
--   - latest_approval JSON (approver name, action, comments, acted_at)
--   - total_count    (window function, preserved from earlier script)
--
-- Run via sqlcmd:
--   sqlcmd -S 10.0.160.80 -U sa -P sa@123 -i scripts\fix_sp_list_pdfs_by_user.sql
-- ============================================================

USE Legal_PDF;
GO

CREATE OR ALTER PROCEDURE dbo.sp_list_pdfs_by_user
    @user_id INT,
    @skip    INT = 0,
    @limit   INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        COUNT(*) OVER()           AS total_count,
        d.id, d.filename, d.original_filename, d.file_path, d.file_size,
        d.status,
        d.document_name, d.reference_number, d.issue_date, d.effective_from,
        d.gazette_reference, d.legal_authority, d.short_title, d.valid_until,
        d.sector_domain, d.implementing_agency, d.next_review_date, d.rule_making_authority,
        d.version_no, d.uploaded_by, d.description, d.created_at,
        d.department_id,    dep.name AS department_name,
        d.document_type_id, dt.name  AS document_type_name,
        (
            SELECT STRING_AGG(CAST(t.id AS NVARCHAR(10)) + ':' + t.name, ',')
            FROM   dbo.pdf_document_tags pdt
            JOIN   dbo.tags t ON t.id = pdt.tag_id
            WHERE  pdt.pdf_id = d.id
        ) AS tags,
        (
            SELECT r.target_pdf_id AS pdf_id,
                   pd.document_name,
                   r.relationship_type AS [type]
            FROM   dbo.pdf_document_relationships r
            JOIN   dbo.pdf_documents pd ON pd.id = r.target_pdf_id
            WHERE  r.source_pdf_id = d.id
            FOR JSON PATH
        ) AS relationships,
        (
            SELECT TOP 1
                   a.action, a.comments, a.acted_at,
                   u.username    AS approver_username,
                   u.first_name  AS approver_first_name,
                   u.last_name   AS approver_last_name
            FROM   dbo.pdf_document_approvals a
            JOIN   dbo.users u ON u.id = a.approver_id
            WHERE  a.pdf_id = d.id
            ORDER  BY a.acted_at DESC
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS latest_approval
    FROM  dbo.pdf_documents d
    LEFT  JOIN dbo.departments    dep ON dep.id = d.department_id
    LEFT  JOIN dbo.document_types dt  ON dt.id  = d.document_type_id
    WHERE d.uploaded_by = @user_id
    ORDER BY d.created_at DESC
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO

PRINT 'fix_sp_list_pdfs_by_user completed — status + latest_approval + total_count all present.';
GO
