#IF .F.
*-------------------------------------------------------
*---------------- FILE CREATION INFO -------------------
Program....: THOR_PROC_GITUTILITIES
Author.....: Michael J. Potjer
Date.......: January 20, 2015
Compiler...: Visual FoxPro 09.00.0000.7423 for Windows
*-------------------------------------------------------
*------------------ USAGE SECTION ----------------------
DESCRIPTION:
	This class encapsulates a collection of utilities which make it easier to work with Git
	in a VFP development environment.

SCOPE: Public

PARAMETERS: None

USAGE: Thor_Proc_GitUtilities()

EXAMPLE:
	* If the Git utilities are in the VFP path, all you need is this:
	loGitUtils = Thor_Proc_GitUtilities()

	* OR, if it is installed in one of the Thor folders, it can be
	* instantiated using this technique.
	loGitUtils = EXECSCRIPT( _Screen.cThorDispatcher, "Thor_Proc_GitUtilities" )

	* An alternate, but more verbose, option for instantiating this
	* class in a Thor environment is this syntax:
	loGitUtils = EXECSCRIPT( _Screen.cThorDispatcher, "Class= cusGitUtilities from Thor_Proc_GitUtilities" )

RETURNS: Object
	Returns a reference to the Git utilities class defined here.

*--------------- MAINTENANCE SECTION -------------------
PRE-CONDITION INVARIANTS:
	-	The Windows Scripting Host must be available.
	-	Git for Windows must be installed so that it is available from a Windows command prompt.
	-	Some methods assume that Thor and the Thor repository are installed.
	-	Text files are generated using the VFPX app FoxBin2Prg.  This should either be installed
		via Thor (recommended), or Thor needs to be configured to be able to find FoxBin2Prg.

NOTES:

CHANGE LOG:
*-------------------------------------------------------
#ENDIF

LOCAL loGitUtils

loGitUtils = CREATEOBJECT( "cusGitUtilities" )

*-- If Thor is installed, return the object reference via the Thor
*-- dispatcher, making it easier to call this procedure via Thor,
*-- otherwise return the reference directly.
IF VARTYPE( _Screen.cThorDispatcher ) = "C" ;
		AND NOT EMPTY( _Screen.cThorDispatcher )
	RETURN EXECSCRIPT( _Screen.cThorDispatcher, "Result=", m.loGitUtils )
ELSE
	RETURN m.loGitUtils
ENDIF


#INCLUDE Thor_Proc_GitUtilities.h

*********************************************************************
DEFINE CLASS cusGitUtilities AS Custom
*********************************************************************
#IF .F.
Class:  Thor_Proc_GitUtilities.PRG/cusGitUtilities

USAGE:


