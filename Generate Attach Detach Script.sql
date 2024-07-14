USE master;
GO
-- exec usp_GenerateDetachAttachScripts 'stackoverflow2013'

-- Create the stored procedure
CREATE or Alter PROCEDURE usp_GenerateDetachAttachScripts
   
    @DatabaseName NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;

    -- Check if the database exists
    IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @DatabaseName)
    BEGIN
        PRINT 'The database [' + @DatabaseName + '] does not exist.';
        RETURN;
    END

    DECLARE @FilePaths TABLE (
        LogicalName NVARCHAR(128),
        PhysicalName NVARCHAR(260),
        TypeDesc NVARCHAR(60)
    );

    DECLARE @FilePath NVARCHAR(260);
    DECLARE @FileType NVARCHAR(60);
    DECLARE @AttachScript NVARCHAR(MAX);
    DECLARE @DetachScript NVARCHAR(MAX);

    -- Insert the file paths into the table
    INSERT INTO @FilePaths (LogicalName, PhysicalName, TypeDesc)
    SELECT name AS LogicalName, physical_name AS PhysicalName, type_desc AS TypeDesc
    FROM sys.master_files
    WHERE database_id = DB_ID(@DatabaseName);

    -- Initialize the attach script
    SET @AttachScript = 'CREATE DATABASE [' + @DatabaseName + '] ON ';

    -- Append file paths to the attach script
    DECLARE file_cursor CURSOR FOR
    SELECT PhysicalName, TypeDesc
    FROM @FilePaths;

    OPEN file_cursor;

    FETCH NEXT FROM file_cursor INTO @FilePath, @FileType;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @AttachScript = @AttachScript + CHAR(13) + '(FILENAME = ''' + @FilePath + '''),';
        FETCH NEXT FROM file_cursor INTO @FilePath, @FileType;
    END;

    CLOSE file_cursor;
    DEALLOCATE file_cursor;

    -- Remove the last comma and add FOR ATTACH
    SET @AttachScript = LEFT(@AttachScript, LEN(@AttachScript) - 1) + CHAR(13) + 'FOR ATTACH;';

    -- Generate the detach script
    SET @DetachScript = '
USE master;
GO

-- Set the database to single-user mode
ALTER DATABASE [' + @DatabaseName + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

-- Detach the database
EXEC sp_detach_db @dbname = N''' + @DatabaseName + ''';
GO
';

    -- Output the scripts
    PRINT 'Attach Script:';
    PRINT @AttachScript;

    PRINT 'Detach Script:';
    PRINT @DetachScript;
END
GO
