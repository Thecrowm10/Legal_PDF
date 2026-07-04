-- Adds link-level reviewer name, reviewed_at, and annotations_json to the
-- sp_get_linked_documents_for_department result set so the uploader's
-- DocViewModal can display who approved/rejected the link, any remarks,
-- and any highlight annotations the approver added during link review.
USE Legal_PDF;
GO

CREATE OR ALTER PROCEDURE dbo.sp_get_linked_documents_for_department
    @department_id INT,
    @status        NVARCHAR(20) = NULL   -- NULL returns all statuses
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.id,
        p.filename,
        p.original_filename,
        p.file_path,
        p.file_size,
        p.status,
        p.document_name,
        p.reference_number,
        p.issue_date,
        p.effective_from,
        p.gazette_reference,
        p.legal_authority,
        p.short_title,
        p.valid_until,
        p.sector_domain,
        p.implementing_agency,
        p.next_review_date,
        p.rule_making_authority,
        p.version_no,
        p.department_id,
        p.document_type_id,
        p.description,
        p.summary,
        p.uploaded_by,
        p.created_at,
        d.name   AS department_name,
        dt.name  AS document_type_name,
        u.username    AS uploader_username,
        u.first_name  AS uploader_first_name,
        u.last_name   AS uploader_last_name,
        l.id          AS link_id,
        l.status      AS link_status,
        l.review_comments,
        l.reviewed_at,
        l.annotations_json AS link_annotations_json,
        rv.username   AS link_reviewed_by_username,
        rv.first_name AS link_reviewed_by_first_name,
        rv.last_name  AS link_reviewed_by_last_name,
        -- Tags
        STUFF((
            SELECT ',' + CAST(t.id AS NVARCHAR) + ':' + t.name
            FROM dbo.pdf_document_tags pdt
            JOIN dbo.tags t ON t.id = pdt.tag_id
            WHERE pdt.pdf_id = p.id
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)'), 1, 1, '') AS tags,
        -- Latest approval of the original document
        (
            SELECT TOP 1
                a.action, a.comments, a.annotations_json, a.acted_at,
                au.username AS approver_username,
                au.first_name AS approver_first_name,
                au.last_name AS approver_last_name
            FROM dbo.pdf_document_approvals a
            JOIN dbo.users au ON au.id = a.approver_id
            WHERE a.pdf_id = p.id
            ORDER BY a.acted_at DESC
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS latest_approval,
        NULL AS relationships,
        COUNT(*) OVER() AS total_count
    FROM dbo.pdf_document_department_links l
    JOIN dbo.pdf_documents  p  ON p.id = l.pdf_id
    LEFT JOIN dbo.departments d  ON d.id = p.department_id
    JOIN dbo.document_types dt   ON dt.id = p.document_type_id
    LEFT JOIN dbo.users      u   ON u.id = p.uploaded_by
    LEFT JOIN dbo.users      rv  ON rv.id = l.reviewed_by
    WHERE l.department_id = @department_id
      AND (@status IS NULL OR l.status = @status)
    ORDER BY l.created_at DESC;
END;
GO

PRINT 'sp_get_linked_documents_for_department updated with link reviewer fields.';
GO
