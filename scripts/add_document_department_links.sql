-- ─────────────────────────────────────────────────────────────────────────────
-- Cross-department document linking
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Linking table
IF OBJECT_ID('dbo.pdf_document_department_links', 'U') IS NULL
CREATE TABLE dbo.pdf_document_department_links
(
    id            INT          IDENTITY(1,1) NOT NULL,
    pdf_id        INT          NOT NULL,
    department_id INT          NOT NULL,
    linked_by     INT          NOT NULL,
    status        NVARCHAR(20) NOT NULL CONSTRAINT DF_link_status DEFAULT 'pending',
    reviewed_by   INT          NULL,
    reviewed_at   DATETIME2    NULL,
    created_at    DATETIME2    NOT NULL CONSTRAINT DF_link_created_at DEFAULT GETDATE(),
    CONSTRAINT PK_pdf_dept_links  PRIMARY KEY (id),
    CONSTRAINT UQ_pdf_dept_link   UNIQUE (pdf_id, department_id),
    CONSTRAINT FK_link_pdf        FOREIGN KEY (pdf_id)
        REFERENCES dbo.pdf_documents(id) ON DELETE CASCADE,
    CONSTRAINT FK_link_department FOREIGN KEY (department_id)
        REFERENCES dbo.departments(id),
    CONSTRAINT FK_link_linked_by  FOREIGN KEY (linked_by)
        REFERENCES dbo.users(id),
    CONSTRAINT FK_link_reviewed_by FOREIGN KEY (reviewed_by)
        REFERENCES dbo.users(id),
    CONSTRAINT CK_link_status     CHECK (status IN ('pending', 'approved', 'rejected'))
);
GO

-- 2. Check for duplicate documents across departments
--    Returns rows from all departments matching the given name + type.
--    match_type = 'own_dept'   → same department as caller (version-upgrade scenario)
--    match_type = 'other_dept' → a different department (link scenario)
--    Excludes: docs from depts that already have an approved/pending link,
--              rejected documents.
CREATE OR ALTER PROCEDURE dbo.sp_check_duplicate_document
    @document_name    NVARCHAR(500),
    @document_type_id INT,
    @caller_dept_id   INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 5
        p.id,
        p.document_name,
        p.version_no,
        p.status,
        p.created_at,
        p.department_id,
        dt.name  AS document_type_name,
        d.name   AS department_name,
        u.username AS uploader_username,
        CASE
            WHEN p.department_id = @caller_dept_id THEN 'own_dept'
            ELSE 'other_dept'
        END AS match_type
    FROM dbo.pdf_documents p
    JOIN dbo.document_types dt ON dt.id = p.document_type_id
    LEFT JOIN dbo.departments d  ON d.id = p.department_id
    LEFT JOIN dbo.users       u  ON u.id = p.uploaded_by
    WHERE
        p.document_name     = @document_name
        AND p.document_type_id = @document_type_id
        AND p.status        <> 'rejected'
        -- For other-dept rows: exclude those already linked to caller's dept
        AND NOT (
            p.department_id <> @caller_dept_id
            AND EXISTS (
                SELECT 1
                FROM dbo.pdf_document_department_links l
                WHERE l.pdf_id = p.id
                  AND l.department_id = @caller_dept_id
                  AND l.status IN ('pending', 'approved')
            )
        )
    ORDER BY
        -- own_dept first, then by newest
        CASE WHEN p.department_id = @caller_dept_id THEN 0 ELSE 1 END,
        p.created_at DESC;
END;
GO

-- 3. Create a pending link from a document to a department
CREATE OR ALTER PROCEDURE dbo.sp_link_document_to_department
    @pdf_id       INT,
    @department_id INT,
    @linked_by    INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.pdf_document_department_links
        WHERE pdf_id = @pdf_id AND department_id = @department_id
    )
    BEGIN
        INSERT INTO dbo.pdf_document_department_links (pdf_id, department_id, linked_by)
        VALUES (@pdf_id, @department_id, @linked_by);
    END

    SELECT
        l.id,
        l.pdf_id,
        l.department_id,
        l.linked_by,
        l.status,
        l.created_at
    FROM dbo.pdf_document_department_links l
    WHERE l.pdf_id = @pdf_id AND l.department_id = @department_id;
END;
GO

-- 4. List pending link requests for a department's approver
CREATE OR ALTER PROCEDURE dbo.sp_get_pending_department_links
    @department_id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        l.id          AS link_id,
        l.pdf_id,
        l.status      AS link_status,
        l.created_at  AS requested_at,
        p.document_name,
        p.version_no,
        p.status      AS document_status,
        dt.name       AS document_type_name,
        orig_d.name   AS original_department_name,
        lu.username   AS requested_by_username,
        lu.first_name AS requested_by_first_name,
        lu.last_name  AS requested_by_last_name
    FROM dbo.pdf_document_department_links l
    JOIN dbo.pdf_documents  p      ON p.id = l.pdf_id
    JOIN dbo.document_types dt     ON dt.id = p.document_type_id
    LEFT JOIN dbo.departments orig_d ON orig_d.id = p.department_id
    LEFT JOIN dbo.users      lu    ON lu.id = l.linked_by
    WHERE l.department_id = @department_id
      AND l.status = 'pending'
    ORDER BY l.created_at DESC;
END;
GO

-- 5. Approve or reject a link request
CREATE OR ALTER PROCEDURE dbo.sp_review_department_link
    @link_id     INT,
    @action      NVARCHAR(20),   -- 'approved' | 'rejected'
    @reviewed_by INT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dbo.pdf_document_department_links
    SET
        status      = @action,
        reviewed_by = @reviewed_by,
        reviewed_at = GETDATE()
    WHERE id = @link_id;
END;
GO

-- 6. Get all approved-linked documents for a department
--    Returns the same columns as sp_list_pdfs_by_user so the frontend
--    can reuse the same mapApiDoc function.
CREATE OR ALTER PROCEDURE dbo.sp_get_linked_documents_for_department
    @department_id INT
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
        -- Tags (same pattern as sp_list_pdfs_by_user)
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
      AND l.status = 'approved'
    ORDER BY l.created_at DESC;
END;
GO
