-- Generic document-name search filtered by document type (LIKE, case-insensitive)
-- Replaces the type-specific sp_search_act_names with one reusable procedure.

CREATE OR ALTER PROCEDURE sp_search_documents_by_type
    @document_type NVARCHAR(100),
    @q             NVARCHAR(255),
    @limit         INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@limit)
        p.id,
        p.document_name,
        p.reference_number,
        p.status,
        dt.name AS document_type_name
    FROM pdf_documents p
    INNER JOIN document_types dt ON p.document_type_id = dt.id
    WHERE dt.name = @document_type
      AND p.document_name LIKE N'%' + @q + N'%'
    ORDER BY p.document_name ASC;
END;
GO
