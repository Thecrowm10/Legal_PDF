-- Add is_active column to departments and document_types, update SPs, add toggle SPs

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'departments' AND COLUMN_NAME = 'is_active')
    ALTER TABLE dbo.departments ADD is_active BIT NOT NULL DEFAULT 1;
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'document_types' AND COLUMN_NAME = 'is_active')
    ALTER TABLE dbo.document_types ADD is_active BIT NOT NULL DEFAULT 1;
GO

-- ── Departments ───────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE sp_list_departments
    @skip  INT = 0,
    @limit INT = 100
AS
BEGIN
    SELECT id, name, description, is_active, created_at
    FROM dbo.departments
    ORDER BY name
    OFFSET @skip ROWS FETCH NEXT @limit ROWS ONLY;
END
GO

CREATE OR ALTER PROCEDURE sp_get_department_by_id
    @department_id INT
AS
BEGIN
    SELECT id, name, description, is_active, created_at
    FROM dbo.departments
    WHERE id = @department_id;
END
GO

CREATE OR ALTER PROCEDURE sp_create_department
    @name        NVARCHAR(100),
    @description NVARCHAR(MAX) = NULL
AS
BEGIN
    INSERT INTO dbo.departments (name, description, is_active, created_at)
    VALUES (@name, @description, 1, GETUTCDATE());

    SELECT id, name, description, is_active, created_at
    FROM dbo.departments
    WHERE id = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_toggle_department_status
    @department_id INT
AS
BEGIN
    UPDATE dbo.departments
    SET is_active = CASE WHEN is_active = 1 THEN 0 ELSE 1 END
    WHERE id = @department_id;

    SELECT id, name, description, is_active, created_at
    FROM dbo.departments
    WHERE id = @department_id;
END
GO

-- ── Document Types ────────────────────────────────────────────────────────

CREATE OR ALTER PROCEDURE sp_list_document_types
AS
BEGIN
    SELECT id, name, description, is_active, created_at
    FROM dbo.document_types
    ORDER BY name;
END
GO

CREATE OR ALTER PROCEDURE sp_get_document_type_by_id
    @type_id INT
AS
BEGIN
    SELECT id, name, description, is_active, created_at
    FROM dbo.document_types
    WHERE id = @type_id;
END
GO

CREATE OR ALTER PROCEDURE sp_create_document_type
    @name        NVARCHAR(100),
    @description NVARCHAR(MAX) = NULL
AS
BEGIN
    INSERT INTO dbo.document_types (name, description, is_active, created_at)
    VALUES (@name, @description, 1, GETUTCDATE());

    SELECT id, name, description, is_active, created_at
    FROM dbo.document_types
    WHERE id = SCOPE_IDENTITY();
END
GO

CREATE OR ALTER PROCEDURE sp_toggle_document_type_status
    @type_id INT
AS
BEGIN
    UPDATE dbo.document_types
    SET is_active = CASE WHEN is_active = 1 THEN 0 ELSE 1 END
    WHERE id = @type_id;

    SELECT id, name, description, is_active, created_at
    FROM dbo.document_types
    WHERE id = @type_id;
END
GO
