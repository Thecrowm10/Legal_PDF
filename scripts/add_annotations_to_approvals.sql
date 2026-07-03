-- ============================================================
-- Adds annotations_json column to pdf_document_approvals and
-- updates all PDF-returning SPs to include it in latest_approval.
--
-- Run via sqlcmd:
--   sqlcmd -S 10.0.160.80 -U sa -P sa@123 -i scripts\add_annotations_to_approvals.sql
-- ============================================================

USE Legal_PDF;
GO

-- ─────────────────────────────────────────────
-- 1. Add annotations_json column
-- ─────────────────────────────────────────────

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID('dbo.pdf_document_approvals')
      AND name = 'annotations_json'
)
    ALTER TABLE dbo.pdf_document_approvals
        ADD annotations_json NVARCHAR(MAX) NULL;
GO

-- ─────────────────────────────────────────────
-- 2. sp_review_pdf_document  (adds @annotations_json param)
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_review_pdf_document
    @pdf_id           INT,
    @approver_id      INT,
    @action           NVARCHAR(20),
    @comments         NVARCHAR(MAX) = NULL,
    @annotations_json NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @action NOT IN ('approved', 'rejected')
    BEGIN
        RAISERROR('action must be ''approved'' or ''rejected''.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.pdf_documents
    SET    status = @action
    WHERE  id = @pdf_id;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('PDF document not found.', 16, 1);
        RETURN;
    END;

    INSERT INTO dbo.pdf_document_approvals (pdf_id, approver_id, action, comments, annotations_json)
    VALUES (@pdf_id, @approver_id, @action, @comments, @annotations_json);

    SELECT
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
            SELECT TOP 1 a.action, a.comments, a.annotations_json, a.acted_at,
                         u.username AS approver_username,
                         u.first_name AS approver_first_name,
                         u.last_name  AS approver_last_name
            FROM   dbo.pdf_document_approvals a
            JOIN   dbo.users u ON u.id = a.approver_id
            WHERE  a.pdf_id = d.id
            ORDER  BY a.acted_at DESC
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS latest_approval
    FROM  dbo.pdf_documents d
    LEFT  JOIN dbo.departments    dep ON dep.id = d.department_id
    LEFT  JOIN dbo.document_types dt  ON dt.id  = d.document_type_id
    WHERE d.id = @pdf_id;
END;
GO

-- ─────────────────────────────────────────────
-- 3. sp_get_pdf_by_id  (adds annotations_json to latest_approval)
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_pdf_by_id
    @document_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
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
            SELECT TOP 1 a.action, a.comments, a.annotations_json, a.acted_at,
                         u.username AS approver_username,
                         u.first_name AS approver_first_name,
                         u.last_name  AS approver_last_name
            FROM   dbo.pdf_document_approvals a
            JOIN   dbo.users u ON u.id = a.approver_id
            WHERE  a.pdf_id = d.id
            ORDER  BY a.acted_at DESC
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS latest_approval
    FROM  dbo.pdf_documents d
    LEFT  JOIN dbo.departments    dep ON dep.id = d.department_id
    LEFT  JOIN dbo.document_types dt  ON dt.id  = d.document_type_id
    WHERE d.id = @document_id;
END;
GO

-- ─────────────────────────────────────────────
-- 4. sp_list_pdfs_by_user  (adds annotations_json to latest_approval)
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_list_pdfs_by_user
    @user_id INT,
    @skip    INT = 0,
    @limit   INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        COUNT(*) OVER() AS total_count,
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
            SELECT TOP 1 a.action, a.comments, a.annotations_json, a.acted_at,
                         u.username AS approver_username,
                         u.first_name AS approver_first_name,
                         u.last_name  AS approver_last_name
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

-- ─────────────────────────────────────────────
-- 5. sp_list_all_pdfs  (adds annotations_json to latest_approval)
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_list_all_pdfs
    @skip   INT = 0,
    @limit  INT = 100,
    @status NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        COUNT(*) OVER() AS total_count,
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
            SELECT TOP 1 a.action, a.comments, a.annotations_json, a.acted_at,
                         u.username AS approver_username,
                         u.first_name AS approver_first_name,
                         u.last_name  AS approver_last_name
            FROM   dbo.pdf_document_approvals a
            JOIN   dbo.users u ON u.id = a.approver_id
            WHERE  a.pdf_id = d.id
            ORDER  BY a.acted_at DESC
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS latest_approval
    FROM  dbo.pdf_documents d
    LEFT  JOIN dbo.departments    dep ON dep.id = d.department_id
    LEFT  JOIN dbo.document_types dt  ON dt.id  = d.document_type_id
    WHERE (@status IS NULL OR d.status = @status)
    ORDER BY d.created_at DESC
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO
