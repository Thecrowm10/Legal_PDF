-- ============================================================
-- Adds Act-specific extended fields to pdf_documents and
-- updates all PDF-returning stored procedures to include them.
-- Fields: act_year, long_title, regional_title, notification_no,
--         act_code, so_reason, no_of_rules, no_of_notifications,
--         no_of_regulations, no_of_circulars, no_of_statutes,
--         no_of_ordinances, no_of_orders, keywords, is_repealed
-- ============================================================

USE Legal_PDF;
GO

-- ─────────────────────────────────────────────
-- 1. Add new columns (idempotent)
-- ─────────────────────────────────────────────

IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'act_year')
    ALTER TABLE dbo.pdf_documents ADD act_year INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'long_title')
    ALTER TABLE dbo.pdf_documents ADD long_title NVARCHAR(MAX) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'regional_title')
    ALTER TABLE dbo.pdf_documents ADD regional_title NVARCHAR(MAX) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'notification_no')
    ALTER TABLE dbo.pdf_documents ADD notification_no NVARCHAR(100) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'act_code')
    ALTER TABLE dbo.pdf_documents ADD act_code NVARCHAR(50) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'so_reason')
    ALTER TABLE dbo.pdf_documents ADD so_reason NVARCHAR(MAX) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'no_of_rules')
    ALTER TABLE dbo.pdf_documents ADD no_of_rules INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'no_of_notifications')
    ALTER TABLE dbo.pdf_documents ADD no_of_notifications INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'no_of_regulations')
    ALTER TABLE dbo.pdf_documents ADD no_of_regulations INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'no_of_circulars')
    ALTER TABLE dbo.pdf_documents ADD no_of_circulars INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'no_of_statutes')
    ALTER TABLE dbo.pdf_documents ADD no_of_statutes INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'no_of_ordinances')
    ALTER TABLE dbo.pdf_documents ADD no_of_ordinances INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'no_of_orders')
    ALTER TABLE dbo.pdf_documents ADD no_of_orders INT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'keywords')
    ALTER TABLE dbo.pdf_documents ADD keywords NVARCHAR(MAX) NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.pdf_documents') AND name = 'is_repealed')
    ALTER TABLE dbo.pdf_documents ADD is_repealed BIT NOT NULL CONSTRAINT DF_pdf_is_repealed DEFAULT 0;
GO

-- ─────────────────────────────────────────────
-- Helper macro: the new columns for SELECT lists
-- (referenced in every SP below)
-- ─────────────────────────────────────────────
-- New columns added to every SELECT:
--   d.act_year, d.long_title, d.regional_title, d.notification_no,
--   d.act_code, d.so_reason,
--   d.no_of_rules, d.no_of_notifications, d.no_of_regulations,
--   d.no_of_circulars, d.no_of_statutes, d.no_of_ordinances, d.no_of_orders,
--   d.keywords, d.is_repealed