EXTERNAL FILES:
	Timestamp File
	==============
	This class can maintain text files to store timestamps for all the files in a repository,
	since Git does not preserve modification dates for the files it tracks in the repository.
	The default name for the timestamp is stored in This.icTimestampFilename.  Since the file
	is maintained entirely by this class, its structure is not important, but you can learn
	more in the header comments for This.SaveRepoTimestampFile().  The file is stored in the
	root folder of the repository.

	Alternate Text Mapping File
	===========================
	By default, this class assumes FoxBin2Prg is being used to generate text files corresponding
	with the VFP binary files, and that the text files will use the default FoxBin2Prg extensions.
	However, if some other form of text file is being used for a particular binary file, that can
	be defined in this mapping file.  The default name for this mapping file is defined in
	This.icAlternateTextFilename.  This file must be created in the root folder of the repository.
	If an alternate mapping is defined for a file, then you are responsible for generating the
	text file, and this class will NOT call FoxBin2Prg to generate a text file for that binary
	file.  Both file names in the mapping MUST include the file extension.  Note that if you
	don't want ANY text file associated with a VFP binary file, then don't enter anything to the
	right of the equal (=) sign.
	The mappings must be defined in the format:
		<binary file name>=<text file name>

	You may include folder names with file names; however, they will be ignored and replaced with
	the relative path of the file within the repository.  Additional spaces around the file names
	are trimmed off and ignored.  Blank lines in the file are also ignored.  In addition, comment
	lines can be included in the file for documentation.  Two comment characters are supported
	-- the pound sign (#), commonly used for comments in Git files, and the asterisk (*), which
	of course is common to VFP.  Each comment line must begin with a comment character.

	Example:
.		# A GenDBC() .PRG file is used for the database
		MYDATA.DBC=MYDATA.PRG

METHODS THAT HAVE BEEN ADDED/MODIFIED:
======================================

PROPERTIES THAT HAVE BEEN ADDED/MODIFIED:
=========================================

MEMBER OBJECTS THAT HAVE BEEN ADDED/MODIFIED:
=============================================

#ENDIF

*-- Indicates that the user should be prompted for a project name if
*-- none was specified.  Set to .F. if this class is to remain "silent".
ilPromptForProject = .T.

*-- Indicates whether the modification date/time of files in repository
*-- are to be preserved.  This is used by This.CleanupVFPBinaries() to
*-- determine whether to call This.RestoreRepoTimestamps() after cleanup
*-- to restore the modification dates of files that haven't changed,
*-- and it's used by This.BinaryToTextRepo() to determine whether to
*-- call This.SaveRepoTimestampFile() after the files in a repo have
*-- been cleaned up, to save the new modification dates of the files
*-- that have changed.
*-- MJP -- 05/11/2015 04:12:56 PM
*-- Change this to numeric to support the following options:
*-- 	1 -	Never save/restore timestamps
*--		2 - Always save and restore timestamps
*--		3 - Save and restore timestamps only when a timestamp file
*--			exists in the repository.
inPreserveFileTimestamps = ccInitialValuePreserveTS	&& 2

*-- Stores the default name of the timestamp file which stores the
*-- modification dates of the files in the repositories.  This was
*-- changed from a constant to a property so that it can be changed at
*-- runtime.
icTimestampFilename = ccInitialValueTSFileName	&& ".gittimestamp"

*-- Stores the full path to the FoxBin2Prg.EXE app.  This can be set
*-- manually if FoxBin2Prg is in a non-standard folder where this class
*-- cannot find it.
icBin2PrgAppPath = ""

*-- This property stores a reference to an instance of the FoxBin2Prg
*-- main conversion class.  This allows us to load it once, and reuse
*-- it for as long as this utilities class is available.
ioBin2PrgConverter = .NULL.
PROTECTED ioBin2PrgConverter

*-- This property stores the last path for which FoxBin2Prg configuration
*-- settings were retrieved.
icBin2PrgSettingsPath = ""
PROTECTED icBin2PrgSettingsPath

*-- Stores the name of the cursor that maps all the extensions used
*-- for VFP binary files to the main extension for the set.
icVFPBinaryExtensionMapAlias = ""
PROTECTED icVFPBinaryExtensionMapAlias

*-- Stores the default name of the file which defines alternate text
*-- files to be associated with a VFP binary file.  This will be used
*-- in determining whether to run FoxBin2Prg on a binary file, and it
*-- will be used to determine whether to undo changes to a binary file.
icAlternateTextFilename = ".gitvfpalttext"

*-- This array stores the alternate text file mappings stored in the
*-- file specified by icAlternateTextFilename.
DIMENSION iaAlternateText[1]
iaAlternateText = .NULL.

*********************************************************************
PROCEDURE Init
*********************************************************************
*-- Attempt to retrieve any user settings from Thor whenever this class
*-- is loaded.
This.LoadThorOptions()

ENDPROC

*********************************************************************
PROTECTED PROCEDURE LoadThorOptions

*!*	This method loads any user options specified through the Thor interface.
*********************************************************************
LOCAL luValue

*-- Make sure Thor is loaded.  If not, skip this method.
IF NOT VARTYPE( _Screen.cThorDispatcher ) = "C" ;
		OR EMPTY( _Screen.cThorDispatcher )
	RETURN
ENDIF

*-- Attempt to retrieve the preserve timestamp setting, and if it's
*-- valid, use it.
luValue = EXECSCRIPT( _Screen.cThorDispatcher, "Get Option=", ccKeyPreserveTimestamps, ccToolName )
IF VARTYPE( m.luValue ) = "N" ;
		AND INLIST( m.luValue, 1, 2, 3 )
	This.inPreserveFileTimestamps = m.luValue
ENDIF

*-- Retrieve file name to use for the timestamp file.  If it's valid,
*-- use it, but make sure it doesn't include any path info.
luValue = EXECSCRIPT( _Screen.cThorDispatcher, "Get Option=", ccKeyTimestampFileName, ccToolName )
IF VARTYPE( m.luValue ) = "C" ;
		AND NOT EMPTY( m.luValue )
	This.icTimestampFilename = JUSTFNAME( m.luValue )
ENDIF

ENDPROC

*********************************************************************
FUNCTION ExecuteCommand

*!*	Executes a Git command, or any command-line command, in the specified repository folder, or
*!*	in the current folder if no repository is specified.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*		 tcRepository (O) -	The full path to the repository folder in which the specified command
*!*							is to be executed.  If omitted, the current folder will be used as
*!*							the repository.  If this method is called several times in succession,
*!*							it may be better to set the repository folder before calling this method.
*!*			tcCommand (R) -	The command to execute.  This can be anything that can be executed from
*!*							the command line, not just Git commands.
*!*			 tcOutput (O) -	A variable passed by reference to receive whatever STDOUT output is
*!*							generated by successful execution of the specified command.  Can be
*!*							omitted if the output of the command is not needed.

*!*	RETURNS: Logical
*!*		Returns .T. if the command executes successfully, or returns .F. if the command fails.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String, tcCommand AS String, tcOutput AS String

LOCAL llSuccess, ;
	loShell AS WScript.Shell, ;
	loExec AS WSCRIPT.WshExec, ;
	lcCommand, ;
	lcOutputFile, ;
	lnReturnError, ;
	lcDefaultPath

llSuccess = .T.
tcOutput = SPACE(0)

loShell = CREATEOBJECT( "WScript.Shell" )

*!* MJP -- Removed 04/30/2015 10:11:14
*!* *-- Make sure the Sleep API function is declared, which is used later.
*!* IF NOT This.IsAPIDeclared( "Sleep" )
*!* 	DECLARE Integer Sleep IN WIN32API Integer
*!* ENDIF

*-- If a repository was specified, make sure it is set as the new current
*-- folder.
lcDefaultPath = This.SetDefaultFolder( m.tcRepository )

*-- When using the Run() method, the only way to capture the output is
*-- to send it to a file.
lcOutputFile = ADDBS( SYS(2023) ) + "Output" + SYS(2015) + ".TXT"

*-- The commands do not seem to work properly, or at least they don't
*-- generate any output, unless we explicitly specify the command-line
*-- processor.  The comspec environment variable points to the command-
*-- line processor used by the OS, which is typically cmd.exe.  The /c
*-- parameter indicates that the command window should not be left open
*-- after the command executes.
*-- The command is also modified to direct the output of the command
*-- to a file.
lcCommand = "%comspec% /c " + m.tcCommand + [ > "] + m.lcOutputFile + ["]

TRY
	*!* MJP -- Removed 04/30/2015 10:11:29
	*-- There is no easy way to hide the command window using Exec(),
	*-- and possibly no way at all to hide it from VFP, so switch to
	*-- the Run() method.
	*!* *-- Attempt to execute the specified command.
	*!* loExec = m.loShell.Exec( m.tcCommand )

	*!* DO CASE
	*!* 	CASE NOT m.loExec.StdOut.AtEndOfStream
	*!* 		*-- The command executed successfully, and generated a
	*!* 		*-- non-empty output stream.  Save the stream to the output
	*!* 		*-- parameter, if it was passed.
	*!* 		tcOutput = m.loExec.StdOut.ReadAll()

	*!* 	CASE NOT m.loExec.StdErr.AtEndOfStream
	*!* 		*-- The command failed and generated an error output stream.
	*!* 		*-- Save the error and the command we were attempting to
	*!* 		*-- execute in the error object.
	*!* 		toErrorInfo = CREATEOBJECT( "Exception" )
	*!* 		toErrorInfo.Message = m.loExec.StdErr.ReadAll()
	*!* 		toErrorInfo.LineContents = m.tcCommand
	*!* 		llSuccess = .F.

	*!* 	OTHERWISE
	*!* 		*-- The command succeeded, but there is no output to report.
	*!* ENDCASE

	*!* *-- If the command is still running, wait for it to complete before
	*!* *-- continuing.
	*!* DO WHILE m.loExec.Status = 0
	*!* 	Sleep( 100 )
	*!* ENDDO

	*-- Execute the command, hiding the command window, and waiting
	*-- for the command to complete before moving on.
	lnReturnError = m.loShell.Run( m.lcCommand, 0, .T. )

	IF m.lnReturnError = 0
		*-- A successful command should return zero.  This is at least
		*-- true of git commands.  Retrieve the contents of the output
		*-- file and store them in the output variable.
		tcOutput = FILETOSTR( m.lcOutputFile )
	ELSE
		*-- An error occurred.  Generate an exception object to report
		*-- whatever information we have available.
		toErrorInfo = CREATEOBJECT( "Exception" )
		toErrorInfo.Message = IIF( FILE( m.lcOutputFile ), FILETOSTR( m.lcOutputFile ), ;
				"(No command output)" )
		toErrorInfo.LineContents = m.tcCommand
		toErrorInfo.Details = "Error " + TRANSFORM( m.lnReturnError )
		llSuccess = .F.
	ENDIF

CATCH TO toErrorInfo
	llSuccess = .F.

FINALLY
	*-- Make sure the output file is deleted when we're finished with
	*-- it.
	ERASE ( m.lcOutputFile )
ENDTRY

*-- If the current folder was changed, restore it before exiting.
This.RestoreDefaultFolder( m.lcDefaultPath )

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION GetRepoFileList

*!*	This method populates an array with a list of all the files being tracked by the specified
*!*	repository.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*		 tcRepository (O) -	The full path to the repository folder whose file list is to be
*!*							retrieved.  If omitted, the current folder will be used as the
*!*							repository.
*!*		   taFileList (R) -	An array variable passed by reference to receive the list of files in
*!*							the specified repository.  If no files are assigned to the repository
*!*							yet, the array will be initialized to a single element set to NULL.

*!*	RETURNS: Logical
*!*		.T. if the list is successfully generated, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String, taFileList

EXTERNAL ARRAY taFileList

LOCAL llSuccess, ;
	lcFileList

*-- Retrieve the list of files in the directory cache index.
llSuccess = This.ExecuteCommand( @m.toErrorInfo, m.tcRepository, "git ls-files", @m.lcFileList )

IF NOT m.llSuccess ;
		OR EMPTY( m.lcFileList )
	*-- An error occurred, or there are no files in the index.  Clear
	*-- the array.
	DIMENSION taFileList[1]
	taFileList = .NULL.
ELSE
	*-- Populate the array with the file list, and perform a case-
	*-- insensitive sort on the results.
	ALINES( taFileList, m.lcFileList, 1+4 )
	ASORT( taFileList, 1, -1, 0, 1 )
ENDIF

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION GetRepoFileModifyDates

*!*	This method populates an array with a list of all the files being tracked by the specified
*!*	repository, and the current modification date/time for each file.

*!*	PARAMETERS:
*!*			  toErrorInfo (O) -	A variable passed by reference to store any error info returned
*!*								from this method.  This will be returned as an Exception object.
*!*								This parameter is not required, but recommended.
*!*			 tcRepository (O) -	The full path to the repository folder whose file list and modification
*!*								dates are to be retrieved.  If omitted, the current folder will be
*!*								used as the repository.
*!*		   taFileDateList (R) -	An array variable passed by reference to receive the list of files
*!*								in the repository and their current modification date.  If no files
*!*								are assigned to the repository yet, the array will be initialized
*!*								to a single element set to NULL.

*!*	RETURNS: Logical
*!*		.T. if the list is successfully generated, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String, taFileDateList

EXTERNAL ARRAY taFileDateList

LOCAL llSuccess, ;
	laFileList[1], ;
	lcRepository, ;
	loShell AS Shell.Shell, ;
	loFolder AS SHELL.Folder, ;
	loFolderItem AS SHELL.FolderItem, ;
	lcFolder, ;
	lcFileName, ;
	xx

*-- Get the list of files.
llSuccess = This.GetRepoFileList( @m.toErrorInfo, m.tcRepository, @laFileList )

*-- If an error occurred, or there are no files to process, clear the
*-- array and exit.
IF NOT m.llSuccess ;
		OR ISNULL( laFileList[1] )
	DIMENSION taFileDateList[1]
	taFileDateList = .NULL.

	RETURN m.llSuccess
ENDIF

lcRepository = This.GetRepositoryPath( m.tcRepository )
loShell = CREATEOBJECT( "Shell.Application" )

*-- We know the size needed for the array, so dimension it before the
*-- loop.
DIMENSION taFileDateList[ALEN( laFileList ), 2]

FOR xx = 1 TO ALEN( laFileList )
	taFileDateList[m.xx,1] = laFileList[m.xx]
	lcFileName = JUSTFNAME( laFileList[m.xx] )

	*-- Get the full path to the file.  VFP seems to treat forward and
	*-- backslashes the same, but convert them to backslashes for consistency.
	lcFolder = ADDBS( m.lcRepository ) + JUSTPATH( CHRTRAN( laFileList[m.xx], "/", "\" ) )

	*-- Use the Windows shell object to drill down and get the modification
	*-- date for the current file.
	loFolder = m.loShell.NameSpace( m.lcFolder )
	loFolderItem = m.loFolder.ParseName( m.lcFileName )
	taFileDateList[m.xx,2] = m.loFolderItem.ModifyDate
ENDFOR

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION RepoHasChanges

*!*	This method checks if there are any changes for the specified (or current) Git repository.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*		 tcRepository (O) -	The full path to the repository folder whose status information is to
*!*							be checked.  If omitted, the current folder will be used as the repository.

*!*	RETURNS: Logical
*!*		Returns .T. if there are changes to the status of the repository, .F. if there are no
*!*		changes, and .NULL. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String

LOCAL llSuccess, ;
	lcStatusInfo, ;
	llHasChanges

*-- Retrieve the git status using the static parseable format for the
*-- output.
llSuccess = This.ExecuteCommand( @m.toErrorInfo, m.tcRepository, "git status --porcelain", ;
		@m.lcStatusInfo )

IF m.llSuccess
	*-- The status info string will be blank if there are no changes.
	llHasChanges = NOT EMPTY( m.lcStatusInfo )
ELSE
	*-- An error occurred, so we can't tell if there are changes or
	*-- not.
	llHasChanges = .NULL.
ENDIF

RETURN m.llHasChanges
ENDFUNC

*********************************************************************
FUNCTION FetchRepoFileList

*!*	This method returns a cursor containing a list of all the files committed to the specified (or
*!*	current) Git repository.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*		 tcRepository (O) -	The full path to the repository folder whose list of tracked files is
*!*							to be retrieved.  If omitted, the current folder will be used as the
*!*							repository.
*!*		tcCursorName (O) -	The name to use for the cursor that returns the file list for the
*!*							repository.  It is not required to specify a cursor name, but if no
*!*							name is specified, a variable should be passed here by reference to
*!*							receive the name of the cursor generated.

*!*	RETURNS: Logical
*!*		Returns true if the file list for the repository can be successfully retrieved, otherwise
*!*		returns .F.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String, tcCursorName AS String

LOCAL laLines[1], ;
	lcFileExtension, ;
	llSuccess, ;
	xx

tcCursorName = IIF( VARTYPE( m.tcCursorName ) = "C" AND NOT EMPTY( m.tcCursorName ), ;
		ALLTRIM( m.tcCursorName ), "C_GitRepoFileList" )
USE IN SELECT( m.tcCursorName )

*-- Generate the cursor used to store the file list.  The fields are
*-- defined as follows:
*--		GL_FileName		  -	The name of the file as currently defined in the repository.
*--		GL_FileExtension  -	The extension for the file.  For file names where there is no stem,
*--							such as .GitIgnore, this field will be left blank.
CREATE CURSOR ( m.tcCursorName ) ;
	( GL_FileName V(254), ;
		GL_FileExtension C(10) )

*-- Retrieve the git repo file list.
llSuccess = This.GetRepoFileList( @m.toErrorInfo, m.tcRepository, @laLines )

*-- If the list command failed, or there are no files in the list somehow,
*-- then there's nothing more to do here.
IF NOT m.llSuccess ;
		OR ISNULL( laLines[1] )
	RETURN m.llSuccess
ENDIF

FOR xx = 1 TO ALEN( laLines, 1 )
	*-- Determine the file extension to report.
	IF EMPTY( JUSTSTEM( laLines[m.xx] ) )
		*-- The file name has no stem, so assume it is a system
		*-- file, like .GitIgnore, and don't save an extension.
		lcFileExtension = SPACE(0)
	ELSE
		*-- The file name has a stem, so save the extension, if it has
		*-- one.
		lcFileExtension = UPPER( JUSTEXT( laLines[m.xx] ) )
	ENDIF

	INSERT INTO ( m.tcCursorName ) ;
		( GL_FileName, ;
			GL_FileExtension ) ;
		VALUES ;
		( laLines[m.xx], ;
			m.lcFileExtension )
ENDFOR

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION FetchRepoStatus

*!*	This method returns a cursor containing status information about the specified (or current)
*!*	Git repository.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*		 tcRepository (O) -	The full path to the repository folder whose status information is to
*!*							be retrieved.  If omitted, the current folder will be used as the
*!*							repository.
*!*		tcCursorName (O) -	The name to use for the cursor that returns the status info for the
*!*							repository.  It is not required to specify a cursor name, but if no
*!*							name is specified, a variable should be passed here by reference to
*!*							receive the name of the cursor generated.

*!*	RETURNS: Logical
*!*		Returns true if the status of the repository can be successfully determined, otherwise
*!*		returns .F.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String, tcCursorName AS String

LOCAL llSuccess, ;
	lcStatusInfo, ;
	laLines[1], ;
	lnCount, ;
	xx, ;
	lcIndexStatus, ;
	lcWorkTreeStatus, ;
	lcFileName, ;
	lcOldFileName, ;
	lcFileExtension

tcCursorName = IIF( VARTYPE( m.tcCursorName ) = "C" AND NOT EMPTY( m.tcCursorName ), ;
		ALLTRIM( m.tcCursorName ), "C_GitRepoStatusResults" )
USE IN SELECT( m.tcCursorName )

*-- Generate the cursor used to store the status info.  For consistency,
*-- the cursor will be generated regardless of whether there is any
*-- status info to report.  The fields are defined as follows:
*--		GS_FileName		  -	The name of the file as currently defined in the repository.
*-- 	GS_OldFileName	  -	The original name of the file, if it has been renamed in the working
*--							tree.  This will be blank if the file has not been renamed.
*--		GS_FileExtension  -	The extension for the file.  If the file has been renamed, this
*--							will be the extension for the NEW file name.  For file names where
*-- 						there is no stem, such as .GitIgnore, this field will be left blank.
*--		GS_IndexStatus	  -	The status of the file in the repository index, IOW the "staged"
*--							files.  See the git status documentation for details.  Values are
*--							blank, M, A, D, R, C, U, ? and !.
*-- 	GS_WorkTreeStatus -	The status of the file in the working tree, IOW files that are
*--							"unstaged".  See the git status documentation for details.  Uses
*--							the same values as GS_IndexStatus.
CREATE CURSOR ( m.tcCursorName ) ;
	( GS_FileName V(254), ;
		GS_OldFileName V(254), ;
		GS_FileExtension C(10), ;
		GS_IndexStatus C(1), ;
		GS_WorkTreeStatus C(1) )

*-- Retrieve the git status using the static parseable format for the
*-- output.
llSuccess = This.ExecuteCommand( @m.toErrorInfo, m.tcRepository, "git status --porcelain", ;
		@m.lcStatusInfo )

*-- If the status command failed, or there are no changes to report,
*-- then there's nothing more to do here.
IF NOT m.llSuccess ;
		OR EMPTY( m.lcStatusInfo )
	RETURN m.llSuccess
ENDIF

*-- The status for each file is on a separate line.
lnCount = ALINES( laLines, m.lcStatusInfo, 4 )

FOR xx = 1 TO m.lnCount
	*-- The first 2 characters are the status codes.
	lcIndexStatus = LEFT( laLines[m.xx], 1 )
	lcWorkTreeStatus = SUBSTR( laLines[m.xx], 2, 1 )

	*-- Check for file name changes.
	IF OCCURS( "->", laLines[m.xx] ) = 0
		*-- There is no "arrow", so the file name has not changed.
		*-- The rest of the line is the name, and there is no new file
		*-- name.
		lcOldFileName = SPACE(0)
		lcFileName = ALLTRIM( SUBSTR( laLines[m.xx], 3 ) )
	ELSE
		*-- The file name has changed, so extract the original name to
		*-- the left of the arrow, and the new name to the right.
		lcOldFileName = ALLTRIM( STREXTRACT( laLines[m.xx], LEFT( laLines[m.xx], 2 ), "->" ) )
		lcFileName = ALLTRIM( STREXTRACT( laLines[m.xx], "->" ) )
	ENDIF

	*-- Determine the file extension to report.
	IF EMPTY( JUSTSTEM( m.lcFileName ) )
		*-- The file name has no stem, so assume it is a system
		*-- file, like .GitIgnore, and don't save an extension.
		lcFileExtension = SPACE(0)
	ELSE
		*-- The file name has a stem, so save the extension, if it has
		*-- one.
		lcFileExtension = JUSTEXT( m.lcFileName )
	ENDIF

	INSERT INTO ( m.tcCursorName ) ;
		( GS_FileName, ;
			GS_OldFileName, ;
			GS_FileExtension, ;
			GS_IndexStatus, ;
			GS_WorkTreeStatus ) ;
		VALUES ;
		( m.lcFileName, ;
			m.lcOldFileName, ;
			UPPER( m.lcFileExtension ), ;
			m.lcIndexStatus, ;
			m.lcWorkTreeStatus )
ENDFOR

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION FetchReposInProject

*!*	Retrieves a cursor containing a list of all Git repositories represented in the specified
*!*	project.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*		tcProjectName (O) -	The name of the project for which the list of repositories should be
*!*							returned.  See This.GetProjectName() for details of what name will
*!*							be used if this parameter is omitted.
*!*							If this parameter is passed by reference, the name of the selected
*!*							project will be returned to the calling code.
*!*		tcCursorName (O) -	The name of the cursor in which to return the results.  If omitted and
*!*							this parameter is passed by reference, the default name for the cursor
*!*							will be returned in this parameter.

*!*	RETURNS: Logical
*!*		Returns .T. if this method is successful, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcProjectName AS String, tcCursorName AS String

LOCAL llSuccess, ;
	lcProjectName, ;
	lcProjectAlias, ;
	lcProjectFoldersAlias, ;
	lcSQL, ;
	lcFolderPath, ;
	lcBranchName

llSuccess = .T.

tcCursorName = IIF( VARTYPE( m.tcCursorName ) = "C" AND NOT EMPTY( m.tcCursorName ), ;
		ALLTRIM( m.tcCursorName ), "C_ReposInProjectList" )
USE IN SELECT( m.tcCursorName )

*-- Get the name of the project to process.
lcProjectName = This.GetProjectName( @m.toErrorInfo, m.tcProjectName )
IF EMPTY( m.lcProjectName )
	RETURN .F.
ELSE
	*-- Make sure the project name is returned to the calling code.
	tcProjectName = m.lcProjectName
ENDIF

lcProjectAlias = JUSTSTEM( m.lcProjectName ) + "_PJX" + SYS(2015)
lcProjectFoldersAlias = JUSTSTEM( m.lcProjectName ) + "_Folders" + SYS(2015)

*-- Generate the query to retrieve all the data paths represented in
*-- the specified project.
TEXT TO m.lcSQL TEXTMERGE NOSHOW
	SELECT DISTINCT ;
			CAST( ADDBS( JUSTPATH( FULLPATH( Name, "<<m.lcProjectName>>" ) ) ) AS V(254) ) ;
				AS PF_FolderPath, ;
			CAST( SPACE(0) AS V(254) ) AS PF_GitRepository ;
		FROM <<m.lcProjectAlias>> ;
		WHERE NOT Type = "H" ;
		INTO CURSOR <<m.lcProjectFoldersAlias>> READWRITE
ENDTEXT
lcSQL = This.CleanupSQL( m.lcSQL )

TRY
	*-- Attempt to open the project as a table.  This normally works
	*-- even if the project is open in the Project Manager.
	USE ( m.lcProjectName ) IN 0 ALIAS ( m.lcProjectAlias ) AGAIN SHARED

	&lcSQL.

CATCH TO toErrorInfo
	llSuccess = .F.
ENDTRY

IF m.llSuccess
	*-- Make sure the folder containing the .PJX file is also included
	*-- in the list of folders, since the project might be in a parent
	*-- folder that does not contain any other files from the project.
	lcFolderPath = UPPER( ADDBS( JUSTPATH( m.lcProjectName ) ) )
	SELECT ( m.lcProjectFoldersAlias )
	LOCATE FOR PF_FolderPath == m.lcFolderPath
	IF NOT FOUND( m.lcProjectFoldersAlias )
		*-- The folder containing the .PJX was not in the folder list.
		*-- Add it to the list to make sure we don't overlook a repository
		*-- containing the .PJX file.
		INSERT INTO ( m.lcProjectFoldersAlias ) ;
			( PF_FolderPath ) ;
			VALUES ;
			( m.lcFolderPath )
	ENDIF

	*-- Check all the folders for the project to determine which Git
	*-- repositories they are a member of, if any.
	SELECT ( m.lcProjectFoldersAlias )
	GO TOP
	SCAN
		lcFolderPath = EVALUATE( m.lcProjectFoldersAlias + ".PF_FolderPath" )

		DO WHILE OCCURS( "\", m.lcFolderPath ) > 1
			IF DIRECTORY( m.lcFolderPath + ".Git", 1 )
				*-- The current folder contains the .Git folder (which
				*-- is normally hidden), so this must be a Git repository.
				REPLACE PF_GitRepository WITH ALLTRIM( m.lcFolderPath ) ;
						IN ( m.lcProjectFoldersAlias )
				EXIT
			ELSE
				*-- This folder is not a repository, so check if the
				*-- parent folder is.  Note that although subfolders
				*-- can be omitted from a repository, it will generally
				*-- be safe to assume that any folder that is in the
				*-- project will be managed by the repository of a
				*-- parent folder.
				lcFolderPath = LEFT( m.lcFolderPath, RAT( "\", m.lcFolderPath, 2 ) )
			ENDIF
		ENDDO
	ENDSCAN

	*-- There are likely multiple project folders that are included in
	*-- the same repository, so consolidate the repository folders list.
	*-- MJP -- 04/29/2015 05:20:43 PM
	*-- Add a field to store the current branch for each repo, and make
	*-- the cursor read/write so we can populate the field.
	SELECT DISTINCT PF_GitRepository, ;
			CAST( SPACE(0) AS V(254) ) AS PF_GitCurrentBranch ;
		FROM ( m.lcProjectFoldersAlias ) ;
		WHERE NOT EMPTY( PF_GitRepository ) ;
		INTO CURSOR ( m.tcCursorName ) READWRITE

	*{ MJP -- 04/29/2015 05:21:57 PM - Begin
	IF RECCOUNT( m.tcCursorName ) > 0
		*-- There are Git repositories in the project, so look up the
		*-- current branch for each one.
		SELECT ( m.tcCursorName )
		GO TOP
		SCAN
			*-- This command retrieves the name of the current branch,
			*-- as long as you're not in a detached HEAD state, otherwise
			*-- you just get "HEAD", which will at least be a clue that
			*-- something probably needs to be done with that repo.
			IF This.ExecuteCommand( .NULL., PF_GitRepository, "git rev-parse --abbrev-ref HEAD", ;
					@m.lcBranchName )
				REPLACE PF_GitCurrentBranch WITH RTRIM( m.lcBranchName ) ;
						IN ( m.tcCursorName )
			ENDIF
		ENDSCAN
		GO TOP
	ENDIF
	*} MJP -- 04/29/2015 05:21:57 PM - End
ENDIF

*-- We're done with these cursors, so clean up.
USE IN SELECT( m.lcProjectAlias )
USE IN SELECT( m.lcProjectFoldersAlias )

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION BinaryToTextRepo

*!*	This method generates the text files for all the VFP binary files that have been changed in
*!*	the current working set of the specified repository.  Optionally, it will also undo changes
*!*	that are solely the result of a recompile, and not due to any code change.

*!*	PARAMETERS:
*!*			  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*								this method.  This will be returned as an Exception object.  This
*!*								parameter is not required, but recommended.
*!*			 tcRepository (O) -	The repository for which to generate text files for all the binary
*!*								files that have changed.  If omitted, the current default folder
*!*								is used as the repository folder.
*!*		tlCleanupModified (O) -	Indicates whether to call This.CleanupVFPBinaries() after the
*!*								text files are generated.  See that method for details.  The default
*!*								is .F., no cleanup is performed.

*!*	RETURNS: Logical
*!*		.T. if the process is successful, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String, tlCleanupModified AS Boolean

LOCAL lcChangesAlias, ;
	llHasChanges, ;
	lcRepository, ;
	llCleanupModified, ;
	lcCleanupAlias, ;
	lcRelativeFileName, ;
	lcMainExtension, ;
	lcFullFileName, ;
	lcMessage, ;
	llSuccess

llSuccess = .T.

*-- Retrieve a list of VFP binary file changes for the repository.
DO CASE
	CASE NOT This.FetchBinaryFilesToConvert( @m.toErrorInfo, m.tcRepository, @m.lcChangesAlias )
		*-- An error occurred attempting to retrieve the list, so abort.
		RETURN .F.

	CASE RECCOUNT( m.lcChangesAlias ) = 0
		*-- There are no changes in the current repository.
		llHasChanges = .F.

	OTHERWISE
		*-- There are changes to process, so continue.
		llHasChanges = .T.
ENDCASE

*-- Determine if irrelevant modifications to binary files are being
*-- cleaned up.
llCleanupModified = ( VARTYPE( m.tlCleanupModified ) = "L" AND m.tlCleanupModified )

IF m.llHasChanges
	*-- If irrelevant changes are being cleaned up, generate a cursor
	*-- to store the list of files that need to be checked.
	IF m.llCleanupModified
		lcCleanupAlias = "C_CleanupModifiedVFPBinaries" + SYS(2015)
		CREATE CURSOR ( m.lcCleanupAlias ) ;
			( CB_FileName V(254), ;
				CB_MainExtension C(3) )
	ENDIF

	*-- Get the path of the repository being processed.
	lcRepository = This.GetRepositoryPath( m.tcRepository )

	lcMessage = "Converting Binary to Text for Repository:" + CHR(13) ;
			+ m.lcRepository + CHR(13) ;
			+ "Converting file: "

	*-- Process the VFP binary files that have changed.
	SELECT ( m.lcChangesAlias )
	GO TOP
	SCAN
		*-- Determine if a text file needs to be generated for the
		*-- current binary file.
		DO CASE
			CASE INLIST( GS_WorkTreeStatus, "?", "!", "D" ) ;
					OR INLIST( GS_IndexStatus, "?", "!", "D" )
				*-- Skip files that aren't being tracked (?), or are
				*-- being ignored (!), or that have been deleted (D).
				LOOP

			OTHERWISE
				*-- Process files for every other status.
		ENDCASE

		lcRelativeFileName = GS_FileName
		lcMainExtension = This.GetMainBinaryExtension( GS_FileExtension )
		lcFullFileName = ADDBS( m.lcRepository ) + FORCEEXT( m.lcRelativeFileName, m.lcMainExtension )

		*-- Use a simple WAIT WINDOW for progress info, which should
		*-- be quicker than instantiating and destroying the FoxBin2Prg
		*-- progress form for each file being processed.
		WAIT WINDOW m.lcMessage + m.lcRelativeFileName NOWAIT NOCLEAR

		*{ MJP -- 04/21/2015 10:56:32 AM - Begin
		IF NOT This.ConvertVFPFile( @m.toErrorInfo, m.lcFullFileName, m.lcRepository )
			llSuccess = .F.
			EXIT
		ENDIF
		*} MJP -- 04/21/2015 10:56:32 AM - End

		*-- If cleanup is being performed, check if the current file
		*-- needs to be added to the list of files to check.  So far,
		*-- .VCX and .FRX are the only files I've seen changed by a
		*-- recompile.  This list should be updated to add any others
		*-- we find.
		*-- MJP -- 02/03/2015 09:16:29 AM
		*-- It seems that .SCX files can also be affected.
		*-- MJP -- 04/15/2015 11:43:26 AM
		*-- .DBC files frequently change for reasons that are not the
		*-- result of changes to code or table structures.
		SELECT ( m.lcChangesAlias )
		IF m.llCleanupModified ;
				AND INLIST( m.lcMainExtension, "VCX", "SCX", "FRX", "DBC" ) ;
				AND ( GS_WorkTreeStatus = "M" ;
					OR GS_IndexStatus = "M" )
			INSERT INTO ( m.lcCleanupAlias ) ;
				( CB_FileName, ;
					CB_MainExtension ) ;
				VALUES ;
				( m.lcRelativeFileName, ;
					m.lcMainExtension )
		ENDIF
	ENDSCAN
ENDIF	&& m.llHasChanges

USE IN SELECT( m.lcChangesAlias )

WAIT CLEAR

*-- If there were changes to process, and cleanup was specified, pass
*-- the cursor to the cleanup method processing.
IF m.llSuccess ;
		AND m.llHasChanges ;
		AND m.llCleanupModified
	llSuccess = This.CleanupVFPBinaries( @m.toErrorInfo, m.lcCleanupAlias, m.tcRepository )

	USE IN SELECT( m.lcCleanupAlias )
ENDIF

*-- Generate the timestamp file if indicated.  We'll only do this here
*-- if modified files were cleaned up, so that we don't generate a lot
*-- of timestamps for files that may need to be reverted later.
IF m.llSuccess ;
		AND m.llCleanupModified ;
		AND This.AreTimestampsPreserved( m.tcRepository )
	llSuccess = This.SaveRepoTimestampFile( @m.toErrorInfo, m.tcRepository )
ENDIF

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION CleanupVFPBinaries

*!*	This method will undo modifications to certain VFP binary files that are not the result of any
*!*	code change, for example, when a file changes due to a recompile.  Only files with a Git status
*!*	of "M" (modified) are processed, and only if the corresponding text file has not changed since
*!*	the last commit.

*!*	PARAMETERS:
*!*			  toErrorInfo (O) -	A variable passed by reference to store any error info returned
*!*								from this method.  This will be returned as an Exception object.
*!*								This parameter is not required, but recommended.
*!*		  tcFileListAlias (R) -	The name of a cursor containing a list of the files to be checked
*!*								for cleanup.  The structure of the table is determined in
*!*								This.BinaryToTextRepo().
*!*			 tcRepository (O) -	The repository where the cleanup is to take place.  If omitted,
*!*								the current default folder is used as the repository folder.

*!*	RETURNS: Logical
*!*		.T. if the cleanup is successful, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcFileListAlias AS String, tcRepository AS String

LOCAL llSuccess, ;
	lcDefaultPath, ;
	lcStatusAlias, ;
	lcRepository, ;
	lcMessage, ;
	lcRelativeFileName, ;
	lcFullFileName, ;
	llStaged, ;
	lcMainFileName, ;
	lcTextFileName

llSuccess = .T.

*-- If the specified cursor wasn't created, or doesn't contain any
*-- records, then there's nothing to do here.
IF NOT USED( m.tcFileListAlias ) ;
		OR RECCOUNT( m.tcFileListAlias ) = 0
	RETURN m.llSuccess
ENDIF

lcDefaultPath = This.SetDefaultFolder( m.tcRepository )

*-- Get a list of the most recent repository changes.
lcStatusAlias = "C_StatusForCleanup" + SYS(2015)
llSuccess = This.FetchRepoStatus( @m.toErrorInfo, .NULL., m.lcStatusAlias )

IF m.llSuccess
	lcRepository = This.GetRepositoryPath( m.tcRepository )
	lcMessage = "Cleaning up Binary files for Repository:" + CHR(13) + m.lcRepository + CHR(13)

	*-- Scan the cleanup list to confirm whether changes should be
	*-- undone for any of the files.
	SELECT ( m.tcFileListAlias )
	GO TOP
	SCAN WHILE m.llSuccess
		lcRelativeFileName = EVALUATE( m.tcFileListAlias + ".CB_FileName" )
		WAIT WINDOW m.lcMessage + "Checking file: " + m.lcRelativeFileName + "..." NOWAIT NOCLEAR

		SELECT ( m.lcStatusAlias )
		LOCATE FOR UPPER( GS_FileName ) == UPPER( m.lcRelativeFileName )

		*-- If the file is no longer in the change list, or the change
		*-- is anything other than a modification (M), then skip it.
		IF NOT FOUND( m.lcStatusAlias ) ;
				OR ( NOT EVALUATE( m.lcStatusAlias + ".GS_WorkTreeStatus" ) = "M" ;
					AND NOT EVALUATE( m.lcStatusAlias + ".GS_IndexStatus" ) = "M" )
			LOOP
		ENDIF

		*-- Check if the file is already staged for commit, in which
		*-- case 2 steps are required to undo the changes.
		llStaged = ( EVALUATE( m.lcStatusAlias + ".GS_IndexStatus" ) = "M" )

		*-- The name of the main binary file is needed to retrieve the
		*-- name of the corresponding text file.
		lcMainFileName = FORCEEXT( m.lcRelativeFileName, EVALUATE( m.tcFileListAlias + ".CB_MainExtension" ) )

		*-- Lookup the text file that corresponds to this binary file.
		*-- If the file name can't be determined, then either an invalid
		*-- file name was added to the list, or no text file is being
		*-- generated for this file.
		lcTextFileName = This.GetTextFilename( m.lcMainFileName, m.lcRepository )
		IF EMPTY( m.lcTextFileName )
			LOOP
		ENDIF

		*-- Check if the text file has changed in any way.  If it has,
		*-- then the changes to the binary file are likely relevant
		*-- and need to be committed, so leave this file alone.
		SELECT ( m.lcStatusAlias )
		LOCATE FOR UPPER( GS_FileName ) == UPPER( m.lcTextFileName )

		IF FOUND( m.lcStatusAlias )
			LOOP
		ENDIF

		*-- Change the message when the file is being restored.
		WAIT WINDOW m.lcMessage + "Restoring file: " + m.lcRelativeFileName + "..." NOWAIT NOCLEAR

		*-- If the binary file was staged, we need to unstage it.
		IF m.llStaged
			llSuccess = This.ExecCommandVFPBinary( @m.toErrorInfo, "git reset", m.lcRelativeFileName )
		ENDIF

		*-- Checkout the last version of the file for the most recent
		*-- commit in the current working tree.
		IF m.llSuccess
			llSuccess = This.ExecCommandVFPBinary( @m.toErrorInfo, "git checkout", m.lcRelativeFileName )
		ENDIF
	ENDSCAN

	*-- If timestamps are being saved, restore the modification dates
	*-- for all the files that have just been reverted, or that were
	*-- not changed at all.
	DO CASE
		CASE NOT m.llSuccess ;
				OR NOT This.AreTimestampsPreserved( m.lcRepository )
			*-- Something failed, or timestamps are not preserved, so
			*-- nothing to do.

		*-- MJP -- 05/11/2015 05:07:05 PM
		CASE NOT FILE( ADDBS( m.lcRepository ) + This.GetTimestampFileName() )
			*-- Timestamps are being preserved, but there is no file
			*-- yet, so nothing to restore.

		OTHERWISE
			*-- Attempt to restore the timestamps.
			llSuccess = This.RestoreRepoTimestamps( @m.toErrorInfo )
	ENDCASE

	WAIT CLEAR
ENDIF

USE IN SELECT( m.lcStatusAlias )

This.RestoreDefaultFolder( m.lcDefaultPath )

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION BinaryToTextProject

*!*	This method generates the text files for all the VFP binary files that have been changed in
*!*	the current working set of the repositories for the specified project.  Optionally, it will
*!*	also undo changes that are solely the result of a recompile, and not due to any code change.

*!*	PARAMETERS:
*!*			  toErrorInfo (O) -	A variable passed by reference to store any error info returned
*!*								from this method.  This will be returned as an Exception object.
*!*								This parameter is not required, but recommended.
*!*			tcProjectName (O) -	The project for which to generate text files for all the binary
*!*								files that have changed.  If omitted, the project to process will
*!*								be determined by This.GetProjectName().
*!*		tlCleanupModified (O) -	Indicates whether to call This.CleanupVFPBinaries() after the
*!*								text files are generated.  See that method for details.  The default
*!*								is .F., no cleanup is performed.

*!*	RETURNS: Logical
*!*		.T. if the conversion is successful, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcProjectName AS String, tlCleanupModified AS Boolean

LOCAL lcRepoListAlias, ;
	llSuccess

llSuccess = .T.

*-- Get a list of the repositories for the project.
DO CASE
	CASE NOT This.FetchReposInProject( @m.toErrorInfo, @m.tcProjectName, @m.lcRepoListAlias )
		*-- An error occurred retrieving the list, so abort.
		RETURN .F.

	CASE RECCOUNT( m.lcRepoListAlias ) = 0
		*-- There are no Git repositories for any of the project files,
		*-- so there's nothing to do.
		USE IN SELECT( m.lcRepoListAlias )
		RETURN m.llSuccess

	*-- MJP -- 02/05/2015 05:02:01 PM
	CASE NOT This.BinaryToTextProjectFile( @m.toErrorInfo, m.tcProjectName )
		*-- The text file for the project itself could not be updated,
		*-- so abort.
		RETURN .F.

	OTHERWISE
		*-- There is a list of repositories to process.
ENDCASE

*-- For each repository represented in the project, generate text files
*-- for all the VFP binary files that have changed.
SELECT ( m.lcRepoListAlias )
GO TOP
SCAN
	IF NOT This.BinaryToTextRepo( @m.toErrorInfo, PF_GitRepository, m.tlCleanupModified )
		llSuccess = .F.
		EXIT
	ENDIF
ENDSCAN

USE IN SELECT( m.lcRepoListAlias )

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION BinaryToTextProjectFile

*!*	This method generates the text file for the specified VFP project file.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*		tcProjectName (O) -	The project for which to generate a text file.  If omitted, the project
*!*							to process will be determined by This.GetProjectName().

*!*	RETURNS: Logical
*!*		.T. if the conversion is successful, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcProjectName AS String

LOCAL llSuccess, ;
	lcProjectName, ;
	llProjectOpen, ;
	loProject AS VisualFoxpro.IFoxProject

*-- Make sure we have the full path to the project to process.  If the
*-- project cannot be determined, abort.
lcProjectName = This.GetProjectName( @m.toErrorInfo, m.tcProjectName )
IF EMPTY( m.lcProjectName )
	RETURN .F.
ENDIF

llSuccess = .T.
llProjectOpen = .F.

IF _VFP.Projects.Count > 0
	*-- Check if the specified project is open, because we can't generate
	*-- the text file if it is.
	TRY
		loProject = _VFP.Projects.Item( m.lcProjectName )
		llProjectOpen = .T.
	CATCH
		loProject = .NULL.
		llProjectOpen = .F.
	ENDTRY

	*-- If the project was open, close it.
	IF NOT ISNULL( m.loProject )
		loProject.Close()
		loProject = .NULL.
	ENDIF
ENDIF

*-- Generate the text file for the project.
llSuccess = This.ConvertVFPFile( @m.toErrorInfo, m.lcProjectName )

*-- If the project was open, re-open it.
IF m.llProjectOpen
	MODIFY PROJECT ( m.lcProjectName ) NOWAIT
ENDIF

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION ReadRepoTimestampFile

*!*	This method reads the list of files and timestamps stored in the timestamp file for the specified
*!*	repository, and populates an array with the results.

*!*	PARAMETERS:
*!*			  toErrorInfo (O) -	A variable passed by reference to store any error info returned
*!*								from this method.  This will be returned as an Exception object.
*!*								This parameter is not required, but recommended.
*!*			 tcRepository (O) -	The full path to the repository folder whose file list and modification
*!*								dates are to be retrieved.  If omitted, the current folder will be
*!*								used as the repository.
*!*			   tcFileName (O) -	The name of the file that the timestamp data is to be read from.
*!*								- If specified, this must be JUST a file name (no path), and must
*!*								be located in the repository root.
*!*								- If omitted, the default file name will be assumed.
*!*								- The structure of the file must match the format generated by
*!*								This.SaveRepoTimestampFile().
*!*		   taFileDateList (R) -	An array variable passed by reference to receive the list of files
*!*								in the timestamp file and the modification dates saved for each.
*!*								If the file doesn't exist, or there are no files listed in it,
*!*								the array will be initialized to a single element set to NULL.
*!*								This array will have the same structure as the array generated by
*!*								This.GetRepoFileModifyDates().

*!*	RETURNS: Logical
*!*		.T. if the list is successfully generated, .F. if the timestamp file doesn't exist.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String, tcFileName AS String, taFileDateList

EXTERNAL ARRAY taFileDateList

LOCAL lcRepository, ;
	lcFullFileName, ;
	lcFileContent, ;
	llSuccess, ;
	lnFileCount, ;
	laFileList[1], ;
	xx

llSuccess = .T.

lcRepository = This.GetRepositoryPath( m.tcRepository )

lcFullFileName = ADDBS( m.lcRepository ) + This.GetTimestampFileName( m.tcFileName )

TRY
	*-- Attempt to read the contents of the file.
	lcFileContent = FILETOSTR( m.lcFullFileName )

CATCH TO toErrorInfo
	*-- If the file doesn't exist or couldn't be read, an error is
	*-- generated.
	llSuccess = .F.
	lcFileContent = SPACE(0)
ENDTRY

IF EMPTY( m.lcFileContent )
	*-- There is no timestamp data to read, so clear the array.
	DIMENSION taFileDateList[1]
	taFileDateList = .NULL.
ELSE
	*-- Populate a temporary array with the file contents, then dimension
	*-- the array to return the results.
	lnFileCount = ALINES( laFileList, m.lcFileContent, 1+4 )
	DIMENSION taFileDateList[m.lnFileCount,2]

	*-- Extract the file name and timestamp from the temporary array,
	*-- converting the timestamp to a date/time data type.
	FOR xx = 1 TO m.lnFileCount
		taFileDateList[m.xx,1] = GETWORDNUM( laFileList[m.xx], 2, CHR(9) )
		taFileDateList[m.xx,2] = EVALUATE( "{^" + GETWORDNUM( laFileList[m.xx], 1, CHR(9) ) + "}" )
	ENDFOR
ENDIF

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION SaveRepoTimestampFile

*!*	This method creates or updates a file that tracks the modification dates of the files in the
*!*	specified repository.  The file generated here can be used by This.RestoreRepoTimestamps() to
*!*	restore the modification dates after checking out files from the repository.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*		 tcRepository (O) -	The full path to the repository folder whose file list and modification
*!*							dates are to be written to a timestamp file.  The timestamp file will
*!*							be saved in this folder.  If omitted, the current folder will be used
*!*							as the repository.
*!*		   tcFileName (O) -	The name of the file that the timestamp data is to be written to.
*!*							- If specified, this must be JUST a file name (no path), and must
*!*							be located in the repository root.
*!*							- If omitted, the default file name will be assumed.
*!*							- If the file doesn't exist, and there is nothing to write to it, it
*!*							will not be created.
*!*							- If the file DOES exist, it will be updated only for files that have
*!*							been added/deleted/changed since the last commit.
*!*							The resulting file is a TAB-separated file using the following structure
*!*							for each record:
*!*								<DateTime>TAB<RelativeFilePath>CRLF
*!*							The DateTime value is stored in XML DateTime format: yyyy-mm-ddThh:mm:ss
*!*							The RelativeFilePath is the format returned by git ls-files.

*!*	RETURNS: Logical
*!*		.T. if the file can be created or updated, or if there's nothing to do, .F. if an error
*!*		occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String, tcFileName AS String

LOCAL lcRepository, ;
	lcTimestampFileName, ;
	lcFullFileName, ;
	lcOldFileContent, ;
	llSuccess, ;
	laFileDateList[1], ;
	lcStatusAlias, ;
	lnFileCount, ;
	loShell AS Shell.Shell, ;
	loFolder AS SHELL.Folder, ;
	loFolderItem AS SHELL.FolderItem, ;
	lcFolder, ;
	lcFileName, ;
	lnRow, ;
	laFilesToIgnore[1], ;
	xx, ;
	lcFileContent

lcRepository = This.GetRepositoryPath( m.tcRepository )

*-- Make sure a file name is specified.
lcTimestampFileName = This.GetTimestampFileName( m.tcFileName )

lcFullFileName = ADDBS( m.lcRepository ) + m.lcTimestampFileName

IF FILE( m.lcFullFileName )
	*-- The timestamp file already exists, so read the list of files
	*-- and timestamps from there.
	lcOldFileContent = FILETOSTR( m.lcFullFileName )
	llSuccess = This.ReadRepoTimestampFile( @m.toErrorInfo, m.tcRepository, m.lcTimestampFileName, ;
			@laFileDateList )
ELSE
	*-- The timestamp file doesn't exist, so get a list of all files
	*-- in the repository and their current timestamps.
	lcOldFileContent = SPACE(0)
	llSuccess = This.GetRepoFileModifyDates( @m.toErrorInfo, m.tcRepository, @laFileDateList )
ENDIF

lcStatusAlias = "C_WriteTimestampStatus" + SYS(2015)

*-- Get a list of the files that have been added/changed/deleted since
*-- the last commit.
IF m.llSuccess
	llSuccess = This.FetchRepoStatus( @m.toErrorInfo, m.tcRepository, m.lcStatusAlias )
ENDIF

*-- Initialize the number of files whose timestamps are being tracked.
lnFileCount = IIF( m.llSuccess AND NOT ISNULL( laFileDateList[1] ), ALEN( laFileDateList, 1 ), 0 )

*-- Update the timestamp list with the changes since the last commit.
IF m.llSuccess ;
		AND RECCOUNT( m.lcStatusAlias ) > 0
	*-- Use the Windows shell object to get the modification date.
	loShell = CREATEOBJECT( "Shell.Application" )

	SELECT ( m.lcStatusAlias )
	GO TOP
	SCAN
		*-- Check if the current changed file is in the timestamp list.
		IF ISNULL( laFileDateList[1] )
			lnRow = 0
		ELSE
			lnRow = ASCAN( laFileDateList, ALLTRIM( GS_FileName ), 1, -1, 1, 1+2+4+8 )
		ENDIF

		IF INLIST( GS_WorkTreeStatus, "?", "!", "D" ) ;
				OR INLIST( GS_IndexStatus, "?", "!", "D" )
			*-- Skip timestamps for files that aren't being tracked (?),
			*-- or are being ignored (!), or that have been deleted (D).
			*-- If this file was in the timestamp list already, remove
			*-- it.
			IF m.lnRow > 0 ;
					AND ADEL( laFileDateList, m.lnRow ) = 1
				lnFileCount = m.lnFileCount - 1

				IF m.lnFileCount = 0
					*-- Clear the array if it's empty now.
					DIMENSION laFileDateList[1]
					laFileDateList = .NULL.
				ELSE
					DIMENSION laFileDateList[m.lnFileCount,2]
				ENDIF
			ENDIF
		ELSE
			*-- This file needs to be tracked.  If it isn't in the
			*-- timestamp list, add it now.
			IF m.lnRow = 0
				lnFileCount = m.lnFileCount + 1
				lnRow = m.lnFileCount
				DIMENSION laFileDateList[m.lnRow,2]
				laFileDateList[m.lnRow,1] = ALLTRIM( GS_FileName )
			ENDIF

			lcFileName = JUSTFNAME( GS_FileName )
			lcFolder = ADDBS( m.lcRepository ) + JUSTPATH( CHRTRAN( GS_FileName, "/", "\" ) )

			*-- Get a shell object reference to the file.
			loFolder = m.loShell.NameSpace( m.lcFolder )
			loFolderItem = m.loFolder.ParseName( m.lcFileName )

			laFileDateList[m.lnRow,2] = m.loFolderItem.ModifyDate
		ENDIF
	ENDSCAN
ENDIF

*-- We're done with the status cursor.
USE IN SELECT( m.lcStatusAlias )

IF m.llSuccess ;
		AND m.lnFileCount > 0
	*-- Before saving this list, check if it includes any files that
	*-- we don't want to track, and need to be removed from the list.
	*-- For now, don't track the timestamp file itself, or Git's ignore
	*-- file, or our alternate text mapping file.
	DIMENSION laFilesToIgnore[3]
	laFilesToIgnore[1] = m.lcTimestampFileName
	laFilesToIgnore[2] = ".gitignore"
	laFilesToIgnore[3] = This.icAlternateTextFilename

	FOR xx = 1 TO ALEN( laFilesToIgnore )
		lnRow = ASCAN( laFileDateList, laFilesToIgnore[m.xx], 1, -1, 1, 1+2+4+8 )
		IF m.lnRow > 0 ;
				AND ADEL( laFileDateList, m.lnRow ) = 1
			lnFileCount = m.lnFileCount - 1
		ENDIF
	ENDFOR
ENDIF

*-- Finish up.
DO CASE
	CASE NOT m.llSuccess
		*-- An error occurred, so do nothing.

	CASE m.lnFileCount = 0
		*-- There are no timestamps to save.  If the timestamp file
		*-- originally containined data, clear it.
		IF NOT EMPTY( m.lcOldFileContent )
			STRTOFILE( SPACE(0), m.lcFullFileName )
		ENDIF

	OTHERWISE
		*-- Save the list of files in the timestamp file.  First adjust
		*-- the size of the array if records have been removed from it.
		IF m.lnFileCount < ALEN( laFileDateList, 1 )
			DIMENSION laFileDateList[m.lnFileCount, 2]
		ENDIF

		*-- Make sure the data is sorted by file name.
		ASORT( laFileDateList, 1, -1, 0, 1 )

		*-- Generate the content to be saved in the timestamp file.
		lcFileContent = SPACE(0)
		FOR lnRow = 1 TO m.lnFileCount
			lcFileContent = m.lcFileContent + TTOC( laFileDateList[m.lnRow, 2], 3 ) + CHR(9) ;
					+ laFileDateList[m.lnRow, 1] + CHR(13) + CHR(10)
		ENDFOR

		*-- If the content has changed, replace the timestamp file.
		IF NOT m.lcFileContent == m.lcOldFileContent
			STRTOFILE( m.lcFileContent, m.lcFullFileName )
		ENDIF
ENDCASE

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION SaveProjectTimestampFiles

*!*	This method creates or updates the files that track the modification dates of the files in all
*!*	the repositories of the specified project.  The files generated here can be used by
*!*	This.RestoreRepoTimestamps() to restore the modification dates after checking out files from
*!*	the repositories.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*		tcProjectName (O) -	The project for which to save file timestamps for all the files that
*!*							have changed.  If omitted, the project to process will be determined
*!*							by This.GetProjectName().

*!*	RETURNS: Logical
*!*		.T. if the timestamps are saved successfully, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcProjectName AS String

LOCAL lcRepoListAlias, ;
	llSuccess

llSuccess = .T.

*-- Get a list of the repositories for the project.
DO CASE
	CASE NOT This.FetchReposInProject( @m.toErrorInfo, @m.tcProjectName, @m.lcRepoListAlias )
		*-- An error occurred retrieving the list, so abort.
		RETURN .F.

	CASE RECCOUNT( m.lcRepoListAlias ) = 0
		*-- There are no Git repositories for any of the project files,
		*-- so there's nothing to do.
		USE IN SELECT( m.lcRepoListAlias )
		RETURN m.llSuccess

	OTHERWISE
		*-- There is a list of repositories to process.
ENDCASE

*-- For each repository represented in the project, save timestamps
*-- for all the project files that have changed.
SELECT ( m.lcRepoListAlias )
GO TOP
SCAN
	IF NOT This.SaveRepoTimestampFile( @m.toErrorInfo, PF_GitRepository )
		llSuccess = .F.
		EXIT
	ENDIF
ENDSCAN

USE IN SELECT( m.lcRepoListAlias )

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION RestoreRepoTimestamps

*!*	This method restores the modification dates of the files in a repository to the dates stored
*!*	in the current revision of the timestamp file.  File dates will only be restored for files
*!*	which have NOT changed since the last commit, IOW for files that do not appear in the git
*!*	status list.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*		 tcRepository (O) -	The full path to the repository folder whose files are to have their
*!*							modification dates restored.  If omitted, the current folder will be
*!*							used as the repository.
*!*		   tcFileName (O) -	The name of the file that the timestamp data was stored in.
*!*							- If specified, this must be JUST a file name (no path), and must
*!*							be located in the repository root.
*!*							- If omitted, the default file name will be assumed.
*!*							- If the file doesn't exist, this method will abort immediately and do
*!*							nothing.
*!*							- The file must have the structure expected by This.ReadRepoTimestampFile()

*!*	RETURNS: Logical
*!*		.T. if modification dates can be successfully restored, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String, tcFileName AS String

LOCAL llSuccess, ;
	laFileDateList[1], ;
	lcStatusAlias, ;
	lnFileCount, ;
	lnRow, ;
	lcRepository, ;
	lcFileName, ;
	lcFolder, ;
	loShell AS Shell.Shell, ;
	loFolder AS SHELL.Folder, ;
	loFolderItem AS SHELL.FolderItem

*-- Attempt to read the modification dates from the timestamp file.
*-- If there are no stored dates, or an error occurred, we're done.
llSuccess = This.ReadRepoTimestampFile( @m.toErrorInfo, m.tcRepository, @m.tcFileName, @m.laFileDateList )
IF NOT m.llSuccess ;
		OR ISNULL( laFileDateList[1] )
	RETURN m.llSuccess
ENDIF

*-- Retrieve a list of all the changes since the last commit.
lcStatusAlias = "C_SetTimestampStatus" + SYS(2015)
llSuccess = This.FetchRepoStatus( @m.toErrorInfo, m.tcRepository, m.lcStatusAlias )

lnFileCount = ALEN( laFileDateList, 1 )

IF m.llSuccess ;
		AND RECCOUNT( m.lcStatusAlias ) > 0
	*-- There have been changes since the last commit, so remove all
	*-- the changed files from the list.  We do NOT want to change the
	*-- modification date of a file that's still in the process of
	*-- being changed in some way.
	SELECT ( m.lcStatusAlias )
	GO TOP
	SCAN
		lnRow = ASCAN( laFileDateList, ALLTRIM( GS_FileName ), 1, -1, 1, 1+2+4+8 )
		IF m.lnRow > 0 ;
				AND ADEL( laFileDateList, m.lnRow ) > 0
			lnFileCount = m.lnFileCount - 1
		ENDIF
	ENDSCAN

	*-- Update the file list array.
	DO CASE
		CASE m.lnFileCount = ALEN( laFileDateList, 1 )
			*-- No files have been removed from the array (evidently
			*-- files are only being added to the repository).

		CASE m.lnFileCount = 0
			*-- ALL files have been removed from the array, so clear it.
			DIMENSION laFileDateList[1]
			laFileDateList = .NULL.

		OTHERWISE
			*-- Resize the array to remove the rows that have been
			*-- cleared.
			DIMENSION laFileDateList[m.lnFileCount, 2]
	ENDCASE
ENDIF

*-- We're done with the status cursor.
USE IN SELECT( m.lcStatusAlias )

IF m.llSuccess ;
		AND m.lnFileCount > 0
	*-- Use the Windows shell object to set the modification date.
	loShell = CREATEOBJECT( "Shell.Application" )

	lcRepository = ADDBS( This.GetRepositoryPath( m.tcRepository ) )

	FOR lnRow = 1 TO m.lnFileCount
		lcFileName = JUSTFNAME( laFileDateList[m.lnRow, 1] )
		*-- Get the full folder name and normalize it to backslashes.
		lcFolder = m.lcRepository + JUSTPATH( CHRTRAN( laFileDateList[m.lnRow, 1], "/", "\" ) )

		*-- Get a shell object reference to the file.
		loFolder = m.loShell.NameSpace( m.lcFolder )
		loFolderItem = m.loFolder.ParseName( m.lcFileName )

		*-- If the current modification date of this file is different
		*-- from what was saved, replace it.
		IF NOT m.loFolderItem.ModifyDate = laFileDateList[m.lnRow, 2]
			loFolderItem.ModifyDate = laFileDateList[m.lnRow, 2]
		ENDIF
	ENDFOR
ENDIF

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION RestoreProjectTimestamps

*!*	This method restores the modification dates of the files in all the repositories of the specified
*!*	project to the dates stored in the current revision of the timestamp files.  File dates will
*!*	only be restored for files which have NOT changed since the last commit, IOW for files that do
*!*	not appear in the git status list.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*		tcProjectName (O) -	The project for which to restore file timestamps for all the files
*!*							that have not changed.  If omitted, the project to process will be
*!*							determined by This.GetProjectName().

*!*	RETURNS: Logical
*!*		.T. if the timestamps are updated successfully, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcProjectName AS String

LOCAL lcRepoListAlias, ;
	llSuccess

llSuccess = .T.

*-- Get a list of the repositories for the project.
DO CASE
	CASE NOT This.FetchReposInProject( @m.toErrorInfo, @m.tcProjectName, @m.lcRepoListAlias )
		*-- An error occurred retrieving the list, so abort.
		RETURN .F.

	CASE RECCOUNT( m.lcRepoListAlias ) = 0
		*-- There are no Git repositories for any of the project files,
		*-- so there's nothing to do.
		USE IN SELECT( m.lcRepoListAlias )
		RETURN m.llSuccess

	OTHERWISE
		*-- There is a list of repositories to process.
ENDCASE

*-- For each repository represented in the project, update timestamps
*-- for all the project files that have not changed.
SELECT ( m.lcRepoListAlias )
GO TOP
SCAN
	IF NOT This.RestoreRepoTimestamps( @m.toErrorInfo, PF_GitRepository )
		llSuccess = .F.
		EXIT
	ENDIF
ENDSCAN

USE IN SELECT( m.lcRepoListAlias )

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION TagProject

*!*	This method attempts to assign a given tag and message to all the repositories in the specified
*!*	project.  This makes it easier to synchronize multiple repositories for a specific version of
*!*	the project.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object. This
*!*							parameter is not required, but recommended.
*!*		tcProjectName (O) -	The project which is to have a tag assigned to it.  If omitted, the
*!*							project to process will be determined by This.GetProjectName().
*!*				tcTag (R) -	The tag to assign to all the repositories for the project.
*!*			tcMessage (O) -	A message to include with the tag.

*!*	RETURNS: Logical
*!*		.T. if the process is successful, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcProjectName AS String, tcTag AS String, tcMessage AS String

LOCAL lcRepoListAlias, ;
	llSuccess, ;
	lcMessage

llSuccess = .T.

*-- Get a list of the repositories for the project.
DO CASE
	CASE NOT This.FetchReposInProject( @m.toErrorInfo, @m.tcProjectName, @m.lcRepoListAlias )
		*-- An error occurred retrieving the list, so abort.
		RETURN .F.

	CASE RECCOUNT( m.lcRepoListAlias ) = 0
		*-- There are no Git repositories for any of the project files,
		*-- so there's nothing to do.
		USE IN SELECT( m.lcRepoListAlias )
		RETURN m.llSuccess

	OTHERWISE
		*-- There is a list of repositories to process.
ENDCASE

*-- If a message was specified for the tag, format it to be included
*-- in the tag command.
IF VARTYPE( m.tcMessage ) = "C" ;
		AND NOT EMPTY( m.tcMessage )
	lcMessage = ' -m "' + m.tcMessage + '"'
ELSE
	lcMessage = SPACE(0)
ENDIF

*-- For each repository represented in the project, apply the specified
*-- tag and message.
SELECT ( m.lcRepoListAlias )
GO TOP
SCAN
	*-- Attempt to tag the current repository.  An unsigned annotated
	*-- tag (-a) will be created, and if the tag already exists it will
	*-- be replaced (-f).  If we decide to make these options configurable
	*-- in the future, properties can be added to the class for that.
	IF NOT This.ExecuteCommand( @m.toErrorInfo, PF_GitRepository, ;
			"git tag -a -f " + m.tcTag + m.lcMessage )
		llSuccess = .F.
		EXIT
	ENDIF
ENDSCAN

USE IN SELECT( m.lcRepoListAlias )

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION UnTagProject

*!*	This method is a complement to This.TagProject(), attempting to remove a specified tag from
*!*	all the repositories found in the specified project.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object. This
*!*							parameter is not required, but recommended.
*!*		tcProjectName (O) -	The project which is to have the specified tag removed from it.  If
*!*							omitted, the project to process will be determined by This.GetProjectName().
*!*				tcTag (R) -	The tag to remove from all the repositories for the project.

*!*	RETURNS: Logical
*!*		.T. if the process is successful, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcProjectName AS String, tcTag AS String

LOCAL lcRepoListAlias, ;
	llSuccess, ;
	lcTagList

llSuccess = .T.

*-- Get a list of the repositories for the project.
DO CASE
	CASE NOT This.FetchReposInProject( @m.toErrorInfo, @m.tcProjectName, @m.lcRepoListAlias )
		*-- An error occurred retrieving the list, so abort.
		RETURN .F.

	CASE RECCOUNT( m.lcRepoListAlias ) = 0
		*-- There are no Git repositories for any of the project files,
		*-- so there's nothing to do.
		USE IN SELECT( m.lcRepoListAlias )
		RETURN m.llSuccess

	OTHERWISE
		*-- There is a list of repositories to process.
ENDCASE

*-- For each repository represented in the project, delete the specified
*-- tag, if it exists.
SELECT ( m.lcRepoListAlias )
GO TOP
SCAN
	lcTagList = SPACE(0)

	*-- Attempt to lookup the specified tag in the current repository.
	DO CASE
		CASE NOT This.ExecuteCommand( @m.toErrorInfo, PF_GitRepository, ;
				'git tag -l "' + m.tcTag + '"', @m.lcTagList )
			*-- The command failed, so abort.
			llSuccess = .F.
			EXIT

		CASE EMPTY( m.lcTagList )
			*-- The tag doesn't match anything specified for the current
			*-- repository, so nothing to do.  We don't want to attempt
			*-- to delete a non-existent tag because that will generate
			*-- a git error.
			LOOP

		CASE This.ExecuteCommand( @m.toErrorInfo, PF_GitRepository, "git tag -d " + m.tcTag )
			*-- The tag was successfully deleted.

		OTHERWISE
			*-- An error occurred deleting the tag.
			llSuccess = .F.
			EXIT
	ENDCASE
ENDSCAN

USE IN SELECT( m.lcRepoListAlias )

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION SetDefaultFolder

*!*	Attempt to set the default folder for subsequent processes.

*!*	PARAMETERS:
*!*		 tcFolderPath (O) -	The full path to the folder which is to be set as the default folder
*!*							for processing.  If omitted, the current default folder will be left
*!*							as-is.

*!*	RETURNS: Character
*!*		If the default folder was changed, returns the path of the previous default folder.  If
*!*		the default folder was already set as specified, or tcFolderPath was not specified, returns
*!*		a blank string.

*!*	EXAMPLE:
*!*		lcDefaultFolder = This.SetDefaultFolder( "C:\Some\New\Folder" )

*!*		*-- do stuff...

*!*		This.RestoreDefaultFolder( lcDefaultFolder )
*********************************************************************
LPARAMETERS tcFolderPath AS String

LOCAL lcOldDefaultPath, ;
	loShell AS WScript.Shell

lcOldDefaultPath = SPACE(0)

*-- If no folder was specified, then the current default folder is to
*-- be used.  Nothing to do, so exit.
IF NOT VARTYPE( m.tcFolderPath ) = "C" ;
		OR EMPTY( m.tcFolderPath )
	RETURN m.lcOldDefaultPath
ENDIF

*-- For consistency, the Windows Script Host is used to set the default
*-- folder, since the shell object is also being used to execute the
*-- Git commands.  However, it seems that setting the default folder
*-- in VFP affects the shell too, so use of the shell could potentially
*-- be eliminated here.
loShell = CREATEOBJECT( "WScript.Shell" )

*-- If the current default is different from what was specified, set
*-- the new default, and save the old default to return to the calling
*-- code.
IF NOT UPPER( ADDBS( m.loShell.CurrentDirectory ) ) == UPPER( ADDBS( m.tcFolderPath ) )
	lcOldDefaultPath = m.loShell.CurrentDirectory
	loShell.CurrentDirectory = m.tcFolderPath
ENDIF

RETURN m.lcOldDefaultPath
ENDFUNC

*********************************************************************
PROCEDURE RestoreDefaultFolder

*!*	Restore the default folder to the specified folder.  This is intended to be used with the
*!*	return value from This.SetDefaultFolder().  See that method for more detail.

*!*	PARAMETERS:
*!*		 tcFolderPath (O) -	The full path of the folder to restore.  If omitted, this method does
*!*							nothing.

*!*	RETURNS: (nothing)
*********************************************************************
LPARAMETERS tcFolderPath AS String

LOCAL loShell AS WScript.Shell

IF VARTYPE( m.tcFolderPath ) = "C" ;
		AND NOT EMPTY( m.tcFolderPath )
	loShell = CREATEOBJECT( "WScript.Shell" )
	loShell.CurrentDirectory = m.tcFolderPath
ENDIF

ENDPROC

*********************************************************************
FUNCTION FetchBinaryFilesToConvert

*!*	This method generates a list of the VFP binary files that have been changed in the specified
*!*	Git repository.  If the main fail has changed, that will be the only file of the set included
*!*	in the list.  Otherwise, whatever secondary files have changed will be included.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*		 tcRepository (O) -	The full path to the repository folder from which a list of changed
*!*							VFP binary files is to be generated.  If omitted, the current folder
*!*							will be used as the repository.
*!*		tcCursorName (O) -	The name to use for the cursor that returns the list of VFP binary
*!*							file changes for the repository.  It is not required to specify a
*!*							cursor name, but if no name is specified, a variable should be passed
*!*							here by reference to receive the name of the cursor generated.

*!*	RETURNS: Logical
*!*		Returns true if a list can be successfully generated for the repository, otherwise returns .F.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String, tcCursorName AS String

LOCAL llSuccess, ;
	lcChangesAlias

tcCursorName = IIF( VARTYPE( m.tcCursorName ) = "C" AND NOT EMPTY( m.tcCursorName ), ;
		m.tcCursorName, "C_BinaryFilesToConvert" + SYS(2015) )
USE IN SELECT( m.tcCursorName )

*-- Retrieve a list of repository changes.
DO CASE
	CASE NOT This.FetchRepoStatus( @m.toErrorInfo, m.tcRepository, @m.lcChangesAlias )
		*-- An error occurred attempting to retrieve the list, so abort.
		RETURN .F.

	CASE RECCOUNT( m.lcChangesAlias ) = 0
		*-- There are no changes in the current repository, so nothing
		*-- to do here.  Just return the blank cursor using the specified
		*-- cursor name.
		USE DBF( m.lcChangesAlias ) IN 0 AGAIN SHARED ALIAS ( m.tcCursorName )
		USE IN SELECT( m.lcChangesAlias )
		RETURN .T.

	OTHERWISE
		*-- There are changes to process, so continue.
ENDCASE

llSuccess = .T.

TRY
	*-- First, populate the output list with just the main VFP binary
	*-- files that have changed.
	SELECT * ;
		FROM ( m.lcChangesAlias ) ;
		WHERE RTRIM( GS_FileExtension ) IN ( "PJX", "VCX", "SCX", "FRX", "LBX", "MNX", "DBC", "DBF" ) ;
		INTO CURSOR ( m.tcCursorName ) READWRITE

	This.FetchVFPExtensionMapAlias()

	*-- Next, retrieve a list of all secondary files that have changed,
	*-- where the primary file did not change.
	SELECT CHILD.* ;
		FROM ( m.lcChangesAlias ) AS CHILD ;
			INNER JOIN ( This.icVFPBinaryExtensionMapAlias ) AS EXT ;
				ON UPPER( PADR( CHILD.GS_FileExtension, 3 ) ) = EXT.EM_Extension ;
			LEFT OUTER JOIN ( m.tcCursorName ) AS MAIN ;
				ON UPPER( MAIN.GS_FileName ) ;
					== UPPER( FORCEEXT( CHILD.GS_FileName, EXT.EM_MainExtension ) ) ;
		WHERE MAIN.GS_FileName IS NULL ;
		INTO CURSOR C_ChildOnlyChanges NOFILTER

	*-- If there were additional binary file changes where the main
	*-- file did not change, add those secondary file names to the
	*-- list.
	IF RECCOUNT( "C_ChildOnlyChanges" ) > 0
		INSERT INTO ( m.tcCursorName ) ;
			SELECT * FROM C_ChildOnlyChanges
	ENDIF

CATCH TO toErrorInfo
	llSuccess = .F.

FINALLY
	USE IN SELECT( m.lcChangesAlias )
	USE IN SELECT( "C_ChildOnlyChanges" )
ENDTRY

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION PostCheckoutProcessProject

*!*	This method performs the synchronization processes typically needed after checking out a branch
*!*	of a repository, but performs it for all repositories represented in the specified project.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*		tcProjectName (O) -	The project for which to process repository files after checkouts for
*!*							the project repositories.  If omitted, the project to process will be
*!*							determined by This.GetProjectName().

*!*	RETURNS: Logical
*!*		.T. if processing is successful, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcProjectName AS String

LOCAL lcRepoListAlias, ;
	llSuccess

llSuccess = .T.

*-- Get a list of the repositories for the project.
DO CASE
	CASE NOT This.FetchReposInProject( @m.toErrorInfo, @m.tcProjectName, @m.lcRepoListAlias )
		*-- An error occurred retrieving the list, so abort.
		RETURN .F.

	CASE RECCOUNT( m.lcRepoListAlias ) = 0
		*-- There are no Git repositories for any of the project files,
		*-- so there's nothing to do.
		USE IN SELECT( m.lcRepoListAlias )
		RETURN m.llSuccess

	OTHERWISE
		*-- There is a list of repositories to process.
ENDCASE

*-- Process each repository represented in the project.
SELECT ( m.lcRepoListAlias )
GO TOP
SCAN
	IF NOT This.PostCheckoutProcessRepo( @m.toErrorInfo, PF_GitRepository )
		llSuccess = .F.
		EXIT
	ENDIF
ENDSCAN

USE IN SELECT( m.lcRepoListAlias )

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION PostCheckoutProcessRepo

*!*	This method makes sure that files not committed to a repository are synchronized as needed to
*!*	the files in the repository, something that is frequently needed after a checkout.  This primarily
*!*	involves regenerating or recompiling certain files.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*		 tcRepository (O) -	The full path to the repository folder to be processed.  If omitted,
*!*							the current folder will be used as the repository.

*!*	RETURNS: Logical
*!*		.T. if processing is successful, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String

LOCAL lcFileListAlias, ;
	llSuccess

*-- Make sure we have a unique name of the file list cursor, and that
*-- there are no prior instances open with with name.
lcFileListAlias = "C_GitRepoFileList" + SYS(2015)
USE IN SELECT( m.lcFileListAlias )

*-- Make sure all .PJX files are in synch with their corresponding
*-- text file.
llSuccess = This.RegenerateRepoProjects( @m.toErrorInfo, m.tcRepository, @m.lcFileListAlias )

*-- Make sure the program and object code files for all .MNX menu files
*-- are updated.
IF m.llSuccess
	llSuccess = This.RegenerateRepoMenus( @m.toErrorInfo, m.tcRepository, @m.lcFileListAlias )
ENDIF

*-- Make sure the object code for all program files is updated.
IF m.llSuccess
	llSuccess = This.RecompileRepoProgramFiles( @m.toErrorInfo, m.tcRepository, @m.lcFileListAlias )
ENDIF

*{ MJP -- 06/10/2015 01:40:07 PM - Begin
*-- Restore file timestamps for all repository files, if applicable.
IF m.llSuccess ;
		AND This.AreTimestampsPreserved( m.tcRepository )
	llSuccess = This.RestoreRepoTimestamps( @m.toErrorInfo, m.tcRepository )
ENDIF
*} MJP -- 06/10/2015 01:40:07 PM - End

USE IN SELECT( m.lcFileListAlias )

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION RegenerateRepoProjects

*!*	This method regenerates the .PJX files for any project text files committed to the specified
*!*	Git repository.  The .PJX/.PJT files for a project are typically not committed to a repository,
*!*	so this method ensures that those binary files are regenerated to match any text file versions
*!*	which have been checked out.

*!*	PARAMETERS:
*!*			  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*								this method.  This will be returned as an Exception object.  This
*!*								parameter is not required, but recommended.
*!*			 tcRepository (O) -	The full path to the repository folder where .PJX files are to be
*!*								regenerated.  If omitted, the current folder will be used as the
*!*								repository.
*!*		  tcFileListAlias (O) -	The alias of the cursor containing a list of all the files in the
*!*								specified repository.  If omitted or there is no cursor open with
*!*								the specified name, the file list will be retrieved here, and the
*!*								cursor name stored in this parameter.  The calling code can delegate
*!*								the task of retrieving the list to this method by passing a variable
*!*								to this parameter by reference, then it will have access to the
*!*								cursor afterward.

*!*	RETURNS: Logical
*!*		.T. if all .PJX files are successfully regenerated, or if there are no project files to
*!*		regenerate, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String, tcFileListAlias AS String

LOCAL lcRepository, ;
	lcTextExtension, ;
	laFileList[1], ;
	lcMessage, ;
	lcFullFileName, ;
	llProjectOpen, ;
	loProject AS VisualFoxpro.IFoxProject, ;
	llSuccess, ;
	xx

*-- Make sure we have a repository name.
lcRepository = This.GetRepositoryPath( m.tcRepository )

IF VARTYPE( m.tcFileListAlias ) = "C" ;
		AND NOT EMPTY( m.tcFileListAlias ) ;
		AND USED( m.tcFileListAlias )
	*-- The specified cursor is already open, so use it.
	llSuccess = .T.
ELSE
	*-- Attempt to retrieve the list of files committed to the specified
	*-- repository.
	llSuccess = This.FetchRepoFileList( @m.toErrorInfo, m.lcRepository, @m.tcFileListAlias )
ENDIF

*-- If something failed, or there are no files in this repository,
*-- there's nothing to do here.
IF NOT m.llSuccess ;
		OR RECCOUNT( m.tcFileListAlias ) = 0
	RETURN m.llSuccess
ENDIF

*-- Determine the extension used for .PJX files in the current repository.
*-- Note that although each subfolder could use a different extension,
*-- we will assume you didn't do anything that crazy, and that the
*-- correct extension can be determined at the repository root level.
lcTextExtension = This.GetTextExtension( "PJX", m.lcRepository )
IF m.lcTextExtension == "PJX"
	*-- There is no text extension for .PJX files, so either there are
	*-- no projects in this repository, or you aren't generating text
	*-- files for them.
	RETURN m.llSuccess
ENDIF

*-- Retrieve a list of the text files generated for the .PJX files in
*-- this repository folder.
SELECT GL_FileName ;
	FROM ( m.tcFileListAlias ) ;
	WHERE UPPER( RTRIM( GL_FileExtension ) ) == m.lcTextExtension ;
	INTO ARRAY laFileList

*-- There are no text files for .PJX files that are committed to the
*-- repository, so nothing to do here.
IF _TALLY = 0
	RETURN m.llSuccess
ENDIF

lcMessage = "Regenerating .PJX files for repository:" + CHR(13) ;
		+ m.lcRepository + CHR(13) ;
		+ "Regenerating file: "

*-- Regenerate all the project files.
FOR xx = 1 TO ALEN( laFileList, 1 )
	WAIT WINDOW m.lcMessage + laFileList[m.xx] NOWAIT NOCLEAR

	*-- Get the full path of the current file.  Note that FULLPATH()
	*-- normalizes any forward slashes (/) in the path to backslashes
	*-- (\), which will be important when accessing the Projects collection
	*-- below.
	lcFullFileName = FULLPATH( ADDBS( m.lcRepository ) + laFileList[m.xx] )

	llProjectOpen = .F.

	IF _VFP.Projects.Count > 0
		*-- Check if the specified project is open, because we can't
		*-- regenerate the project file if it is.
		TRY
			loProject = _VFP.Projects.Item( FORCEEXT( m.lcFullFileName, "PJX" ) )
			llProjectOpen = .T.
		CATCH
			loProject = .NULL.
			llProjectOpen = .F.
		ENDTRY

		*-- If the project was open, close it.
		IF NOT ISNULL( m.loProject )
			loProject.Close()
			loProject = .NULL.
		ENDIF
	ENDIF

	*-- Attempt to regenerate the .PJX file.
	IF NOT This.ConvertVFPFile( @m.toErrorInfo, m.lcFullFileName, m.lcRepository, .T. )
		llSuccess = .F.
		EXIT
	ENDIF

	*-- If the project was open, re-open it.
	IF m.llProjectOpen
		MODIFY PROJECT ( FORCEEXT( m.lcFullFileName, "PJX" ) ) NOWAIT
	ENDIF
ENDFOR

WAIT CLEAR

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION RegenerateRepoMenus

*!*	This method regenerates the menu code files (.MPR/.MPX) for any menu binary files (.MNX) committed
*!*	to the specified Git repository.  The code files and object code for menus typically aren't
*!*	committed to a repository, so this ensures they are in synch with different versions of the menus
*!*	which have been checked out.

*!*	PARAMETERS:
*!*			  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*								this method.  This will be returned as an Exception object.  This
*!*								parameter is not required, but recommended.
*!*			 tcRepository (O) -	The full path to the repository folder where menu files are to be
*!*								regenerated.  If omitted, the current folder will be used as the
*!*								repository.
*!*		  tcFileListAlias (O) -	The alias of the cursor containing a list of all the files in the
*!*								specified repository.  If omitted or there is no cursor open with
*!*								the specified name, the file list will be retrieved here, and the
*!*								cursor name stored in this parameter.  The calling code can delegate
*!*								the task of retrieving the list to this method by passing a variable
*!*								to this parameter by reference, then it will have access to the
*!*								cursor afterward.

*!*	RETURNS: Logical
*!*		.T. if all menu code files are successfully regenerated, or if there are no menu files to
*!*		regenerate, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String, tcFileListAlias AS String

LOCAL laFileList[1], ;
	lcFullFileName, ;
	lcMessage, ;
	lcRepository, ;
	llSuccess, ;
	xx

*-- Make sure we have a repository name.
lcRepository = This.GetRepositoryPath( m.tcRepository )

IF VARTYPE( m.tcFileListAlias ) = "C" ;
		AND NOT EMPTY( m.tcFileListAlias ) ;
		AND USED( m.tcFileListAlias )
	*-- The specified cursor is already open, so use it.
	llSuccess = .T.
ELSE
	*-- Attempt to retrieve the list of files committed to the specified
	*-- repository.
	llSuccess = This.FetchRepoFileList( @m.toErrorInfo, m.lcRepository, @m.tcFileListAlias )
ENDIF

*-- If something failed, or there are no files in this repository,
*-- there's nothing to do here.
IF NOT m.llSuccess ;
		OR RECCOUNT( m.tcFileListAlias ) = 0
	RETURN m.llSuccess
ENDIF

*-- Retrieve a list of the menu files in this repository folder.
SELECT GL_FileName ;
	FROM ( m.tcFileListAlias ) ;
	WHERE UPPER( RTRIM( GL_FileExtension ) ) == "MNX" ;
	INTO ARRAY laFileList

*-- There are no menu files that are committed to the repository, so
*-- nothing to do here.
IF _TALLY = 0
	RETURN m.llSuccess
ENDIF

lcMessage = "Regenerating menu code files for repository:" + CHR(13) ;
		+ m.lcRepository + CHR(13) ;
		+ "Regenerating menu: "

*-- Regenerate all the menu code.
FOR xx = 1 TO ALEN( laFileList, 1 )
	WAIT WINDOW m.lcMessage + laFileList[m.xx] NOWAIT NOCLEAR

	*-- Get the full path of the current file.  Note that FULLPATH()
	*-- normalizes any forward slashes (/) in the path to backslashes
	*-- (\).
	lcFullFileName = FULLPATH( ADDBS( m.lcRepository ) + laFileList[m.xx] )

	*-- Attempt to generate the code files for this menu file.
	IF NOT This.GenerateMenuCode( @m.toErrorInfo, m.lcFullFileName )
		llSuccess = .F.
		EXIT
	ENDIF
ENDFOR

WAIT CLEAR

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION RecompileRepoProgramFiles

*!*	This method recompiles all the program files committed to the specified Git repository.  The
*!*	object code files (.FXP) are typically not committed to the repository, so this ensures that
*!*	they are in synch with the program files if different versions of the program files have been
*!*	checked out.

*!*	PARAMETERS:
*!*			  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*								this method.  This will be returned as an Exception object.  This
*!*								parameter is not required, but recommended.
*!*			 tcRepository (O) -	The full path to the repository folder where program files are to be
*!*								recompiled.  If omitted, the current folder will be used as the
*!*								repository.
*!*		  tcFileListAlias (O) -	The alias of the cursor containing a list of all the files in the
*!*								specified repository.  If omitted or there is no cursor open with
*!*								the specified name, the file list will be retrieved here, and the
*!*								cursor name stored in this parameter.  The calling code can delegate
*!*								the task of retrieving the list to this method by passing a variable
*!*								to this parameter by reference, then it will have access to the
*!*								cursor afterward.

*!*	RETURNS: Logical
*!*		.T. if all program files are successfully recompiled, or if there are no program files to
*!*		recompile, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String, tcFileListAlias AS String

LOCAL laFileList[1], ;
	lcFullFileName, ;
	lcMessage, ;
	lcRepository, ;
	lcSetNotify, ;
	llSuccess, ;
	xx

*-- Make sure we have a repository name.
lcRepository = This.GetRepositoryPath( m.tcRepository )

IF VARTYPE( m.tcFileListAlias ) = "C" ;
		AND NOT EMPTY( m.tcFileListAlias ) ;
		AND USED( m.tcFileListAlias )
	*-- The specified cursor is already open, so use it.
	llSuccess = .T.
ELSE
	*-- Attempt to retrieve the list of files committed to the specified
	*-- repository.
	llSuccess = This.FetchRepoFileList( @m.toErrorInfo, m.lcRepository, @m.tcFileListAlias )
ENDIF

*-- If something failed, or there are no files in this repository,
*-- there's nothing to do here.
IF NOT m.llSuccess ;
		OR RECCOUNT( m.tcFileListAlias ) = 0
	RETURN m.llSuccess
ENDIF

*-- Retrieve a list of the program files in this repository folder.
SELECT GL_FileName ;
	FROM ( m.tcFileListAlias ) ;
	WHERE UPPER( RTRIM( GL_FileExtension ) ) == "PRG" ;
	INTO ARRAY laFileList

*-- There are no program files that are committed to the repository, so
*-- nothing to do here.
IF _TALLY = 0
	RETURN m.llSuccess
ENDIF

*-- Make sure SET NOTIFY is OFF during compiling.  We won't get any
*-- progress info when compiling very large files, but the compile is
*-- *significantly* faster.
lcSetNotify = SET("Notify")
SET NOTIFY OFF

lcMessage = "Recompiling " + ALLTRIM( TRANSFORM( ALEN( laFileList, 1 ), "999,999" ) ) ;
		+ " program files for repository:" + CHR(13) + m.lcRepository + CHR(13) ;
		+ "Please wait..."
WAIT WINDOW m.lcMessage NOWAIT NOCLEAR

TRY
	*-- Recomile all the program code.
	FOR xx = 1 TO ALEN( laFileList, 1 )
		*!* WAIT WINDOW m.lcMessage + laFileList[m.xx] NOWAIT NOCLEAR

		*-- Get the full path of the current file.  Note that FULLPATH()
		*-- normalizes any forward slashes (/) in the path to backslashes
		*-- (\).
		lcFullFileName = FULLPATH( ADDBS( m.lcRepository ) + laFileList[m.xx] )

		*-- Attempt to recompile this program.
		COMPILE ( m.lcFullFileName )
	ENDFOR

CATCH TO toErrorInfo
	llSuccess = .F.
ENDTRY

*-- Make sure the original setting is restored.
SET NOTIFY &lcSetNotify.

WAIT CLEAR

RETURN m.llSuccess
ENDFUNC

*********************************************************************
PROTECTED FUNCTION IsAPIDeclared

*!*	Determine if the specified API function has already been DECLAREd.

*!*	PARAMETERS:
*!*		   tcFunctionName (R) -	The name of the API function to look for.

*!*	RETURNS: Logical
*!*		Returns .T. if the specified API function is already DECLAREd, otherwise returns .F.
*********************************************************************
LPARAMETERS tcFunctionName AS String

LOCAL laDLLs[1], ;
	lnRow

*!* MJP -- Removed 05/06/2015 17:19:03
*!* *-- Call the VMP function that performs this task.  If this class is
*!* *-- distributed publicly, this method can be updated with equivalent
*!* *-- code to perform the same task.
*!* RETURN X7ISAPIF( m.tcFunctionName )

*-- Get a list of all DECLAREd DLLs, and if there aren't any, then the
*-- specified DLL function is not DECLAREd.
IF ADLLS( laDLLs ) = 0
	RETURN .F.
ENDIF

*-- Check if the specified function name is in the list of DECLAREd
*-- DLLs.
lnRow = ASCAN( laDLLs, m.tcFunctionName, 1, -1, 2, 1+2+4+8 )

RETURN ( m.lnRow > 0 )
ENDFUNC

*********************************************************************
PROTECTED FUNCTION CleanupSQL

*!*	Remove formatting characters from a SQL string that was created in a TEXT..ENDTEXT block.

*!*	PARAMETERS:
*!*		tcSQL (R) -	The SQL string that needs to have formatting characters removed from it.

*!*	RETURNS: Character
*!*		Returns the cleaned-up SQL string.
*********************************************************************
LPARAMETERS tcSQL AS String

LOCAL lcSQL, ;
	laLines[1], ;
	lcLine

*!* MJP -- Removed 05/06/2015 16:59:29
*!* *-- Call the VMP function that performs this task.  If this class is
*!* *-- distributed publicly, this method can be updated with equivalent
*!* *-- code to perform the same task.
*!* lcSQL = X7RemoveCRLFTAB( m.tcSQL, .T., ";" )

lcSQL = SPACE(0)

*-- Remove CR and LF, and insert a space between each line.
ALINES( laLines, m.tcSQL, 1+4 )
IF ALEN( laLines, 1 ) = 1
	*-- The passed string is a single line, so don't add any spaces.
	lcSQL = laLines[1]
ELSE
	*-- Add a space between each line of the string.
	FOR EACH lcLine IN laLines
		lcSQL = m.lcSQL + m.lcLine + SPACE(1)
	ENDFOR  
ENDIF

*-- Remove all TABs and semi-colons from the string.
lcSQL = CHRTRANC( ALLTRIM( m.lcSQL ), CHR(9) + ";", SPACE(0) )

RETURN m.lcSQL
ENDFUNC

*********************************************************************
PROTECTED FUNCTION GetRepositoryPath

*!*	This method returns the path of the repository that is being processed.

*!*	PARAMETERS:
*!*		 tcRepository (O) -	The path of a repository.  If omitted, it is assumed that the default
*!*							folder is the repository being used.

*!*	RETURNS: Character
*!*		If a repository was passed to this method, returns that path, otherwise returns the path
*!*		of the current default folder.
*********************************************************************
LPARAMETERS tcRepository AS String

LOCAL lcRepository, ;
	loShell AS WScript.Shell

IF VARTYPE( m.tcRepository ) = "C" ;
		AND NOT EMPTY( m.tcRepository )
	*-- A repository was passed, so assume this path is either set as
	*-- the current folder, or will be passed to methods that need to
	*-- know the repository path.
	lcRepository = m.tcRepository
ELSE
	*-- Nothing was specified, so assume the current folder is the path
	*-- of the repository being used.
	loShell = CREATEOBJECT( "WScript.Shell" )
	lcRepository = m.loShell.CurrentDirectory
ENDIF

*-- Make sure the formatting of the repository is consistent.
lcRepository = ADDBS( m.lcRepository )

RETURN m.lcRepository
ENDFUNC

*********************************************************************
PROTECTED FUNCTION GetTimestampFileName

*!*	This method determines the file name to use for the timestamp file.

*!*	PARAMETERS:
*!*		   tcFileName (O) -	A custom file name, either passed to the calling method or generated
*!*							by the calling method.  If omitted, user settings are used to determine
*!*							the file name to use.

*!*	RETURNS: Character
*!*		The file name to use for storing timestamp data.
*********************************************************************
LPARAMETERS tcFileName AS String

LOCAL lcFileName

*-- Check the file name, and use the default if nothing was specified.
lcFileName = IIF( VARTYPE( m.tcFileName ) = "C" AND NOT EMPTY( m.tcFileName ), ;
		ALLTRIM( m.tcFileName ), This.icTimestampFilename )

*-- Make sure the name does not include any path info.
lcFileName = JUSTFNAME( m.lcFileName )

RETURN m.lcFileName
ENDFUNC

*********************************************************************
PROTECTED FUNCTION AreTimestampsPreserved

*!*	This method checks the timestamp settings to determine if timestamps are to be saved/restored
*!*	for the specified repository.

*!*	PARAMETERS:
*!*		 tcRepository (O) -	The path of a repository.  If omitted, it is assumed that the default
*!*							folder is the repository being used.
*!*		   tcFileName (O) -	A custom file name, either passed to the calling method or generated
*!*							by the calling method.  If omitted, user settings are used to determine
*!*							the file name to use.

*!*	RETURNS: Logical
*!*		.T. if settings indicate that timestamps are to be preserved, otherwise returns .F.
*********************************************************************
LPARAMETERS tcRepository AS String, tcFileName AS String

LOCAL llSaveTimestamps, ;
	lcFileName

DO CASE
	CASE This.inPreserveFileTimestamps = 2
		*-- Timestamps are always to be saved.
		llSaveTimestamps = .T.

	CASE This.inPreserveFileTimestamps = 3
		*-- Timestamps are only to be saved if the timestamp file exists,
		*-- so lookup the name and make sure it exists in this repository.
		lcFileName = ADDBS( This.GetRepositoryPath( m.tcRepository ) ) ;
				+ This.GetTimestampFileName( m.tcFileName )

		llSaveTimestamps = FILE( m.lcFileName )

	OTHERWISE
		*-- Timestamps are never to be saved, or we somehow have an
		*-- invalid setting, so don't save them.
		llSaveTimestamps = .F.
ENDCASE

RETURN m.llSaveTimestamps
ENDFUNC

*********************************************************************
*-- MJP -- 02/13/2015 11:51:35 AM
*-- Allow access to this method outside of the class.
*!*	PROTECTED FUNCTION GetProjectName
FUNCTION GetProjectName

*!*	Validates a specified project file name, or attempts to determine the name of the project to
*!*	process.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*		tcProjectName (O) -	The name of a project file to validate.
*!*							- If this is omitted and there is a project open, the name of the
*!*							active project will be used.
*!*							- If this is omitted AND there are no projects open AND
*!*							This.ilPromptForProject = .T., then you will be prompted for the name
*!*							of the project to use.
*!*							- If this is omitted AND there are no projects open AND
*!*							This.ilPromptForProject = .F., this method will fail.

*!*	RETURNS: Character
*!*		Returns the full path and file name of the project to use, if a valid project was passed
*!*		or could be determined, otherwise returns a blank string.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcProjectName AS String

LOCAL lcProjectName

DO CASE
	CASE VARTYPE( m.tcProjectName ) = "C" ;
			AND NOT EMPTY( m.tcProjectName )
		IF FILE( m.tcProjectName )
			*-- A valid file name was specified, so use it as the name
			*-- of the project to process.  Make sure it includes the
			*-- absolute path to the file.
			lcProjectName = FULLPATH( m.tcProjectName )
		ELSE
			*-- The specified project name is not a file, or can't be
			*-- found, so generate an error.
			TRY
				ERROR "'" + m.tcProjectName + "' is not a valid project file name"

			CATCH TO toErrorInfo
				lcProjectName = SPACE(0)
			ENDTRY
		ENDIF

	CASE _VFP.Projects.Count > 0
		*-- There is an active project, so assume that is the project
		*-- to process.
		lcProjectName = _VFP.ActiveProject.Name

	CASE This.ilPromptForProject
		*-- There aren't any projects open, and the user may be prompted
		*-- for a name, so ask the user to select the project to process.
		*-- Note that this will fail if Thor and the Thor repository
		*-- are not installed.
		TRY
			lcProjectName = EXECSCRIPT( _SCREEN.cThorDispatcher, "Thor_Proc_GetProjectName" )
			IF EMPTY( m.lcProjectName )
				ERROR "No project file selected"
			ENDIF

		CATCH TO toErrorInfo
			lcProjectName = SPACE(0)
		ENDTRY

	OTHERWISE
		*-- The project to process cannot be determined, so generate
		*-- an error.
		TRY
			ERROR "Project name not specified and cannot be determined"

		CATCH TO toErrorInfo
			lcProjectName = SPACE(0)
		ENDTRY
ENDCASE

RETURN m.lcProjectName
ENDPROC

*********************************************************************
PROTECTED FUNCTION GenerateMenuCode

*!*	This function provides a simple way to generate the .MPR/.MPX files for a menu by specifying
*!*	the name of the .MNX file to process.  For whatever reason, the VFP _GenMenu function must take
*!*	the name of .PJX file, and the record number of a menu file in that project, which makes it
*!*	complicated to use that function by itself.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*		   tcMenuFile (R) -	The full path and file name of the menu file (.MNX) for which the code
*!*							file (.MPR) is to be generated.  The extension is optional, and will be
*!*							forced to .MNX if omitted.

*!*	RETURNS: Logical
*!*		.T. if the menu code file can be successfully generated, .F. otherwise.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcMenuFile AS String

LOCAL lcMenuFile, ;
	lcTempProjectName, ;
	loProject AS VisualFoxPro.IFoxProject, ;
	lcProjectAlias, ;
	lnWorkArea, ;
	lnMenuRecNo, ;
	llSuccess

lcTempProjectName = ADDBS( SYS(2023) ) + "GenerateMenu" + SYS(2015)
lcProjectAlias = "C_GenerateMenuProject" + SYS(2015)
lnWorkArea = SELECT()

TRY
	*-- Make sure a menu file name was specified.
	IF NOT VARTYPE( m.tcMenuFile ) = "C" ;
			OR EMPTY( m.tcMenuFile )
		ERROR 11
	ENDIF

	*-- Make sure the menu file has the correct extension.
	lcMenuFile = FORCEEXT( m.tcMenuFile, "mnx" )

	DO CASE
		CASE NOT FILE( m.lcMenuFile )
			*-- The specified menu file can't be found, so abort.
			ERROR 1, m.lcMenuFile

		CASE EMPTY( _GenMenu )
			*-- We use the menu-generation program specified in the
			*-- VFP development environment, but that hasn't been set.
			ERROR "The menu-generation program has not been specified."

		CASE NOT FILE( _GenMenu )
			*-- An invalid menu generation program has been specified
			*-- in the development environment.
			ERROR 1693

		OTHERWISE
			*-- Everything appears to be valid.
	ENDCASE

	*-- Since the menu generation program requires a project file,
	*-- create a temporary one for this process.
	CREATE PROJECT ( m.lcTempProjectName ) NOWAIT NOSHOW NOPROJECTHOOK
	loProject = _VFP.Projects( m.lcTempProjectName + ".PJX" )

	*-- Add the menu file to the project.
	loProject.Files.Add( m.lcMenuFile )

	*-- We need to lookup the project table record for the menu file
	*-- and hack it for this process to succeed.
	USE ( m.lcTempProjectName + ".PJX" ) IN 0 AGAIN ALIAS ( m.lcProjectAlias ) SHARED

	*-- Locate the record referencing the menu file.
	SELECT ( m.lcProjectAlias )
	LOCATE FOR Type = "M"
	IF FOUND( m.lcProjectAlias )
		*-- We need the record number of the project table record that
		*-- references the menu file so that we can pass it to the menu
		*-- generation program used by VFP.
		lnMenuRecNo = RECNO( m.lcProjectAlias )

		*-- The relative path and file name of the .MPR output file
		*-- must be specified in the project file, otherwise the menu
		*-- generation program will fail.  Make sure the output file
		*-- is in the same folder and has the same file stem as the
		*-- menu file.  The file name must also be NULL terminated,
		*-- otherwise the VFP menu generation program will fail.
		REPLACE OutFile WITH FORCEEXT( Name, "mpr" ) + CHR(0) ;
				IN ( m.lcProjectAlias )
	ELSE
		*-- We just added the menu file, so there's no good reason for
		*-- this, but abort.
		ERROR "The menu file '" + m.lcMenuFile + "' could not be processed."
	ENDIF

	*-- We're done with the cursor, so attempt to close it.
	USE IN SELECT( m.lcProjectAlias )

	*-- We finally have everything we need to call the VFP menu generation
	*-- program.
	DO ( _GenMenu ) WITH m.lcTempProjectName + ".PJX", m.lnMenuRecNo

	llSuccess = .T.

CATCH TO toErrorInfo
	llSuccess = .F.

FINALLY
	*-- Make sure the project table cursor is closed, in case something
	*-- failed while it was still open.
	USE IN SELECT( m.lcProjectAlias )

	*-- Make sure the temporary project is closed.
	IF VARTYPE( m.loProject ) = "O"
		loProject.Close()
	ENDIF

	*-- Attempt to erase the temporary project.
	ERASE ( m.lcTempProjectName + ".*" )

	*-- Restore whatever work area was selected when this function was
	*-- called.
	SELECT ( m.lnWorkArea )
ENDTRY

RETURN m.llSuccess
ENDFUNC

*********************************************************************
PROTECTED FUNCTION GetBin2PrgAppPath

*!*	Retrieves the full path to the Binary to Text conversion app.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.

*!*	RETURNS: Character
*!*		Returns the full path to the binary to text conversion app if successful, otherwise returns
*!*		a blank string.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception

LOCAL lcAppPath

IF VARTYPE( This.icBin2PrgAppPath ) = "C" ;
		AND NOT EMPTY( This.icBin2PrgAppPath ) ;
		AND DIRECTORY( This.icBin2PrgAppPath )
	*-- The path was already set, either outside of this class or in a
	*-- prior call to this method.
	lcAppPath = This.icBin2PrgAppPath
ELSE
	*-- Retrieve the FoxBin2Prg folder.  The default function code only
	*-- returns an empty value if the folder was not found and the user
	*-- didn't select anything when prompted.
	*-- Note that this will fail if Thor and the Thor repository are
	*-- not installed.
	TRY
		lcAppPath = EXECSCRIPT( _Screen.cThorDispatcher, "Thor_Proc_GetFoxBin2PrgFolder" )

		DO CASE
			CASE EMPTY( m.lcAppPath )
				*-- The location of FoxBin2Prg could not be determined,
				*-- so generate an error and abort.
				ERROR "FoxBin2Prg folder could not be determined"

			CASE FILE( FORCEPATH( "FoxBin2Prg.EXE", m.lcAppPath ) )
				*-- The app was found.  Save the path in the property
				*-- so that it doesn't need to be located next time.
				This.icBin2PrgAppPath = ADDBS( m.lcAppPath )

			OTHERWISE
				*-- The FoxBin2Prg path returned is invalid, so generate
				*-- an error and abort.
				ERROR "'" + m.lcAppPath + "' is not a valid FoxBin2Prg folder"
		ENDCASE

	CATCH TO toErrorInfo
		lcAppPath = SPACE(0)
	ENDTRY
ENDIF

RETURN m.lcAppPath
ENDPROC

*********************************************************************
PROTECTED FUNCTION GetBin2PrgConverter

*!*	This method makes sure the FoxBin2Prg converter class is loaded, and returns a reference to it.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.

*!*	RETURNS: Object
*!*		A reference to the converter object if successful, otherwise returns NULL.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception

LOCAL loConverter, ;
	lcBin2PrgPath

loConverter = .NULL.

TRY
	*-- If the converter has already been loaded, set the return value
	*-- and exit.
	IF VARTYPE( This.ioBin2PrgConverter ) = "O"
		loConverter = This.ioBin2PrgConverter
		EXIT
	ENDIF

	*-- Attempt to get the FoxBin2Prg application path.  If we can't
	*-- get it, abort.  An error message should already be stored.
	lcBin2PrgPath = This.GetBin2PrgAppPath( @m.toErrorInfo )
	IF EMPTY( m.lcBin2PrgPath )
		EXIT
	ENDIF

	*-- Attempt to instantiate the converter.
	SET PROCEDURE TO ( ADDBS( m.lcBin2PrgPath ) + "FOXBIN2PRG.EXE" ) ADDITIVE
	loConverter = CREATEOBJECT( "C_FoxBin2Prg" )

	*-- If the converter was successfully loaded, store a reference
	*-- for next time, otherwise abort with an error.
	IF VARTYPE( m.loConverter ) = "O"
		This.ioBin2PrgConverter = m.loConverter
	ELSE
		ERROR "Unable to instantiate Bin-to-Prg converter object"
	ENDIF

CATCH TO toErrorInfo
	loConverter = .NULL.
ENDTRY

RETURN m.loConverter
ENDFUNC

*********************************************************************
PROTECTED FUNCTION ConvertVFPFile

*!*	This method attempts to generate the FoxBin2Prg text file for the specified VFP binary file, or
*!*	generate the VFP binary file for the specified FoxBin2Prg text file.

*!*	PARAMETERS:
*!*			  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*								this method.  This will be returned as an Exception object.  This
*!*								parameter is not required, but recommended.
*!*		  tcInputFilename (R) -	The name of a VFP binary file for which a text file is to be generated,
*!*								or the name of the text file to be converted to a VFP binary file.
*!*								The file name must include an extension, and for binary file types
*!*								the extension must be the MAIN extension for that file type.  For
*!*								example, for a VFP table, the extension must be .DBF, NOT .CDX or
*!*								.FPT.  Full path information is expected to be included in the file
*!*								name.
*!*			 tcRepository (O) -	The path of a repository.  This parameter is not used directly in
*!*			 					this method, but passed on to methods called from here.
*!*		 tlGenerateBinary (O) -	If passed as .T., indicates that tcInputFilename is the name of a
*!*								text file that is to be converted to a binary file.  If omitted,
*!*								the input file is assumed to be a binary file that will be converted
*!*								to a text file.

*!*	RETURNS: Logical
*!*		.T. if the file can be successfully converted, or if there's nothing to do, .F. if this
*!*		process fails.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcInputFilename AS String, tcRepository AS String, ;
			tlGenerateBinary AS Boolean

LOCAL loConverter AS C_FoxBin2Prg OF "C:\Work\VFP\Shared\Tools\Thor\Tools\Components\FoxBin2Prg\FoxBin2Prg.PRG", ;
	lcAltTextFilename, ;
	llGenerateText, ;
	llSuccess

llGenerateText = ( NOT VARTYPE( m.tlGenerateBinary ) = "L" OR NOT m.tlGenerateBinary )
llSuccess = .T.

IF m.llGenerateText
	*-- Check if the specified VFP binary file uses an alternate text
	*-- file.  If so, assume it is not generated by FoxBin2Prg, and exit.
	lcAltTextFilename = This.GetAlternateTextName( m.tcInputFilename, m.tcRepository )
	IF VARTYPE( m.lcAltTextFilename ) = "C"
		RETURN m.llSuccess
	ENDIF
ENDIF

*-- Attempt to get a reference to the converter.  If we can't get it,
*-- abort with an error.
loConverter = This.GetBin2PrgConverter( @m.toErrorInfo )
IF ISNULL( m.loConverter )
	RETURN .F.
ENDIF

*-- Make sure the FoxBin2Prg config settings are loaded for the folder
*-- containing the file being processed.
This.SetBin2PrgConfiguration( JUSTPATH( m.tcInputFilename ) )

*-- Check if file conversion is supported for the specified file, otherwise
*-- there's nothing to do here.
IF m.llGenerateText
	IF NOT m.loConverter.hasSupport_Bin2Prg( m.tcInputFilename )
		RETURN m.llSuccess
	ENDIF
ELSE
	IF NOT m.loConverter.hasSupport_Prg2Bin( m.tcInputFilename )
		RETURN m.llSuccess
	ENDIF
ENDIF

*-- Attempt to convert the file.  Only one file is being processed, so
*-- don't take the time to show progress info.  Don't show errors either,
*-- since we'll just retrieve the error info in the exception object
*-- which we return to the calling code for processing.
IF m.loConverter.Execute( m.tcInputFilename, "", "", m.llGenerateText, "1", "0", "1", .NULL., ;
		@m.toErrorInfo ) > 0
	llSuccess = .F.
ENDIF

RETURN m.llSuccess
ENDFUNC

*********************************************************************
PROTECTED PROCEDURE SetBin2PrgConfiguration

*!*	This method attempts to ensure that FoxBin2Prg configuration settings are loaded for the specified
*!*	folder.

*!*	PARAMETERS:
*!*		   tcSettingsPath (R) -	The full path to the folder for which FoxBin2Prg configuration settings
*!*								are to be retrieved.
*********************************************************************
LPARAMETERS tcSettingsPath AS String

LOCAL loConverter AS C_FoxBin2Prg OF "C:\Work\VFP\Shared\Tools\Thor\Tools\Components\FoxBin2Prg\FoxBin2Prg.PRG"

*-- If the settings path hasn't changed, then the config settings are
*-- already loaded for this path, and we're done.
IF This.icBin2PrgSettingsPath == UPPER( ADDBS( m.tcSettingsPath ) )
	RETURN
ENDIF

*-- Get a reference to the converter.  If we can't get it, there's
*-- nothing more to do here.  We won't bother returning error info,
*-- since whatever the calling code intends to do with the settings is
*-- probably going to require the converter, too.
loConverter = This.GetBin2PrgConverter()
IF ISNULL( m.loConverter )
	RETURN
ENDIF

*-- Save the path so that we don't need to load the settings again if
*-- the next call needs settings for the same path.
This.icBin2PrgSettingsPath = UPPER( ADDBS( m.tcSettingsPath ) )

*-- Attempt to load the settings for this [D]irectory, but don't override
*-- any config file settings.
loConverter.evaluateConfiguration( "", "", "", "", "", "", "", "", This.icBin2PrgSettingsPath, "D" )

ENDPROC

*********************************************************************
PROTECTED FUNCTION GetTextExtension

*!*	This method determines the extension that will be used when a generating a text file for a file
*!*	with the specified binary extension.

*!*	PARAMETERS:
*!*		tcBinaryExtension (R) -	The VFP binary extension for which a text extension is needed.
*!*								This must be one of the values returned by This.GetMainBinaryExtension().
*!*			   tcFilePath (O) -	The path where the binary file is located.  If omitted, get the text
*!*								extension that applies to files in the root folder of the current
*!*								repository.

*!*	RETURNS: Character
*!*		If a text file extension applies for the specified binary extension, it will be returned,
*!*		otherwise the extension passed to this method will be returned as-is.
*********************************************************************
LPARAMETERS tcBinaryExtension AS String, tcFilePath AS String

LOCAL lcFilePath, ;
	loConverter AS C_FoxBin2Prg OF "C:\Work\VFP\Shared\Tools\Thor\Tools\Components\FoxBin2Prg\FoxBin2Prg.PRG", ;
	lcTextExtension

*-- Text extensions can vary by folder.  We don't recommend doing that,
*-- but we'll take that into account.  If the calling code didn't specify
*-- the folder being used, use the repository folder.
IF VARTYPE( m.tcFilePath ) = "C" ;
		AND NOT EMPTY( m.tcFilePath )
	lcFilePath = m.tcFilePath
ELSE
	lcFilePath = This.GetRepositoryPath()
ENDIF

*-- Make sure the FoxBin2Prg configuration settings are loaded for the
*-- specified folder.
This.SetBin2PrgConfiguration( m.lcFilePath )

*-- Use the Bin-to-Prg object to get the default extension used for
*-- the text file.
loConverter = This.GetBin2PrgConverter()
lcTextExtension = UPPER( m.loConverter.get_Ext2FromExt( m.tcBinaryExtension ) )

RETURN m.lcTextExtension
ENDFUNC

*********************************************************************
PROTECTED FUNCTION GetTextFilename

*!*	This method determines the name of the text file that will be generated for a specified VFP
*!*	binary file.

*!*	PARAMETERS:
*!*		 tcBinaryFilename (R) -	The name of a VFP binary file for which the name of a text file is
*!*								to be returned.  The file name must include an extension, and the
*!*								extension must be the MAIN extension for that binary file type.  For
*!*								example, for a VFP table, the extension must be .DBF, NOT .CDX or
*!*								.FPT.  Any path information in the file name must be relative to
*!*								the specified repository, and will be applied to the text file name
*!*								returned.
*!*			 tcRepository (O) -	The path of a repository.  This parameter is used to determine the
*!*								the full path for the specified tcBinaryFilename.

*!*	RETURNS: Character
*!*		If a text file will be generated, the file name will be returned, otherwise if no text file
*!*		will be generated, or the name cannot be determined, a blank string will be returned.
*********************************************************************
LPARAMETERS tcBinaryFilename AS String, tcRepository AS String

LOCAL lcTextFilename, ;
	lcFilePath, ;
	loConverter AS C_FoxBin2Prg OF "C:\Work\VFP\Shared\Tools\Thor\Tools\Components\FoxBin2Prg\FoxBin2Prg.PRG", ;
	lcTextExtension

*-- First check if the specified binary file uses an alternate text
*-- file.
lcTextFilename = This.GetAlternateTextName( m.tcBinaryFilename, m.tcRepository )

IF ISNULL( m.lcTextFilename )
	*-- There is no alternate text file mapping.  Get the full path to
	*-- the binary file, and lookup the extension for the specified
	*-- file.
	lcFilePath = This.GetRepositoryPath( m.tcRepository )
	lcFilePath = JUSTPATH( ADDBS( m.lcFilePath ) + m.tcBinaryFilename )
	lcTextExtension = This.GetTextExtension( JUSTEXT( m.tcBinaryFilename ), m.lcFilePath )

	*-- If the binary extension isn't recognized, the original extension
	*-- is returned.  If that's the case, a text file will not be generated,
	*-- so return an empty string, otherwise return the file name with
	*-- text extension.
	lcTextFilename = IIF( UPPER( m.lcTextExtension ) == UPPER( JUSTEXT( m.tcBinaryFilename ) ), ;
			SPACE(0), FORCEEXT( m.tcBinaryFilename, m.lcTextExtension ) )
ENDIF

RETURN m.lcTextFilename
ENDFUNC

*********************************************************************
PROTECTED FUNCTION GetAlternateTextName

*!*	This method determines if an alternate text file name is associated with the specified VFP
*!*	binary file.

*!*	PARAMETERS:
*!*		 tcBinaryFilename (R) -	The name of a VFP binary file for which the name of a text file is
*!*								to be returned.  The file name must include an extension, and the
*!*								extension must be the MAIN extension for that binary file type.  For
*!*								example, for a VFP table, the extension must be .DBF, NOT .CDX or
*!*								.FPT.  Any path information in the file name will be applied to the
*!*								text file name returned.
*!*			 tcRepository (O) -	The path of a repository.  This parameter is not used directly in
*!*			 					this method, but passed on to methods called from here.

*!*	RETURNS: Character
*!*		IF there is no mapping for the specified binary file, returns NULL.  If a mapping is defined,
*!*		but no text file name is specified in the mapping, returns an empty string.  Otherwise, the
*!*		name of the text file associated with the binary file will be returned.
*********************************************************************
LPARAMETERS tcBinaryFilename AS String, tcRepository AS String

LOCAL lcTextFilename, ;
	lnRow

lcTextFilename = SPACE(0)
lcTextFilename = .NULL.

*-- Make sure the alternate text mapping list is populated.
This.GetAlternateTextList( m.tcRepository )

IF ALEN( This.iaAlternateText, 1 ) > 1
	*-- There is at least one custom mapping, so check if it is for the
	*-- specified file.
	lnRow = ASCAN( This.iaAlternateText, JUSTFNAME( m.tcBinaryFilename ), 2, -1, 1, 1+2+4+8 )
ELSE
	*-- There are no custom mappings.
	lnRow = 0
ENDIF

DO CASE
	CASE m.lnRow = 0
		*-- The specified file does not have a custom mapping.

	CASE EMPTY( This.iaAlternateText[m.lnRow,2] )
		*-- The custom mapping for the specified file is that no text
		*-- file is to be generated.
		lcTextFilename = SPACE(0)

	OTHERWISE
		*-- A custom text file name has been specified for this binary
		*-- file.
		lcTextFilename = FORCEPATH( This.iaAlternateText[m.lnRow,2], JUSTPATH( m.tcBinaryFilename ) )
ENDCASE

RETURN m.lcTextFilename
ENDFUNC

*********************************************************************
PROTECTED PROCEDURE GetAlternateTextList

*!*	This method makes sure This.iaAlternateText is populated with alternate text file mappings for
*!*	the specified repository.  The structure of the array is as follows:
*!*		Row 1, Column 1: The full path of the repository that the list is associated with
*!*		Row 1, Column 2: NULL

*!*		For Row 2 and beyond:
*!*		Column 1: The file name (with extension) of a VFP binary file
*!*		Column 2: The file name (with extension) of the text file associated with the binary file
*!*					in column 1.  If this is blank, no text file is being tracked for the binary
*!*					file.

*!*	PARAMETERS:
*!*		 tcRepository (O) -	The path of a repository.  If omitted, it is assumed that the default
*!*							folder is the repository being used.
*********************************************************************
LPARAMETERS tcRepository AS String

LOCAL lcRepository, ;
	lcAlternateTextFilename, ;
	laAlternateTextRaw[1], ;
	lnLineCount, ;
	lnRows, ;
	xx

*-- Get the current repository folder, and format the name.
lcRepository = UPPER( This.GetRepositoryPath( m.tcRepository ) )

*-- The first row of the array stores the name of the repository that
*-- the alternate text mapping list was generated for.  If the list
*-- has already been populated for the specified repository, we're done.
IF VARTYPE( This.iaAlternateText[1] ) = "C" ;
		AND This.iaAlternateText[1] == m.lcRepository
	RETURN
ENDIF

*-- Initialize the mapping list for the current repository.
DIMENSION This.iaAlternateText[1,2]
This.iaAlternateText[1,1] = m.lcRepository
This.iaAlternateText[1,2] = .NULL.

*-- Look for the mapping file.  If it doesn't exist, we're done.
lcAlternateTextFilename = m.lcRepository + This.icAlternateTextFilename
IF NOT FILE( m.lcAlternateTextFilename )
	RETURN
ENDIF

*-- Read the contents of the mapping file into an array for processing.
lnLineCount = ALINES( laAlternateTextRaw, FILETOSTR( m.lcAlternateTextFilename ), 1+4 )
lnRows = 1

FOR xx = 1 TO m.lnLineCount
	*-- If this line begins with a comment character, ignore it.
	IF INLIST( LEFT( laAlternateTextRaw[m.xx], 1 ), "#", "*" )
		LOOP
	ENDIF

	*-- This is a non-empty line with no comment character, so assume
	*-- it defines a file mapping.  Store the binary and text file names.
	lnRows = m.lnRows + 1
	DIMENSION This.iaAlternateText[m.lnRows,2]
	This.iaAlternateText[m.lnRows,1] = JUSTFNAME( ALLTRIM( GETWORDNUM( laAlternateTextRaw[m.xx], 1, "=" ) ) )
	This.iaAlternateText[m.lnRows,2] = JUSTFNAME( ALLTRIM( GETWORDNUM( laAlternateTextRaw[m.xx], 2, "=" ) ) )
ENDFOR

ENDPROC

*********************************************************************
PROTECTED PROCEDURE FetchVFPExtensionMapAlias

*!*	This method populates a cursor with the mapping of all VFP binary file extension to the main
*!*	extension for each set.

*!*	PARAMETERS: None

*!*	RETURNS: Nothing
*********************************************************************
DO CASE
	CASE EMPTY( This.icVFPBinaryExtensionMapAlias )
		*-- The cursor name hasn't been set yet.  Use a default name,
		*-- and assume it still needs to be populated with data.
		This.icVFPBinaryExtensionMapAlias = "C_VFPBinaryFileExtensions" + SYS(2015)

	CASE USED( This.icVFPBinaryExtensionMapAlias ) ;
			AND RECCOUNT( This.icVFPBinaryExtensionMapAlias ) > 0
		*-- The cursor has already been populated, so nothing to do.
		RETURN

	OTHERWISE
		*-- The cursor needs to be populated yet (or again).
ENDCASE

*-- Generate a cursor to map all the binary file extensions to the main
*-- extension for each set.  Create an index for lookups.
CREATE CURSOR ( This.icVFPBinaryExtensionMapAlias ) ;
	( EM_Extension C(3), ;
		EM_MainExtension C(3) )
INDEX ON UPPER( EM_Extension ) TAG EM_EXT CANDIDATE

*-- Store all the binary extensions we want to reference in this class.
INSERT INTO ( This.icVFPBinaryExtensionMapAlias ) ;
	( EM_Extension, EM_MainExtension ) VALUES ( "PJX", "PJX" )
INSERT INTO ( This.icVFPBinaryExtensionMapAlias ) ;
	( EM_Extension, EM_MainExtension ) VALUES ( "PJT", "PJX" )
INSERT INTO ( This.icVFPBinaryExtensionMapAlias ) ;
	( EM_Extension, EM_MainExtension ) VALUES ( "VCX", "VCX" )
INSERT INTO ( This.icVFPBinaryExtensionMapAlias ) ;
	( EM_Extension, EM_MainExtension ) VALUES ( "VCT", "VCX" )
INSERT INTO ( This.icVFPBinaryExtensionMapAlias ) ;
	( EM_Extension, EM_MainExtension ) VALUES ( "SCX", "SCX" )
INSERT INTO ( This.icVFPBinaryExtensionMapAlias ) ;
	( EM_Extension, EM_MainExtension ) VALUES ( "SCT", "SCX" )
INSERT INTO ( This.icVFPBinaryExtensionMapAlias ) ;
	( EM_Extension, EM_MainExtension ) VALUES ( "FRX", "FRX" )
INSERT INTO ( This.icVFPBinaryExtensionMapAlias ) ;
	( EM_Extension, EM_MainExtension ) VALUES ( "FRT", "FRX" )
INSERT INTO ( This.icVFPBinaryExtensionMapAlias ) ;
	( EM_Extension, EM_MainExtension ) VALUES ( "LBX", "LBX" )
INSERT INTO ( This.icVFPBinaryExtensionMapAlias ) ;
	( EM_Extension, EM_MainExtension ) VALUES ( "LBT", "LBX" )
INSERT INTO ( This.icVFPBinaryExtensionMapAlias ) ;
	( EM_Extension, EM_MainExtension ) VALUES ( "MNX", "MNX" )
INSERT INTO ( This.icVFPBinaryExtensionMapAlias ) ;
	( EM_Extension, EM_MainExtension ) VALUES ( "MNT", "MNX" )
INSERT INTO ( This.icVFPBinaryExtensionMapAlias ) ;
	( EM_Extension, EM_MainExtension ) VALUES ( "DBF", "DBF" )
INSERT INTO ( This.icVFPBinaryExtensionMapAlias ) ;
	( EM_Extension, EM_MainExtension ) VALUES ( "CDX", "DBF" )
INSERT INTO ( This.icVFPBinaryExtensionMapAlias ) ;
	( EM_Extension, EM_MainExtension ) VALUES ( "FPT", "DBF" )
INSERT INTO ( This.icVFPBinaryExtensionMapAlias ) ;
	( EM_Extension, EM_MainExtension ) VALUES ( "DBC", "DBC" )
INSERT INTO ( This.icVFPBinaryExtensionMapAlias ) ;
	( EM_Extension, EM_MainExtension ) VALUES ( "DCT", "DBC" )
INSERT INTO ( This.icVFPBinaryExtensionMapAlias ) ;
	( EM_Extension, EM_MainExtension ) VALUES ( "DCX", "DBC" )

ENDPROC

*********************************************************************
PROTECTED FUNCTION GetMainBinaryExtension

*!*	Given any extension associated with a VFP binary file, this method returns the extension of
*!*	the primary file.

*!*	PARAMETERS:
*!*		  tcExtension (R) -	The extension of any VFP binary file.

*!*	RETURNS: Character
*!*		Returns the extension of the primary VFP binary file for the specified binary extension.
*!*		If the passed extension is not a valid extension for a VFP binary file, a blank string
*!*		is returned.
*********************************************************************
LPARAMETERS tcExtension AS String

LOCAL lcExtension, ;
	lcBinaryExtension

lcExtension = UPPER( PADR( m.tcExtension, 3 ) )

*-- Make sure the extension mapping table is populated.
This.FetchVFPExtensionMapAlias()

*-- Lookup the main extension for the specified extension.  If the
*-- extension isn't found, it isn't a valid VFP binary file.
IF SEEK( m.lcExtension, This.icVFPBinaryExtensionMapAlias, "EM_EXT" )
	lcBinaryExtension = EVALUATE( This.icVFPBinaryExtensionMapAlias + ".EM_MainExtension" )
ELSE
	lcBinaryExtension = SPACE(0)
ENDIF

RETURN m.lcBinaryExtension
ENDFUNC

*********************************************************************
PROTECTED FUNCTION ExecCommandVFPBinary

*!*	This method attempts to execute a Git command for the specified VFP binary file.  Since VFP
*!*	binaries are composed of 2 or 3 files, this method attempts to execute the command for all
*!*	the companion files of the "main" binary file as well.

*!*	NOTES:
*!*		This method expects the repository folder to be set as the default folder BEFORE this
*!*		method is called.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*			tcCommand (R) -	The Git command to execute.  This expected to be a command that works
*!*							with individual files AND file masks, such as:
*!*								git reset
*!*								git checkout
*!*								git clean
*!*								git add
*!*		   tcFileName (R) -	The name of the main VFP binary file that the command is to be applied
*!*							to.  The command will be applied to the companion files also.
*!*							Note that a) the case of the file name is assumed to be the same as
*!*							what was used when the file was committed to the repository, and b) the
*!*							companion files are assumed to use the same case as the main file.  If
*!*							either condition is not true (particularly b), then this method will
*!*							need to be enhanced to deal with the case-sensitivity of Git.

*!*	RETURNS: Logical
*!*		.T. if the command executes successfully, .F. otherwise.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcCommand AS String, tcFileName AS String

LOCAL llSuccess, ;
	lcMainExtension, ;
	lcExtensionExpr

llSuccess = .T.

tcFileName = ALLTRIM( m.tcFileName )

*-- Use the extension of the main binary, not the file passed here,
*-- which will allow us to call this method for the "companion" files
*-- as well as the main file.
lcMainExtension = This.GetMainBinaryExtension( JUSTEXT( m.tcFileName ) )

DO CASE
	CASE ( "|" + m.lcMainExtension + "|" ) $ "|VCX|SCX|FRX|LBX|MNX|PJX|"
		*-- These file types all have a single companion file whose
		*-- extension begins with the same first 2 letters, and ends
		*-- in "T", so we handle all of them using the same formula.
		*!* *{ MJP -- 06/04/2015 08:38:38 - Begin
		*!* llSuccess = This.ExecuteCommand( @m.toErrorInfo, .NULL., m.tcCommand + ' -- "' ;
		*!* 		+ LEFT( m.tcFileName, LENC( m.tcFileName ) - 1 ) + '[TtXx]"' )
		*-- In general, the main file and its memo file use the same
		*-- case for their extensions, however, I ran into a couple
		*-- cases where the extension of one file was uppercase and
		*-- the other was lowercase, so we need to account for that in
		*-- the expression for the entire extension.
		lcExtensionExpr = "[" + UPPER( SUBSTR( m.lcMainExtension, 1, 1 ) ) ;
				+ LOWER( SUBSTR( m.lcMainExtension, 1, 1 ) ) + "]" ;
				+ "[" + UPPER( SUBSTR( m.lcMainExtension, 2, 1 ) ) ;
				+ LOWER( SUBSTR( m.lcMainExtension, 2, 1 ) ) + "][TtXx]"

		llSuccess = This.ExecuteCommand( @m.toErrorInfo, .NULL., m.tcCommand + ' -- "' ;
				+ LEFT( m.tcFileName, LENC( m.tcFileName ) - 3 ) + m.lcExtensionExpr + '"' )
		*!* *} MJP -- 06/04/2015 08:38:38 - End

	CASE m.lcMainExtension = "DBC"
		*-- The .DBC is a set of 3 files with a little different naming
		*-- convention.  Explicitly specify the extension for all of
		*-- the files, in case it wasn't the .DBC itself that was passed.
		llSuccess = This.ExecuteCommand( @m.toErrorInfo, .NULL., m.tcCommand + ' -- "' ;
				+ LEFT( m.tcFileName, LENC( m.tcFileName ) - 3 ) + '[Dd][Bb][Cc]"' )
		IF m.llSuccess
			llSuccess = This.ExecuteCommand( @m.toErrorInfo, .NULL., m.tcCommand + ' -- "' ;
					+ LEFT( m.tcFileName, LENC( m.tcFileName ) - 3 ) + '[Dd][Cc][TtXx]"' )
		ENDIF

	CASE m.lcMainExtension = "DBF"
		*-- The .DBF has up to 3 files, which depend on the structure
		*-- of the table.  I don't think we'll need or want to deal
		*-- with DBFs via this utility, so do nothing here.

	OTHERWISE
		*-- This specified file is not one of the expected VFP binaries,
		*-- so do nothing.
ENDCASE

RETURN m.llSuccess
ENDFUNC

*********************************************************************
PROCEDURE SelfTest

*!*	A method for code that can be run to test if this class is working properly.
*********************************************************************
LOCAL lcRepository, ;
	loErrorInfo AS Exception, ;
	lcAlias, ;
	llSuccess, ;
	lcResult, ;
	lcProjectName, ;
	llCleanup

lcRepository = "C:\Work\VFP\Shared\Lib"

lcRepository = GETDIR( m.lcRepository, "Select a Git repository to check its status", ;
		"Select Git Repository", 1+64+512 )
IF EMPTY( m.lcRepository )
	RETURN
ENDIF

lcAlias = SPACE(0)
llSuccess = This.FetchRepoFileList( @m.loErrorInfo, m.lcRepository, @m.lcAlias )

IF m.llSuccess
	WAIT WINDOW "Files in repository '" + m.lcRepository + "'" NOWAIT NOCLEAR
	SELECT ( m.lcAlias )
	BROWSE LAST NOCAPTIONS
	WAIT CLEAR
ELSE
	lcResult = IIF( m.loErrorInfo.ErrorNo = 0, SPACE(0), ;
				"Error " + TRANSFORM( m.loErrorInfo.ErrorNo ) + CHR(13) ) ;
			+ m.loErrorInfo.Message ;
			+ IIF( EMPTY( m.loErrorInfo.LineContents ), SPACE(0), ;
				+ CHR(13) + CHR(13) + "Command:  " + m.loErrorInfo.LineContents )

	MESSAGEBOX( "Repository: " + m.lcRepository + CHR(13) + CHR(13) + m.lcResult, 16, PROGRAM() )
ENDIF

lcAlias = SPACE(0)
llSuccess = This.FetchRepoStatus( @m.loErrorInfo, m.lcRepository, @m.lcAlias )

DO CASE
	CASE NOT m.llSuccess
		lcResult = IIF( m.loErrorInfo.ErrorNo = 0, SPACE(0), ;
					"Error " + TRANSFORM( m.loErrorInfo.ErrorNo ) + CHR(13) ) ;
				+ m.loErrorInfo.Message ;
				+ IIF( EMPTY( m.loErrorInfo.LineContents ), SPACE(0), ;
					+ CHR(13) + CHR(13) + "Command:  " + m.loErrorInfo.LineContents )

	CASE RECCOUNT( m.lcAlias ) = 0
		lcResult = "No changes detected"

	OTHERWISE
		lcResult = TRANSFORM( RECCOUNT( m.lcAlias ) ) + " change(s) detected"
ENDCASE

MESSAGEBOX( "Repository: " + m.lcRepository + CHR(13) + CHR(13) + m.lcResult, ;
		IIF( m.llSuccess, 64, 16 ), PROGRAM() )

IF USED( m.lcAlias ) ;
		AND RECCOUNT( m.lcAlias ) > 0
	SELECT ( m.lcAlias )
	BROWSE LAST NOCAPTIONS
ENDIF

lcProjectName = SPACE(0)
lcAlias = SPACE(0)
llSuccess = This.FetchReposInProject( @m.loErrorInfo, @m.lcProjectName, @m.lcAlias )
IF m.llSuccess
	WAIT WINDOW "Repositories found in " + m.lcProjectName NOWAIT NOCLEAR
	SELECT ( m.lcAlias )
	BROWSE LAST NOCAPTIONS
	WAIT CLEAR
ELSE
	lcResult = "Error " + TRANSFORM( m.loErrorInfo.ErrorNo ) + CHR(13) ;
			+ m.loErrorInfo.Message + CHR(13) + CHR(13) ;
			+ "Command:  " + m.loErrorInfo.LineContents
	MESSAGEBOX( m.lcResult, 16, PROGRAM() )
ENDIF

lcProjectName = SPACE(0)
llCleanup = ( MESSAGEBOX( "Cleanup binaries in the selected project?", 4+32, PROGRAM() ) = 6 )
llSuccess = This.BinaryToTextProject( @m.loErrorInfo, @m.lcProjectName, m.llCleanup )
IF m.llSuccess
	MESSAGEBOX( "Binary to Text successful for " + m.lcProjectName, 64, PROGRAM() )
ELSE
	lcResult = "Error " + TRANSFORM( m.loErrorInfo.ErrorNo ) + CHR(13) ;
			+ m.loErrorInfo.Message + CHR(13) + CHR(13) ;
			+ "Command:  " + m.loErrorInfo.LineContents
	MESSAGEBOX( m.lcResult, 16, PROGRAM() )
ENDIF

ENDPROC

ENDDEFINE


*-- Option classes need to be defined locally, so it doesn't help to
*-- define them here.
*!*	*********************************************************************
*!*	*-- Define master option classes.
*!*	*********************************************************************
*!*	DEFINE CLASS ccOptionClassPreserveTS AS Custom
*!*		Tool = ccToolName
*!*		Key = ccKeyPreserveTimestamps
*!*		Value = ccInitialValuePreserveTS
*!*		EditClassName = [ccEditClassName from Thor_Proc_GitUtilities.PRG]
*!*	ENDDEFINE

*!*	DEFINE CLASS ccOptionClassTSFileName AS Custom
*!*		Tool = ccToolName
*!*		Key = ccKeyTimestampFileName
*!*		Value = ccInitialValueTSFileName
*!*		EditClassName = [ccEditClassName from Thor_Proc_GitUtilities.PRG]
*!*	ENDDEFINE

*********************************************************************
*-- Define the option page for all the Git utilities options.
*********************************************************************
DEFINE CLASS ccEditClassName AS Container

	PROCEDURE Init
		LOCAL loRenderEngine

		loRenderEngine = EXECSCRIPT( _Screen.cThorDispatcher, "Class= OptionRenderEngine" )

		TEXT TO loRenderEngine.cBodyMarkup NOSHOW TEXTMERGE
			.Class = "Label"
			.Caption = "Should file modification dates be saved/restored for all files in Git repositories?  (This setting is ignored when explicitly saving or restoring file timestamps using the corresponding tools.)"
			.Width = 350
			.Left = 25
			.WordWrap = .T.
			|
			.Class = "OptionGroup"
			.cCaptions = "Never save timestamps\\Always save timestamps\\Only save when the timestamp file exists"
			.Left = 50
			.cTool = ccToolName
			.cKey = ccKeyPreserveTimestamps
			|
			.Class = "Label"
			.Caption = "Enter the name of the file where the file modification timestamps will be saved.  The file is created in the repository root, so do not include a path."
			.Width = 350
			.Left = 25
			.WordWrap = .T.
			|
			.Class = "Textbox"
			.Width = 150
			.Left = 50
			.cTool = ccToolName
			.cKey = ccKeyTimestampFileName
		ENDTEXT

		loRenderEngine.Render( This, ccToolName )
	ENDPROC

ENDDEFINE
