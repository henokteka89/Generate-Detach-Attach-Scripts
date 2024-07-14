USE master;
GO

-- Create the stored procedure
CREATE PROCEDURE usp_GenerateDetachAttachScripts
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

    DECLARE @DataFilePath NVARCHAR(260);
    DECLARE @LogFilePath NVARCHAR(260);
    DECLARE @AttachScript NVARCHAR(MAX);
    DECLARE @DetachScript NVARCHAR(MAX);

    -- Create a temporary table to store the file paths
    IF OBJECT_ID('tempdb..#DatabaseFiles') IS NOT NULL
        DROP TABLE #DatabaseFiles;

    CREATE TABLE #DatabaseFiles (
        LogicalName NVARCHAR(128),
        PhysicalName NVARCHAR(260),
        TypeDesc NVARCHAR(60)
    );

    -- Insert the file paths into the temporary table
    INSERT INTO #DatabaseFiles (LogicalName, PhysicalName, TypeDesc)
    SELECT name AS LogicalName, physical_name AS PhysicalName, type_desc AS TypeDesc
    FROM sys.master_files
    WHERE database_id = DB_ID(@DatabaseName);

    -- Retrieve the data file path
    SELECT @DataFilePath = PhysicalName
    FROM #DatabaseFiles
    WHERE TypeDesc = 'ROWS';

    -- Retrieve the log file path
    SELECT @LogFilePath = PhysicalName
    FROM #DatabaseFiles
    WHERE TypeDesc = 'LOG';

    -- Generate the attach script
    SET @AttachScript = '
CREATE DATABASE [' + @DatabaseName + '] ON 
(FILENAME = ''' + @DataFilePath + '''),
(FILENAME = ''' + @LogFilePath + ''')
FOR ATTACH;
';

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