-- ─────────────────────────────────────────────
-- 2. sp_create_pdf_document
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_create_pdf_document
    @filename              NVARCHAR(255),
    @original_filename     NVARCHAR(255),
    @file_path             NVARCHAR(500),
    @file_size             BIGINT,
    @uploaded_by           INT,
    @document_name         NVARCHAR(500) = NULL,
    @reference_number      NVARCHAR(100) = NULL,
    @issue_date            DATE          = NULL,
    @effective_from        DATE          = NULL,
    @gazette_reference     NVARCHAR(500) = NULL,
    @legal_authority       NVARCHAR(255) = NULL,
    @short_title           NVARCHAR(255) = NULL,
    @valid_until           DATE          = NULL,
    @sector_domain         NVARCHAR(255) = NULL,
    @implementing_agency   NVARCHAR(255) = NULL,
    @next_review_date      DATE          = NULL,
    @rule_making_authority NVARCHAR(255) = NULL,
    @version_no            NVARCHAR(50)  = '1.0',
    @department_id         INT           = NULL,
    @document_type_id      INT           = NULL,
    @description           NVARCHAR(MAX) = NULL,
    @summary               NVARCHAR(MAX) = NULL,
    -- New Act-specific fields
    @act_year              INT           = NULL,
    @long_title            NVARCHAR(MAX) = NULL,
    @regional_title        NVARCHAR(MAX) = NULL,
    @notification_no       NVARCHAR(100) = NULL,
    @act_code              NVARCHAR(50)  = NULL,
    @so_reason             NVARCHAR(MAX) = NULL,
    @no_of_rules           INT           = NULL,
    @no_of_notifications   INT           = NULL,
    @no_of_regulations     INT           = NULL,
    @no_of_circulars       INT           = NULL,
    @no_of_statutes        INT           = NULL,
    @no_of_ordinances      INT           = NULL,
    @no_of_orders          INT           = NULL,
    @keywords              NVARCHAR(MAX) = NULL,
    @is_repealed           BIT           = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @new_id INT;

    INSERT INTO dbo.pdf_documents (
        filename, original_filename, file_path, file_size, uploaded_by,
        document_name, reference_number, issue_date, effective_from,
        gazette_reference, legal_authority, short_title, valid_until,
        sector_domain, implementing_agency, next_review_date, rule_making_authority,
        version_no, department_id, document_type_id, description, summary, status,
        act_year, long_title, regional_title, notification_no, act_code, so_reason,
        no_of_rules, no_of_notifications, no_of_regulations, no_of_circulars,
        no_of_statutes, no_of_ordinances, no_of_orders, keywords, is_repealed
    ) VALUES (
        @filename, @original_filename, @file_path, @file_size, @uploaded_by,
        @document_name, @reference_number, @issue_date, @effective_from,
        @gazette_reference, @legal_authority, @short_title, @valid_until,
        @sector_domain, @implementing_agency, @next_review_date, @rule_making_authority,
        @version_no, @department_id, @document_type_id, @description, @summary, 'pending',
        @act_year, @long_title, @regional_title, @notification_no, @act_code, @so_reason,
        @no_of_rules, @no_of_notifications, @no_of_regulations, @no_of_circulars,
        @no_of_statutes, @no_of_ordinances, @no_of_orders, @keywords, @is_repealed
    );

    SET @new_id = SCOPE_IDENTITY();

    SELECT
        d.id, d.filename, d.original_filename, d.file_path, d.file_size,
        d.status, d.summary,
        d.document_name, d.reference_number, d.issue_date, d.effective_from,
        d.gazette_reference, d.legal_authority, d.short_title, d.valid_until,
        d.sector_domain, d.implementing_agency, d.next_review_date, d.rule_making_authority,
        d.version_no, d.uploaded_by, d.description, d.created_at,
        d.department_id,    dep.name AS department_name,
        d.document_type_id, dt.name  AS document_type_name,
        d.act_year, d.long_title, d.regional_title, d.notification_no, d.act_code,
        d.so_reason, d.no_of_rules, d.no_of_notifications, d.no_of_regulations,
        d.no_of_circulars, d.no_of_statutes, d.no_of_ordinances, d.no_of_orders,
        d.keywords, d.is_repealed,
        NULL AS tags,
        NULL AS relationships,
        NULL AS latest_approval
    FROM  dbo.pdf_documents d
    LEFT  JOIN dbo.departments    dep ON dep.id = d.department_id
    LEFT  JOIN dbo.document_types dt  ON dt.id  = d.document_type_id
    WHERE d.id = @new_id;
END;
GO


-- ─────────────────────────────────────────────
-- 3. sp_get_pdf_by_id
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_pdf_by_id
    @document_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        d.id, d.filename, d.original_filename, d.file_path, d.file_size,
        d.status, d.summary,
        d.document_name, d.reference_number, d.issue_date, d.effective_from,
        d.gazette_reference, d.legal_authority, d.short_title, d.valid_until,
        d.sector_domain, d.implementing_agency, d.next_review_date, d.rule_making_authority,
        d.version_no, d.uploaded_by, d.description, d.created_at,
        d.department_id,    dep.name AS department_name,
        d.document_type_id, dt.name  AS document_type_name,
        d.act_year, d.long_title, d.regional_title, d.notification_no, d.act_code,
        d.so_reason, d.no_of_rules, d.no_of_notifications, d.no_of_regulations,
        d.no_of_circulars, d.no_of_statutes, d.no_of_ordinances, d.no_of_orders,
        d.keywords, d.is_repealed,
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
-- 4. sp_list_pdfs_by_user
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
        d.status, d.summary,
        d.document_name, d.reference_number, d.issue_date, d.effective_from,
        d.gazette_reference, d.legal_authority, d.short_title, d.valid_until,
        d.sector_domain, d.implementing_agency, d.next_review_date, d.rule_making_authority,
        d.version_no, d.uploaded_by, d.description, d.created_at,
        d.department_id,    dep.name AS department_name,
        d.document_type_id, dt.name  AS document_type_name,
        d.act_year, d.long_title, d.regional_title, d.notification_no, d.act_code,
        d.so_reason, d.no_of_rules, d.no_of_notifications, d.no_of_regulations,
        d.no_of_circulars, d.no_of_statutes, d.no_of_ordinances, d.no_of_orders,
        d.keywords, d.is_repealed,
        u.username   AS uploader_username,
        u.first_name AS uploader_first_name,
        u.last_name  AS uploader_last_name,
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
                         u2.username AS approver_username,
                         u2.first_name AS approver_first_name,
                         u2.last_name  AS approver_last_name
            FROM   dbo.pdf_document_approvals a
            JOIN   dbo.users u2 ON u2.id = a.approver_id
            WHERE  a.pdf_id = d.id
            ORDER  BY a.acted_at DESC
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS latest_approval
    FROM  dbo.pdf_documents d
    LEFT  JOIN dbo.departments    dep ON dep.id = d.department_id
    LEFT  JOIN dbo.document_types dt  ON dt.id  = d.document_type_id
    LEFT  JOIN dbo.users          u   ON u.id   = d.uploaded_by
    WHERE d.uploaded_by = @user_id
    ORDER BY d.created_at DESC
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO


