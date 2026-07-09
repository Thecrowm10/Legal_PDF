-- ============================================================
-- PDF Full-Text Search setup  (SQL Server T-SQL)
-- Run AFTER create_tables.sql has been executed.
--
-- Prerequisites:
--   1. SQL Server Full-Text Search feature must be installed.
--      Check: SELECT FULLTEXTSERVICEPROPERTY('IsFullTextInstalled')
--      Should return 1.
--   2. SQL Server Full-Text Daemon must be running (services.msc).
--
-- Run via sqlcmd:
--   sqlcmd -S 10.0.160.80 -U sa -P sa@123 -i scripts\add_pdf_search.sql
-- Or open in SSMS and execute.
-- ============================================================

--USE legal_pdf_db;
--GO

-- ─────────────────────────────────────────────
-- TABLE: pdf_pages  (one row per page per PDF)
-- ─────────────────────────────────────────────

IF OBJECT_ID('dbo.pdf_pages', 'U') IS NULL
CREATE TABLE dbo.pdf_pages
(
    id               INT           IDENTITY(1,1) NOT NULL,
    pdf_document_id  INT           NOT NULL,
    page_number      INT           NOT NULL,
    page_text        NVARCHAR(MAX) NULL,
    created_at       DATETIME2     NOT NULL CONSTRAINT DF_pdf_pages_created_at DEFAULT GETDATE(),
    CONSTRAINT PK_pdf_pages      PRIMARY KEY (id),
    CONSTRAINT FK_pdf_pages_doc  FOREIGN KEY (pdf_document_id)
        REFERENCES dbo.pdf_documents(id) ON DELETE CASCADE
);
GO

-- ─────────────────────────────────────────────
-- FULL-TEXT CATALOG
-- ─────────────────────────────────────────────

IF NOT EXISTS (SELECT 1 FROM sys.fulltext_catalogs WHERE name = 'pdf_catalog')
    CREATE FULLTEXT CATALOG pdf_catalog AS DEFAULT;
GO

-- ─────────────────────────────────────────────
-- FULL-TEXT INDEX on pdf_pages.page_text
-- Must be created AFTER the table and catalog exist.
-- LANGUAGE 0 = neutral (language-independent) — indexes Hindi Devanagari and English
-- without relying on a language-specific word-breaker or stemmer.
-- ─────────────────────────────────────────────

IF NOT EXISTS (
    SELECT 1
    FROM   sys.fulltext_indexes fi
    JOIN   sys.tables t ON fi.object_id = t.object_id
    WHERE  t.name = 'pdf_pages' AND SCHEMA_NAME(t.schema_id) = 'dbo'
)
CREATE FULLTEXT INDEX ON dbo.pdf_pages(page_text LANGUAGE 0)
    KEY INDEX PK_pdf_pages
    ON pdf_catalog
    WITH CHANGE_TRACKING AUTO;
GO

-- If the FTS index already exists from a previous deployment with LANGUAGE 1033,
-- run these two statements manually to switch to neutral and rebuild the index:
--
--   ALTER FULLTEXT INDEX ON dbo.pdf_pages ALTER COLUMN page_text LANGUAGE 0;
--   ALTER FULLTEXT INDEX ON dbo.pdf_pages START FULL POPULATION;
GO

-- ─────────────────────────────────────────────
-- STORED PROCEDURES
-- ─────────────────────────────────────────────

-- Save a single page's extracted text
CREATE OR ALTER PROCEDURE dbo.sp_save_pdf_page
    @pdf_document_id INT,
    @page_number     INT,
    @page_text       NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO dbo.pdf_pages (pdf_document_id, page_number, page_text)
    VALUES (@pdf_document_id, @page_number, @page_text);
END;
GO

-- Full-text search across all PDF pages.
-- @search_term supports SQL Server FTS syntax:
--   single word  : 'termination'
--   exact phrase : '"termination clause"'
--   multiple     : 'termination AND clause'
--   prefix       : 'terminat*'
CREATE OR ALTER PROCEDURE dbo.sp_search_pdf_pages
    @search_term NVARCHAR(500),
    @skip        INT = 0,
    @limit       INT = 20
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        p.id                AS page_id,
        p.pdf_document_id,
        p.page_number,
        p.page_text,
        d.original_filename,
        d.file_path,
        d.uploaded_by,
        ft.RANK             AS relevance_score
    FROM   CONTAINSTABLE(dbo.pdf_pages, page_text, @search_term) ft
    INNER JOIN dbo.pdf_pages     p ON p.id = ft.[KEY]
    INNER JOIN dbo.pdf_documents d ON d.id = p.pdf_document_id
    ORDER  BY ft.RANK DESC
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END;
GO

-- Delete all page records for a given PDF document
-- (called automatically via ON DELETE CASCADE, but also available explicitly)
CREATE OR ALTER PROCEDURE dbo.sp_delete_pdf_pages_by_doc
    @pdf_document_id INT
AS
BEGIN
    SET NOCOUNT ON;
    DELETE FROM dbo.pdf_pages WHERE pdf_document_id = @pdf_document_id;
END;
GO
