USE Legal_PDF;
GO

-- Returns all documents that reference @act_id via any relationship type.
-- This powers the "children" / history tab of an Act, including:
--   parent_act  → Amendments that amend this Act
--   issued_under → Notifications, Circulars, Orders, etc. issued under this Act
--   notified_under, implements, amends, related, etc.
CREATE OR ALTER PROCEDURE dbo.sp_get_documents_under_act
    @act_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.id,
        p.document_name,
        p.reference_number,
        p.issue_date,
        p.status,
        p.version_no,
        p.description,
        p.summary,
        p.uploaded_by,
        p.created_at,
        dt.name  AS document_type_name,
        dep.name AS department_name,
        u.username   AS uploader_username,
        u.first_name AS uploader_first_name,
        u.last_name  AS uploader_last_name,
        r.relationship_type
    FROM  dbo.pdf_document_relationships r
    JOIN  dbo.pdf_documents  p   ON p.id   = r.source_pdf_id
    JOIN  dbo.document_types dt  ON dt.id  = p.document_type_id
    LEFT  JOIN dbo.departments  dep ON dep.id = p.department_id
    LEFT  JOIN dbo.users        u   ON u.id   = p.uploaded_by
    WHERE r.target_pdf_id = @act_id
    ORDER BY dt.name, p.issue_date DESC;
END;
GO

PRINT 'sp_get_documents_under_act created successfully.';
GO