-- ─────────────────────────────────────────────
-- 5. sp_list_all_pdfs
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
        d.status, d.summary,
        d.document_name, d.reference_number, d.issue_date, d.effective_from,
        d.gazette_reference, d.legal_authority, d.short_title, d.valid_until,
        d.sector_domain, d.implementing_agency, d.next_review_date, d.rule_making_authority,
        d.version_no, d.uploaded_by, d.description, d.created_at,
        d.department_id,    dep.name AS department_name,
        d.document_type_id, dt.name  AS document_type_name,
        d.act_year, d.long_title, d.regional_title, d.notification_no, d.act_code,
        d.so_reason, d.no_of_rules, d.no_of_notifications, d.no_of_regulations,
        d.no_of_circulars, d.no_of_statutes, d.no_of_ordinances, d.no_of_orders,
        d.keywords, d.is_repealed,
        u.username   AS uploader_username,
        u.first_name AS uploader_first_name,
        u.last_name  AS uploader_last_name,
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
                         u2.username AS approver_username,
                         u2.first_name AS approver_first_name,
                         u2.last_name  AS approver_last_name
            FROM   dbo.pdf_document_approvals a
            JOIN   dbo.users u2 ON u2.id = a.approver_id
            WHERE  a.pdf_id = d.id
            ORDER  BY a.acted_at DESC
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS latest_approval
    FROM  dbo.pdf_documents d
    LEFT  JOIN dbo.departments    dep ON dep.id = d.department_id
    LEFT  JOIN dbo.document_types dt  ON dt.id  = d.document_type_id
    LEFT  JOIN dbo.users          u   ON u.id   = d.uploaded_by
    WHERE (@status IS NULL OR d.status = @status)
    ORDER BY d.created_at DESC
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO


-- ─────────────────────────────────────────────
-- 6. sp_get_pending_pdfs
-- ─────────────────────────────────────────────

CREATE OR ALTER PROCEDURE dbo.sp_get_pending_pdfs
    @skip  INT = 0,
    @limit INT = 100
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        COUNT(*) OVER() AS total_count,
        d.id, d.filename, d.original_filename, d.file_path, d.file_size,
        d.status, d.summary,
        d.document_name, d.reference_number, d.issue_date, d.effective_from,
        d.gazette_reference, d.legal_authority, d.short_title, d.valid_until,
        d.sector_domain, d.implementing_agency, d.next_review_date, d.rule_making_authority,
        d.version_no, d.uploaded_by, d.description, d.created_at,
        d.department_id,    dep.name AS department_name,
        d.document_type_id, dt.name  AS document_type_name,
        d.act_year, d.long_title, d.regional_title, d.notification_no, d.act_code,
        d.so_reason, d.no_of_rules, d.no_of_notifications, d.no_of_regulations,
        d.no_of_circulars, d.no_of_statutes, d.no_of_ordinances, d.no_of_orders,
        d.keywords, d.is_repealed,
        u.username   AS uploader_username,
        u.first_name AS uploader_first_name,
        u.last_name  AS uploader_last_name,
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
        NULL AS latest_approval
    FROM  dbo.pdf_documents d
    LEFT  JOIN dbo.departments    dep ON dep.id = d.department_id
    LEFT  JOIN dbo.document_types dt  ON dt.id  = d.document_type_id
    LEFT  JOIN dbo.users          u   ON u.id   = d.uploaded_by
    WHERE d.status = 'pending'
    ORDER BY d.created_at ASC
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO

PRINT 'Migration add_act_extended_fields completed successfully.';
GO
