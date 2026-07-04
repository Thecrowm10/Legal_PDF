-- ─────────────────────────────────────────────────────────────────────────
-- 1. Update sp_get_pending_department_links to support optional status filter
--    (NULL = all statuses, 'pending' = default behaviour preserved)
-- ─────────────────────────────────────────────────────────────────────────
USE Legal_PDF;
GO

CREATE OR ALTER PROCEDURE dbo.sp_get_department_links
    @department_id INT,
    @status        NVARCHAR(20) = 'pending'  -- NULL returns all statuses
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        l.id          AS link_id,
        l.pdf_id,
        l.status      AS link_status,
        l.created_at  AS requested_at,
        l.reviewed_at,
        l.review_comments,
        l.annotations_json,
        p.document_name,
        p.version_no,
        p.status      AS document_status,
        dt.name       AS document_type_name,
        orig_d.name   AS original_department_name,
        lu.username   AS requested_by_username,
        lu.first_name AS requested_by_first_name,
        lu.last_name  AS requested_by_last_name,
        rv.username   AS reviewed_by_username,
        rv.first_name AS reviewed_by_first_name,
        rv.last_name  AS reviewed_by_last_name
    FROM dbo.pdf_document_department_links l
    JOIN dbo.pdf_documents  p      ON p.id = l.pdf_id
    JOIN dbo.document_types dt     ON dt.id = p.document_type_id
    LEFT JOIN dbo.departments orig_d ON orig_d.id = p.department_id
    LEFT JOIN dbo.users      lu    ON lu.id = l.linked_by
    LEFT JOIN dbo.users      rv    ON rv.id = l.reviewed_by
    WHERE l.department_id = @department_id
      AND (@status IS NULL OR l.status = @status)
    ORDER BY l.created_at DESC;
END;
GO

-- ─────────────────────────────────────────────────────────────────────────
-- 2. New SP for admin / nodal officer — all department links across all depts
--    @department_id NULL = all depts; non-NULL = that specific dept only
--    @status        NULL = all statuses
-- ─────────────────────────────────────────────────────────────────────────
CREATE OR ALTER PROCEDURE dbo.sp_get_all_department_links
    @status        NVARCHAR(20) = NULL,
    @department_id INT          = NULL   -- link's target department (not the original doc dept)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        l.id            AS link_id,
        l.pdf_id,
        l.status        AS link_status,
        l.created_at    AS requested_at,
        l.reviewed_at,
        l.review_comments,
        l.annotations_json,
        p.document_name,
        p.version_no,
        p.status        AS document_status,
        dt.name         AS document_type_name,
        orig_d.name     AS original_department_name,
        tgt_d.name      AS linked_department_name,
        lu.username     AS requested_by_username,
        lu.first_name   AS requested_by_first_name,
        lu.last_name    AS requested_by_last_name,
        rv.username     AS reviewed_by_username,
        rv.first_name   AS reviewed_by_first_name,
        rv.last_name    AS reviewed_by_last_name
    FROM dbo.pdf_document_department_links l
    JOIN dbo.pdf_documents  p       ON p.id  = l.pdf_id
    JOIN dbo.document_types dt      ON dt.id = p.document_type_id
    LEFT JOIN dbo.departments orig_d ON orig_d.id = p.department_id
    LEFT JOIN dbo.departments tgt_d  ON tgt_d.id  = l.department_id
    LEFT JOIN dbo.users      lu      ON lu.id = l.linked_by
    LEFT JOIN dbo.users      rv      ON rv.id = l.reviewed_by
    WHERE (@status IS NULL OR l.status = @status)
      AND (@department_id IS NULL OR l.department_id = @department_id)
    ORDER BY l.created_at DESC;
END;
GO

-- ─────────────────────────────────────────────────────────────────────────
-- 3. Update sp_get_linked_documents_for_department to support all statuses
--    @status NULL = all (uploader sees pending/approved/rejected)
-- ─────────────────────────────────────────────────────────────────────────
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
        -- Tags
        STUFF((
            SELECT ',' + CAST(t.id AS NVARCHAR) + ':' + t.name
            FROM dbo.pdf_document_tags pdt
            JOIN dbo.tags t ON t.id = pdt.tag_id
            WHERE pdt.pdf_id = p.id
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)'), 1, 1, '') AS tags,
        -- Latest approval
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
    WHERE l.department_id = @department_id
      AND (@status IS NULL OR l.status = @status)
    ORDER BY l.created_at DESC;
END;
GO

PRINT 'All department link SPs created/updated successfully.';
GO
