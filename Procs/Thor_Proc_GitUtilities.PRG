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
	Michael J. Potjer changed on 10/12/2015 11:37:46 AM
	-	Enhance the FetchRepoStatus() method to allow a pathspec filter to be specified for the
		status list.
	-	Add the AddUntrackedFilesToRepo() method to automatically add any untracked binary files
		and text file associated with a primary VFP binary file in the repository.
		This method is called by the BinaryToTextRepo() method immediately after the cleanup
		process executes.
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
	since Git and Mercurial do not preserve modification dates for the files they track in the
	repository.  The default name for the timestamp file is stored in This.icGitTimestampFilename
	for Git repositories and This.icHgTimestampFilename for Mercurial repositories.  Since the
	file is maintained entirely by this class, its structure is not important, but you can learn
	more in the header comments for This.SaveRepoTimestampFile().  The file is stored in the
	root folder of the repository.

	Alternate Text Mapping File
	===========================
	By default, this class assumes FoxBin2Prg is being used to generate text files corresponding
	with the VFP binary files, and that the text files will use the default FoxBin2Prg extensions.
	However, if some other form of text file is being used for a particular binary file, that can
	be defined in this mapping file.  The default name for this mapping file is defined in
	This.icGitAlternateTextFilename (for Git) and This.icHgAlternateTextFilename (for Mercurial).
	This file must be created in the root folder of the repository.  If an alternate mapping is
	defined for a file, then you are responsible for generating the text file, and this class will
	NOT call FoxBin2Prg to generate a text file for that binary file.  Both file names in the
	mapping MUST include the file extension.  Note that if you don't want ANY text file associated
	with a VFP binary file, then don't enter anything to the right of the equal (=) sign.
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
*-- modification dates of the files in Git repositories.  This was
*-- changed from a constant to a property so that it can be changed at
*-- runtime.
icGitTimestampFilename = ccInitialValueGitTSFileName	&& ".gittimestamp"

*-- Stores the default name of the timestamp file which stores the
*-- modification dates of the files in Mercurial repositories.  This
*-- is a property so that it can be changed at runtime.
icHgTimestampFilename = ccInitialValueHgTSFileName	&& ".hgtimestamp"

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
icGitAlternateTextFilename = ".gitvfpalttext"

*-- Stores the default name of the file which defines alternate text
*-- files to be associated with a VFP binary file in a Git repository.
icHgAlternateTextFilename = ".hgvfpalttext"

*-- This array stores the alternate text file mappings stored in the
*-- file specified by icGitAlternateTextFilename and icHgAlternateTextFilename.
DIMENSION iaAlternateText[1]
iaAlternateText = .NULL.

*-- When we are using the FoxBin2Prg progress bar for our own purpose,
*-- these properties keep track of the last message displayed for each
*-- progress bar.
icProgressBar1LastMessage = ""
icProgressBar2LastMessage = ""
PROTECTED icProgressBar1LastMessage
PROTECTED icProgressBar2LastMessage

*-- These properties keep track of the total count that was specified
*-- for each progress bar.
inProgressBar1TotalCount = 0
inProgressBar2TotalCount = 0
PROTECTED inProgressBar1TotalCount
PROTECTED inProgressBar2TotalCount

*-- These properties keep track of the current item count for each
*-- progress bar.
inProgressBar1LastItem = 0
inProgressBar2LastItem = 0
PROTECTED inProgressBar1LastItem
PROTECTED inProgressBar2LastItem

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

*-- Retrieve the file name to use for the Git timestamp file.  If it's
*-- valid, use it, but make sure it doesn't include any path info.
luValue = EXECSCRIPT( _Screen.cThorDispatcher, "Get Option=", ccKeyGitTimestampFileName, ccToolName )
IF VARTYPE( m.luValue ) = "C" ;
		AND NOT EMPTY( m.luValue )
	This.icGitTimestampFilename = JUSTFNAME( m.luValue )
ENDIF

*-- Retrieve the file name to use for the Mercurial timestamp file.
*-- If it's valid, use it, but make sure it doesn't include any path
*-- info.
luValue = EXECSCRIPT( _Screen.cThorDispatcher, "Get Option=", ccKeyHgTimestampFileName, ccToolName )
IF VARTYPE( m.luValue ) = "C" ;
		AND NOT EMPTY( m.luValue )
	This.icHgTimestampFilename = JUSTFNAME( m.luValue )
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

LOCAL lcCommand, ;
	lcDefaultPath, ;
	lcOutputFile, ;
	llSuccess, ;
	lnReturnError, ;
	loExec AS WSCRIPT.WshExec, ;
	loShell AS WScript.Shell

llSuccess = .T.
tcOutput = SPACE(0)

loShell = CREATEOBJECT( "WScript.Shell" )

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
	*-- There is no easy way to hide the command window using Exec(),
	*-- and possibly no way at all to hide it from VFP, so the Run()
	*-- method is used here.
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
		toErrorInfo.LineContents = m.tcCommand
		toErrorInfo.Details = "Error " + TRANSFORM( m.lnReturnError )
		llSuccess = .F.

		*-- We don't always get error information back from a command,
		*-- so make sure we generate some useful information.
		toErrorInfo.Message = IIF( FILE( m.lcOutputFile ), FILETOSTR( m.lcOutputFile ), SPACE(0) )

		*-- If no error information was collected in the output file,
		*-- re-run the command using Exec(), which will allow us to
		*-- retrieve the output sent to the command window.
		IF EMPTY( m.toErrorInfo.Message )
			 *-- Make sure the Sleep API function is declared, which
			 *-- is used later.
			 IF NOT This.IsAPIDeclared( "Sleep" )
			 	DECLARE Integer Sleep IN WIN32API Integer
			 ENDIF

			*-- Attempt to execute the specified command again, this
			*-- time using the Exec() method.  This will cause a command
			*-- window to flash on the screen, but since we only do
			*-- this when a command has already failed, it shouldn't
			*-- happen very often.
			loExec = m.loShell.Exec( m.lcCommand )

			DO CASE
				CASE NOT m.loExec.StdOut.AtEndOfStream
					*-- The command executed successfully, and generated
					*-- a non-empty output stream.  This is unlikely,
					*-- since the same command failed just before this,
					*-- but save the stream to the output parameter,
					*-- if it was passed, and set the success flag.
					tcOutput = m.loExec.StdOut.ReadAll()
					llSuccess = .T.

				CASE NOT m.loExec.StdErr.AtEndOfStream
					*-- The command failed and generated an error output
					*-- stream.  Save the error in the error object.
					toErrorInfo.Message = m.loExec.StdErr.ReadAll()

				OTHERWISE
					*-- The command succeeded, and there is no output
					*-- to report.  This is unlikely, since the same
					*-- command failed just before this, but set the
					*-- success flag.
					llSuccess = .T.
			ENDCASE

			*-- If the command is still running, wait for it to complete
			*-- before continuing.
			DO WHILE m.loExec.Status = 0
				Sleep( 100 )
			ENDDO
		ENDIF

		*-- Include the command that was executing, and the return value
		*-- from the Run() method in the message.  If we still didn't
		*-- get an error message, generate something generic.
		toErrorInfo.Message = "Error executing command: " + m.tcCommand + CHR(13) + CHR(13) ;
				+ EVL( m.toErrorInfo.Message, "A general error occurred." ) + CHR(13) + CHR(13) ;
				+ "Return Value: " + TRANSFORM( m.lnReturnError )
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
*!*	NOTE: If a tracked file has been deleted, but the deletion has not been staged for commit yet,
*!*	the file will still appear in this list, even though it doesn't exist in the folder.

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

LOCAL lcCommand, ;
	lcFileList, ;
	lcRepoType, ;
	llSuccess

llSuccess = .T.

lcRepoType = This.GetRepoType( m.tcRepository )
DO CASE
	CASE m.lcRepoType = "G"
		*-- Generate the command for retrieving a list of all files
		*-- being tracked by a Git repository.
		lcCommand = "git ls-files"

	CASE m.lcRepoType = "M"
		*-- Generate the command for retrieving a list of all files
		*-- being tracked by a Mercurial repository.
		lcCommand = "hg manifest"

	OTHERWISE
		*-- This folder is not a recognized repository, so generate an
		*-- error message and abort.
		lcCommand = SPACE(0)
		llSuccess = .F.
		TRY
			ERROR "'" + m.tcRepository + "' is not a valid repository folder."
		CATCH TO toErrorInfo
		ENDTRY
ENDCASE

*-- Retrieve the list of files in the directory cache index.
IF m.llSuccess
	llSuccess = This.ExecuteCommand( @m.toErrorInfo, m.tcRepository, m.lcCommand, @m.lcFileList )
ENDIF

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

LOCAL laFileList[1], ;
	lcFileName, ;
	lcFolder, ;
	lcRepository, ;
	llSuccess, ;
	lnFileCount, ;
	loFolder AS SHELL.Folder, ;
	loFolderItem AS SHELL.FolderItem, ;
	loShell AS Shell.Shell, ;
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

*-- We know the maximum size needed for the array, so dimension it
*-- before the loop.
DIMENSION taFileDateList[ALEN( laFileList ), 2]
lnFileCount = 0

FOR xx = 1 TO ALEN( laFileList )
	lcFileName = JUSTFNAME( laFileList[m.xx] )

	*-- Get the full path to the file.  VFP seems to treat forward and
	*-- backslashes the same, but convert them to backslashes for consistency.
	lcFolder = ADDBS( m.lcRepository ) + JUSTPATH( CHRTRAN( laFileList[m.xx], "/", "\" ) )

	*-- Make sure the folder still exists, in case it has been deleted,
	*-- but the deleted files in the folder haven't been staged for
	*-- commit.
	IF NOT DIRECTORY( m.lcFolder )
		LOOP
	ENDIF

	*-- Use the Windows shell object to drill down and get the modification
	*-- date for the current file.
	loFolder = m.loShell.NameSpace( m.lcFolder )
	loFolderItem = m.loFolder.ParseName( m.lcFileName )

	*-- Make sure this file exists.  A deleted file will be in the list
	*-- if the deletion hasn't been staged yet.
	IF ISNULL( loFolderItem )
		LOOP
	ENDIF

	lnFileCount = m.lnFileCount + 1
	taFileDateList[m.lnFileCount,1] = laFileList[m.xx]
	taFileDateList[m.lnFileCount,2] = m.loFolderItem.ModifyDate
ENDFOR

*-- Check the results.
DO CASE
	CASE m.lnFileCount = 0
		*-- There are no files to process.  Clear the results array.
		DIMENSION taFileDateList[1]
		taFileDateList = .NULL.

	CASE m.lnFileCount < ALEN( laFileList )
		*-- Some of the files in the repo list no longer exist, so
		*-- resize the results array.
		DIMENSION taFileDateList[m.lnFileCount,2]

	OTHERWISE
		*-- The results are fine as-is.
ENDCASE

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

LOCAL lcCommand, ;
	lcRepoType, ;
	lcStatusInfo, ;
	llHasChanges, ;
	llSuccess

*-- Determine the type of repository so the appropriate status command
*-- can be used. Retrieve the status using the static parseable format
*-- for the output.
lcRepoType = This.GetRepoType( m.tcRepository )
lcCommand = IIF( m.lcRepoType = "M", "hg status", "git status --porcelain" )
llSuccess = This.ExecuteCommand( @m.toErrorInfo, m.tcRepository, m.lcCommand, @m.lcStatusInfo )

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
FUNCTION IsFileInRepo

*!*	This method determines if the specified file, or its text file if it's a VFP binary file, is
*!*	being tracked by a repository.

*!*	PARAMETERS:
*!*			  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*								this method.  This will be returned as an Exception object.  This
*!*								parameter is not required, but recommended.
*!*			   tcFilePath (R) -	The full path and file name of a file to look for in the list of
*!*								files being tracked by the repository in which the file is located,
*!*								if any.
*!*		  tlCheckTextFile (O) -	If the name of a VFP binary file is specified for tcFilePath, indicates
*!*								whether to check if the corresponding text file is being tracked by a
*!*								repository.  When passed as .T., this method returns .T. if either the
*!*								binary or the text file (or both) is being tracked.  If omitted or
*!*								.F., only the specified file will be checked.  If the specified file
*!*								name is not a type that has a text file associated with it, this
*!*								parameter does nothing.
*!*			 tcRepository (O) -	If a variable is passed by reference to this parameter, and the
*!*								specified file name is being tracked in a repository, then the path
*!*								to the repository will be returned via this parameter.

*!*	RETURNS: Logical
*!*		Returns .T. if the specified file is tracked by a repository, .F. if it is not tracked,
*!*		and .NULL. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcFilePath AS String, tlCheckTextFile AS Boolean, tcRepository AS String

LOCAL laRepoFiles[1], ;
	lcFolderPath, ;
	lcLookupFileName, ;
	lcRepoPath, ;
	llIsInRepo

llIsInRepo = .F.
tcRepository = SPACE(0)

*-- Get the folder containing the file being checked, and determine
*-- if the file is in a repository folder.  If there isn't even a repo
*-- folder, then the file is obviously not being tracked.
lcFolderPath = JUSTPATH( m.tcFilePath )
lcRepoPath = This.GetRepoFolderForPath( @m.toErrorInfo, m.lcFolderPath )
IF EMPTY( m.lcRepoPath )
	RETURN m.llIsInRepo
ENDIF

*-- Attempt to retrieve a list of the files in the repository where the
*-- specified file is located.
laRepoFiles = .NULL.
DO CASE
	CASE NOT This.GetRepoFileList( @m.toErrorInfo, m.lcRepoPath, @laRepoFiles )
		*-- An error occurred retrieving the file list, so abort.
		RETURN .NULL.

	CASE ISNULL( laRepoFiles[1] )
		*-- There are no files tracked by the repository, so the file
		*-- cannot be tracked.
		RETURN m.llIsInRepo

	OTHERWISE
		*-- Continue on and check if the file is being tracked.
ENDCASE

*-- Get the path to the file relative to the repository path.  Convert
*-- any backslashes (\) to forward slashes (/) to match the way paths
*-- are separated in Git file list.
lcLookupFileName = STRTRAN( m.tcFilePath, ADDBS( m.lcRepoPath ), SPACE(0), 1, 1, 1 )
lcLookupFileName = CHRTRAN( m.lcLookupFileName, "\", "/" )

*-- Lookup the specified file name in the list of files tracked by the
*-- repository.
llIsInRepo = ( ASCAN( laRepoFiles, m.lcLookupFileName, 1, -1, 1, 1+2+4 ) > 0 )

IF NOT m.llIsInRepo ;
		AND VARTYPE( m.tlCheckTextFile ) = "L" ;
		AND m.tlCheckTextFile
	*-- The specified file is not being tracked, but we also need to
	*-- check if a corresponding text file is being tracked.  Get the
	*-- name of the text file, if any.  Make sure backslashes are converted
	*-- again, and check if the text file is being tracked.
	lcLookupFileName = This.GetTextFilename( m.lcLookupFileName, m.lcRepoPath )
	IF NOT EMPTY( m.lcLookupFileName )
		lcLookupFileName = CHRTRAN( m.lcLookupFileName, "\", "/" )
		llIsInRepo = ( ASCAN( laRepoFiles, m.lcLookupFileName, 1, -1, 1, 1+2+4 ) > 0 )
	ENDIF
ENDIF

*-- If the file is being tracked, store the repository path in the
*-- parameter to return to the calling code.
IF m.llIsInRepo
	tcRepository = m.lcRepoPath
ENDIF

RETURN m.llIsInRepo
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
*!*	Git or Hg repository.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*		 tcRepository (O) -	The full path to the repository folder whose status information is to
*!*							be retrieved.  If omitted, the current folder will be used as the
*!*							repository.
*!*		 tcCursorName (O) -	The name to use for the cursor that returns the status info for the
*!*							repository.  It is not required to specify a cursor name, but if no
*!*							name is specified, a variable should be passed here by reference to
*!*							receive the name of the cursor generated.
*!*			 tcFilter (O) -	A valid Git pathspec or Hg pattern that will be used to filter the results
*!*							of the status cursor.

*!*	RETURNS: Logical
*!*		Returns true if the status of the repository can be successfully determined, otherwise
*!*		returns .F.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String, tcCursorName AS String, tcFilter AS String

LOCAL laLines[1], ;
	lcFileExtension, ;
	lcFileName, ;
	lcIndexStatus, ;
	lcOldFileName, ;
	lcPathSpec, ;
	lcRepoType, ;
	lcStatusInfo, ;
	lcWorkTreeStatus, ;
	llMergeConflict, ;
	llSuccess, ;
	lnCount, ;
	xx

tcCursorName = IIF( VARTYPE( m.tcCursorName ) = "C" AND NOT EMPTY( m.tcCursorName ), ;
		ALLTRIM( m.tcCursorName ), "C_RepoStatusResults" )
USE IN SELECT( m.tcCursorName )

*-- Determine the type of repository being processed.
lcRepoType = This.GetRepoType( m.tcRepository )

*-- If a filter was specified, use it as the pathspec for the status
*-- command.
lcPathSpec = IIF( VARTYPE( m.tcFilter ) = "C" AND NOT EMPTY( m.tcFilter ), SPACE(1) + m.tcFilter, SPACE(0) )

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
*--		GS_MergeConflict  -	Indicates whether there is a merge conflict for this file.
CREATE CURSOR ( m.tcCursorName ) ;
	( GS_FileName V(254), ;
		GS_OldFileName V(254), ;
		GS_FileExtension C(10), ;
		GS_IndexStatus C(1), ;
		GS_WorkTreeStatus C(1), ;
		GS_MergeConflict L )

*-- Retrieve the status using the static parseable format for the output.
*-- Add any pathspec specified by the calling code.
IF m.lcRepoType = "M"
	*-- This is a Mercurial repository.  The pathspec should work the
	*-- same as Git.
	llSuccess = This.ExecuteCommand( @m.toErrorInfo, m.tcRepository, "hg status " + m.lcPathSpec, ;
			@m.lcStatusInfo )
ELSE
	*-- This is (presumably) a Git repository.
	llSuccess = This.ExecuteCommand( @m.toErrorInfo, m.tcRepository, ;
			"git status --porcelain" + m.lcPathSpec, @m.lcStatusInfo )
ENDIF

*-- If the status command failed, or there are no changes to report,
*-- then there's nothing more to do here.
IF NOT m.llSuccess ;
		OR EMPTY( m.lcStatusInfo )
	RETURN m.llSuccess
ENDIF

*-- The status for each file is on a separate line.
lnCount = ALINES( laLines, m.lcStatusInfo, 4 )

FOR xx = 1 TO m.lnCount
	IF m.lcRepoType = "M"
		*-- Mercurial repository
		*-- Hg only has one status code, so treat it like a "staged"
		*-- change, and convert it to an equivalent Git status code.
		lcIndexStatus = LEFT( laLines[m.xx], 1 )
		lcIndexStatus = ICASE( m.lcIndexStatus = "R", "D", ;
				m.lcIndexStatus = "I", "!", ;
				INLIST( m.lcIndexStatus, "C", "!" ), SPACE(1), ;
				m.lcIndexStatus )

		*-- The file name follows the status, separated by a space.
		lcFileName = ALLTRIM( SUBSTR( laLines[m.xx], 2 ) )

		*-- Hg doesn't have an "unstaged" status, so we'll treat all
		*-- files as "staged", except for untracked files (?).  Store
		*-- the untracked status in both fields, so that methods that
		*-- deal with untracked files can handle Hg the same as Git.
		lcWorkTreeStatus = IIF( m.lcIndexStatus = "?", "?", SPACE(1) )

		*-- Merge conflicts appear to be handled differently, so I'm
		*-- not going to try to determine that.
		llMergeConflict = .F.

		*-- File renames don't have their own status code, and I don't
		*-- know how to reliably determine that a rename occurred, so
		*-- just leave the old file name blank.
		lcOldFileName = SPACE(0)
	ELSE
		*-- Git repository
		*-- The first 2 characters are the status codes.
		lcIndexStatus = LEFT( laLines[m.xx], 1 )
		lcWorkTreeStatus = SUBSTR( laLines[m.xx], 2, 1 )

		*-- Check for a merge conflict on this item.  See the git status
		*-- documentation for an explanation of what these codes mean.
		llMergeConflict = INLIST( m.lcIndexStatus + m.lcWorkTreeStatus, "DD", "AU", "UD", "UA", "DU", "AA", "UU" )

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
			GS_WorkTreeStatus, ;
			GS_MergeConflict ) ;
		VALUES ;
		( m.lcFileName, ;
			m.lcOldFileName, ;
			UPPER( m.lcFileExtension ), ;
			m.lcIndexStatus, ;
			m.lcWorkTreeStatus, ;
			m.llMergeConflict )
ENDFOR

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION GetRepoType

*!*	This method attempts to determine if the specified folder is a repository, and if so, what type
*!*	of repository (Git or Mercurial).

*!*	PARAMETERS:
*!*		 tcRepository (O) -	The full path to the repository folder whose repo type is to be retrieved.
*!*							If omitted, the current folder will be used as the repository.

*!*	RETURNS: Character
*!*		"G" if the folder is a Git repository, "M" for a Mercurial repository, or a blank string if
*!*		the folder is not a (recognized) repository.
*********************************************************************
LPARAMETERS tcRepository AS String

LOCAL lcRepoType, ;
	lcRepository

lcRepoType = SPACE(0)
lcRepository = This.GetRepositoryPath( m.tcRepository )

DO CASE
	CASE DIRECTORY( m.lcRepository + ".Git", 1 )
		*-- The current folder contains the .Git folder (which is normally
		*-- hidden), so this must be a Git repository.
		lcRepoType = "G"

	CASE DIRECTORY( m.lcRepository + ".Hg", 1 )
		*-- The current folder contains the .Hg folder, which indicates
		*-- this is a Mercurial repository.  Mercurial doesn't appear
		*-- to hide its folder by default, but allow for that possibility
		*-- here.
		lcRepoType = "M"

	OTHERWISE
		*-- This folder is not a repository that is recognized here.
ENDCASE

RETURN m.lcRepoType
ENDFUNC

*********************************************************************
FUNCTION GetRepoFolderForPath

*!*	This method determines the Git or Hg repository folder, if any, for the specified folder.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*		 tcFolderPath (R) -	The full path of a folder for which you want to determine the repository
*!*							folder that it belongs to, if any.
*!*		   tcRepoType (O) -	A variable passed by reference to store the type of repository for the
*!*							specified folder.  This returns the same value as This.GetRepoType(),
*!*							and will be blank if the specified folder is not in a repository.

*!*	RETURNS: Character
*!*		Returns the full path to the repository if one is found, otherwise returns an empty string.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcFolderPath AS String, tcRepoType AS String

LOCAL lcFolderPath, ;
	lcRepoFolder, ;
	lcRepoType

lcRepoFolder = SPACE(0)
tcRepoType = SPACE(0)
lcFolderPath = ADDBS( m.tcFolderPath )

DO WHILE OCCURS( "\", m.lcFolderPath ) > 1
	*-- Check if the current folder is a repository.
	lcRepoType = This.GetRepoType( m.lcFolderPath )
	IF EMPTY( m.lcRepoType )
		*-- This folder is not a repository, so check if the parent
		*-- folder is.  Note that although subfolders can be omitted
		*-- from a repository, it will generally be safe to assume that
		*-- any folder that is in the project will be managed by the
		*-- repository of a parent folder.
		lcFolderPath = LEFT( m.lcFolderPath, RAT( "\", m.lcFolderPath, 2 ) )
	ELSE
		*-- The current folder is a repository.  Store the folder and
		*-- and the repository type.
		lcRepoFolder = ALLTRIM( m.lcFolderPath )
		tcRepoType = m.lcRepoType
		EXIT
	ENDIF
ENDDO

RETURN m.lcRepoFolder
ENDFUNC

*********************************************************************
FUNCTION GetRepoStatistics

*!*	This method populates a data object with some statistics about the specified repository.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*		 tcRepository (O) -	The full path to the repository folder whose statistics are to be
*!*							retrieved.  If omitted, the current folder will be used as the repository.

*!*	RETURNS: Object
*!*		If an error occurs, returns NULL, otherwise returns a data object containing statistics for
*!*		the specified repository.

*!*		The properties of the data object are:
*!*			StagedChanges	  -	The total number of all changes that are staged for commit.  This
*!*								includes files that have merge conflicts.
*!*			UnstagedChanges	  -	The total number of all changes that are being tracked by the repository,
*!*								but are not staged for commit.  This includes files that have merge
*!*								conflicts.
*!*			UntrackedItems	  -	The total number of items that are not being tracked by the repository,
*!*								but are not in any ignore list.
*!*			MergeConflicts	  -	If a merge is in effect on the repository, this will contain the total
*!*								number of merge conflicts that have not be resolved.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String

LOCAL lcAggregateAlias, ;
	lcStatusAlias, ;
	lnWorkArea, ;
	loGitStats

lcStatusAlias = "C_GitRepoStatus" + SYS(2015)
lcAggregateAlias = "C_GitRepoStatistics" + SYS(2015)

lnWorkArea = SELECT()

IF This.FetchRepoStatus( @m.toErrorInfo, m.tcRepository, m.lcStatusAlias )
	TRY
		*-- Gather statistics about the items in the repository.  There
		*-- are 6 codes that indicate some kind of change to a tracked
		*-- item, and only 3 status values that indicate something else,
		*-- so I went with the shorter list for some of these.
		SELECT SUM( IIF( INLIST( GS_IndexStatus, "?", "!", " " ), 0, 1 ) ) AS StagedChanges, ;
				SUM( IIF( INLIST( GS_WorkTreeStatus, "?", "!", " " ), 0, 1 ) ) AS UnstagedChanges, ;
				SUM( IIF( GS_IndexStatus = "?" OR GS_WorkTreeStatus = "?", 1, 0 ) ) AS UntrackedItems, ;
				SUM( IIF( GS_MergeConflict, 1, 0 ) ) AS MergeConflicts ;
			FROM ( m.lcStatusAlias ) ;
			INTO CURSOR ( m.lcAggregateAlias ) NOFILTER

		SELECT ( m.lcAggregateAlias )

		*-- If the status cursor contains no items, the aggregate cursor
		*-- will only contain NULL values, so generate a BLANK data
		*-- object instead, which is a more accurate result.
		*-- Note that we could just create an object and add empty
		*-- properties to it when there is no status data, but that
		*-- code would be more complicated to maintain if we ever change
		*-- the stats that are being gathered.
		IF RECCOUNT( m.lcStatusAlias ) = 0
			SCATTER BLANK NAME m.loGitStats
		ELSE
			SCATTER NAME m.loGitStats
		ENDIF

	CATCH TO toErrorInfo
		*-- Abort if an error occurs getting the aggregate amounts.
		loGitStats = .NULL.
	ENDTRY
ELSE
	*-- The repository status could not be retrieved, so abort.
	loGitStats = .NULL.
ENDIF

*-- Cleanup cursors created here.
USE IN SELECT( m.lcStatusAlias )
USE IN SELECT( m.lcAggregateAlias )

SELECT ( m.lnWorkArea )

RETURN m.loGitStats
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

LOCAL lcAliasRoot, ;
	lcBranchName, ;
	lcCommand, ;
	lcFolderPath, ;
	lcProjectAlias, ;
	lcProjectFoldersAlias, ;
	lcProjectName, ;
	lcRepoFolder, ;
	lcRepoType, ;
	lcSQL, ;
	llSuccess, ;
	loRepoStatistics

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

lcAliasRoot = CHRTRANC( JUSTSTEM( m.lcProjectName ), SPACE(1), "_" )
lcProjectAlias = m.lcAliasRoot + "_PJX" + SYS(2015)
lcProjectFoldersAlias = m.lcAliasRoot + "_Folders" + SYS(2015)

*-- Generate the query to retrieve all the data paths represented in
*-- the specified project.
*-- Add a field for the repository type.
TEXT TO m.lcSQL TEXTMERGE NOSHOW
	SELECT DISTINCT ;
			CAST( ADDBS( JUSTPATH( FULLPATH( Name, "<<m.lcProjectName>>" ) ) ) AS V(254) ) ;
				AS PF_FolderPath, ;
			CAST( SPACE(0) AS V(254) ) AS PF_RepositoryFolder, ;
			CAST( SPACE(0) AS C(1) ) AS PF_RepositoryType ;
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

	*-- If the macro-expansion failed, copy the query we were trying
	*-- to execute into the line contents.  Note that VFP gets confused
	*-- if the ampersand isn't separated from the rest of the string,
	*-- and thinks it's dealing with a macro-expansion instead of a
	*-- string.
	IF LOWER( ALLTRIM( m.toErrorInfo.LineContents ) ) = "&" + "lcsql."
		toErrorInfo.LineContents = m.lcSQL
	ENDIF
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

		*-- Check if a repository exists in this folder, or one of its
		*-- parent folders.  If so, save it.
		lcRepoFolder = This.GetRepoFolderForPath( @m.toErrorInfo, m.lcFolderPath, @m.lcRepoType )
		IF NOT EMPTY( m.lcRepoFolder )
			REPLACE PF_RepositoryFolder WITH ALLTRIM( m.lcRepoFolder ), ;
					PF_RepositoryType WITH m.lcRepoType ;
					IN ( m.lcProjectFoldersAlias )
		ENDIF
	ENDSCAN

	*-- There are likely multiple project folders that are included in
	*-- the same repository, so consolidate the repository folders list.
	*-- Add a field to store the current branch for each repo, and make
	*-- the cursor read/write so we can populate the field.
	*-- Add fields to store some statistics about each repository,
	*-- making this cursor a little more useful for getting an overview
	*-- of the status of the project.
	*-- Include the repository type in the results, and we can check
	*-- if that has a value, rather than the folder field.
	SELECT DISTINCT PF_RepositoryFolder, ;
			PF_RepositoryType, ;
			CAST( SPACE(0) AS V(254) ) AS PF_CurrentBranch, ;
			CAST( .NULL. AS I ) AS PF_StagedChanges, ;
			CAST( .NULL. AS I ) AS PF_UnstagedChanges, ;
			CAST( .NULL. AS I ) AS PF_MergeConflicts, ;
			CAST( .NULL. AS I ) AS PF_UntrackedItems ;
		FROM ( m.lcProjectFoldersAlias ) ;
		WHERE NOT EMPTY( PF_RepositoryType ) ;
		INTO CURSOR ( m.tcCursorName ) READWRITE

	IF RECCOUNT( m.tcCursorName ) > 0
		*-- There are repositories in the project, so look up the current
		*-- branch for each one.
		SELECT ( m.tcCursorName )
		GO TOP
		SCAN
			*-- Determine the command needed to retrieve the name of
			*-- the current branch in the repository.
			*-- The Git command retrieves the name of the current branch,
			*-- as long as you're not in a detached HEAD state, otherwise
			*-- you just get "HEAD", which will at least be a clue that
			*-- something probably needs to be done with that repo.
			lcCommand = IIF( EVALUATE( m.tcCursorName + ".PF_RepositoryType" ) = "M", ;
					"hg branch", "git rev-parse --abbrev-ref HEAD" )

			IF This.ExecuteCommand( .NULL., PF_RepositoryFolder, m.lcCommand, @m.lcBranchName )
				REPLACE PF_CurrentBranch WITH RTRIM( m.lcBranchName ) ;
						IN ( m.tcCursorName )
			ENDIF

			*-- Attempt to get some stats for the current repository.
			*-- If this fails, leave the statistic fields set to their
			*-- default value of NULL to indicate that the information
			*-- could not be retrieved.  We won't abort this method if
			*-- the stats can't be retrieved, though.
			loRepoStatistics = This.GetRepoStatistics( .NULL., PF_RepositoryFolder )
			IF NOT ISNULL( m.loRepoStatistics )
				REPLACE PF_StagedChanges WITH m.loRepoStatistics.StagedChanges, ;
						PF_UnstagedChanges WITH m.loRepoStatistics.UnstagedChanges, ;
						PF_MergeConflicts WITH m.loRepoStatistics.MergeConflicts, ;
						PF_UntrackedItems WITH m.loRepoStatistics.UntrackedItems ;
						IN ( m.tcCursorName )
			ENDIF
		ENDSCAN
		GO TOP
	ENDIF
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
	lcCleanupAlias, ;
	lcFullFileName, ;
	lcMainExtension, ;
	lcMessage, ;
	lcRelativeFileName, ;
	lcRepository, ;
	llCleanupModified, ;
	llHasChanges, ;
	llSuccess, ;
	lnFileCount, ;
	lnFileNumber, ;
	loProjects

llSuccess = .T.

*-- Make sure all projects are closed before processing.
loProjects = CREATEOBJECT( "colPushPopProjects" )

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

	*-- Use our message method and a progress bar to provide nicer
	*-- feedback.
	This.ShowMessage( "Converting Binary to Text for Repository:" + CHR(13) + m.lcRepository )
	This.LoadProgressBar()
	lnFileNumber = 0
	lnFileCount = RECCOUNT( m.lcChangesAlias )

	*-- Process the VFP binary files that have changed.
	SELECT ( m.lcChangesAlias )
	GO TOP
	SCAN
		*-- Increment a counter used for the progress bar.
		lnFileNumber = m.lnFileNumber + 1

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

		lcMessage = "Processing file: " + m.lcRelativeFileName
		This.UpdateProgressBar( m.lcMessage, m.lnFileNumber, m.lnFileCount, 1 )

		IF NOT This.ConvertVFPFile( @m.toErrorInfo, m.lcFullFileName, m.lcRepository )
			llSuccess = .F.
			EXIT
		ENDIF

		*-- If cleanup is being performed, check if the current file
		*-- needs to be added to the list of files to check.  So far,
		*-- .VCX and .FRX are the only files I've seen changed by a
		*-- recompile.  This list should be updated to add any others
		*-- we find.
		*-- It seems that .SCX files can also be affected.
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

This.ReleaseProgressBar()
This.ClearMessage()

*-- If there were changes to process, and cleanup was specified, pass
*-- the cursor to the cleanup method processing.
IF m.llSuccess ;
		AND m.llHasChanges ;
		AND m.llCleanupModified
	llSuccess = This.CleanupVFPBinaries( @m.toErrorInfo, m.lcCleanupAlias, m.tcRepository )

	USE IN SELECT( m.lcCleanupAlias )
ENDIF

*-- If there are any VFP binary files that are not being tracked, but
*-- have a text file being tracked in the repo, regenerate those text
*-- files.
IF m.llSuccess
	llSuccess = This.BinaryToTextForTextOnlyRepo( @m.toErrorInfo, m.tcRepository )
ENDIF

*-- If no errors occurred, and there were changes to process, then add
*-- any untracked files which should be included with the tracked files.
*-- This ensures that all the binaries that go together, and the text
*-- files generated for them, are all committed together.  It also
*-- ensures that timestamps are generated for all of them, if timestamps
*-- are being saved.
IF m.llSuccess ;
		AND m.llHasChanges
	llSuccess = This.AddUntrackedFilesToRepo( @m.toErrorInfo, m.tcRepository )
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

LOCAL lcDefaultPath, ;
	lcMainFileName, ;
	lcMessage, ;
	lcRelativeFileName, ;
	lcRepoType, ;
	lcRepository, ;
	lcStatusAlias, ;
	lcTextFileName, ;
	llStaged, ;
	llSuccess, ;
	lnFileCount, ;
	lnFileNumber

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
	*-- Use the message method and a progress bar to provide nicer
	*-- feedback.
	This.ShowMessage( "Cleaning up Binary files for Repository:" + CHR(13) + m.lcRepository )
	This.LoadProgressBar()
	lnFileNumber = 0
	lnFileCount = RECCOUNT( m.tcFileListAlias )

	*-- Get the type of repository, which is needed to generate the
	*-- appropriate command to undo file changes.
	lcRepoType = This.GetRepoType( m.lcRepository )

	*-- Scan the cleanup list to confirm whether changes should be
	*-- undone for any of the files.
	SELECT ( m.tcFileListAlias )
	GO TOP
	SCAN WHILE m.llSuccess
		lcRelativeFileName = EVALUATE( m.tcFileListAlias + ".CB_FileName" )
		lnFileNumber = m.lnFileNumber + 1
		lcMessage = "Checking file: " + m.lcRelativeFileName
		This.UpdateProgressBar( m.lcMessage, m.lnFileNumber, m.lnFileCount, 1 )

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
		*-- We only need the staged flag for a Git repository.
		IF m.lcRepoType = "G"
			llStaged = ( EVALUATE( m.lcStatusAlias + ".GS_IndexStatus" ) = "M" )
		ELSE
			llStaged = .F.
		ENDIF

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
		lcMessage = "Restoring file: " + m.lcRelativeFileName
		This.UpdateProgressBar( m.lcMessage, m.lnFileNumber )

		*-- If the binary file was staged, we need to unstage it.
		IF m.llStaged
			llSuccess = This.ExecCommandVFPBinary( @m.toErrorInfo, "git reset", m.lcRelativeFileName )
		ENDIF

		DO CASE
			CASE NOT m.llSuccess
				*-- Something already failed.

			CASE m.lcRepoType = "M"
				*-- In Mercurial, revert the change on the current
				*-- revision, and don't create a backup (.orig) file.
				llSuccess = This.ExecCommandVFPBinary( @m.toErrorInfo, "hg revert -C", m.lcRelativeFileName )

			OTHERWISE
				*-- In Git, checkout the last version of the file for
				*-- the most recent commit in the current working tree.
				llSuccess = This.ExecCommandVFPBinary( @m.toErrorInfo, "git checkout", m.lcRelativeFileName )
		ENDCASE
	ENDSCAN

	*-- If timestamps are being saved, restore the modification dates
	*-- for all the files that have just been reverted, or that were
	*-- not changed at all.
	DO CASE
		CASE NOT m.llSuccess ;
				OR NOT This.AreTimestampsPreserved( m.lcRepository )
			*-- Something failed, or timestamps are not preserved, so
			*-- nothing to do.

		CASE NOT FILE( ADDBS( m.lcRepository ) + This.GetTimestampFileName( .NULL., m.lcRepository ) )
			*-- Timestamps are being preserved, but there is no file
			*-- yet, so nothing to restore.

		OTHERWISE
			*-- Attempt to restore the timestamps.
			llSuccess = This.RestoreRepoTimestamps( @m.toErrorInfo )
	ENDCASE

	This.ReleaseProgressBar()
	This.ClearMessage()
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
	llBin2TxtSelectedProject, ;
	llSuccess, ;
	loProjects AS "colPushPopProjects"

llSuccess = .T.
llBin2TxtSelectedProject = .F.

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

	CASE NVL( This.IsFileInRepo( @m.toErrorInfo, m.tcProjectName, .T. ), .F. )
		*-- The project file is already in the repository, so it will
		*-- be processed with the rest of the files in the repo.

	OTHERWISE
		*-- There is a list of repositories to process.
		*-- The project file isn't in the repository, so the text file
		*-- needs to be generated.
		llBin2TxtSelectedProject = .T.
ENDCASE

*-- Save and close all open projects.
loProjects = CREATEOBJECT( "colPushPopProjects" )

DO CASE
	CASE NOT m.llBin2TxtSelectedProject
		*-- The text file for the project will be generated with the
		*-- rest of the files, so nothing to do here.

	CASE NOT This.BinaryToTextProjectFile( @m.toErrorInfo, m.tcProjectName )
		*-- The text file for the project itself could not be updated,
		*-- so abort.
		RETURN .F.

	OTHERWISE
		*-- The text file was successfully generated.
ENDCASE

*-- For each repository represented in the project, generate text files
*-- for all the VFP binary files that have changed.
SELECT ( m.lcRepoListAlias )
GO TOP
SCAN
	IF NOT This.BinaryToTextRepo( @m.toErrorInfo, PF_RepositoryFolder, m.tlCleanupModified )
		llSuccess = .F.
		EXIT
	ENDIF
ENDSCAN

USE IN SELECT( m.lcRepoListAlias )

RETURN m.llSuccess
ENDFUNC

*********************************************************************
PROTECTED FUNCTION BinaryToTextForTextOnlyRepo

*!*	If there are VFP binary files that are not being tracked in the specified repository, but there
*!*	are text files for those binary files (typically with a .??2 extension) that ARE being tracked,
*!*	then this method will regenerate those text files.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from this
*!*							method.  This will be returned as an Exception object.  This parameter is
*!*							not required, but recommended.
*!*		 tcRepository (O) -	The path of the repository where the binary files are to be processed.  If
*!*							omitted, the current repository will be used.

*!*	RETURNS: Logical
*!*		Returns .T. if there is nothing to do, or the binary files are successfully processed.
*!*		Returns .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String

LOCAL laBinaryFiles[1], ;
	laFileTimestampInfo[1], ;
	laTextFiles[1], ;
	lcBinaryExtension, ;
	lcBinaryFileName, ;
	lcFolder, ;
	lcFullFileName, ;
	lcJustFileName, ;
	lcMessage, ;
	lcRepoFilesAlias, ;
	lcRepository, ;
	lcTextExtension, ;
	lcTextExtensionsAlias, ;
	llSuccess, ;
	llTimestampsMatch, ;
	lnFileCount, ;
	loBinaryFile AS SHELL.FolderItem, ;
	loFolder AS SHELL.Folder, ;
	loShell AS Shell.Shell, ;
	ltFileTimestamp, ;
	xx, ;
	yy

llSuccess = .T.

lcRepository = This.GetRepositoryPath( m.tcRepository )

*-- Get a list of all the files tracked in the repository.
lcRepoFilesAlias = "C_RepositoryFileList" + SYS(2015)
llSuccess = This.FetchRepoFileList( @m.toErrorInfo, m.lcRepository, m.lcRepoFilesAlias )

*-- If something failed, or there are no files in this repository,
*-- there's nothing to do here.
IF NOT m.llSuccess ;
		OR RECCOUNT( m.lcRepoFilesAlias ) = 0
	RETURN m.llSuccess
ENDIF

*-- Retrieve the list of text extensions and Bin2Prg settings for the
*-- specified repository.
lcTextExtensionsAlias = SPACE(0)
IF NOT This.FetchTextExtensionList( @m.toErrorInfo, m.lcRepository, @m.lcTextExtensionsAlias )
	RETURN .F.
ENDIF

*-- Make sure the list of VFP binary extensions is populated.
This.FetchVFPExtensionMapAlias()

*-- Get a Windows shell object to read/set the modification dates.
loShell = CREATEOBJECT( "Shell.Application" )

This.LoadProgressBar()

SELECT ( m.lcTextExtensionsAlias )
SCAN
	*-- Determine the text extension used for binary files in the current
	*-- repository.  Note that although each subfolder could use a
	*-- different extension, we will assume you didn't do anything that
	*-- crazy, and that the correct extension can be determined at the
	*-- repository root level.  We will also assume that the repository
	*-- root level specifies which text files will allow conversion to
	*-- binary.
	IF EVALUATE( m.lcTextExtensionsAlias + ".TE_SupportsBin2Prg" ) = .T.
		lcTextExtension = EVALUATE( m.lcTextExtensionsAlias + ".TE_TextExtension" )
		lcBinaryExtension = EVALUATE( m.lcTextExtensionsAlias + ".TE_VFPExtension" )
	ELSE
		*-- Text files aren't being generated for this file type in
		*-- this repository.
		LOOP
	ENDIF

	DIMENSION laTextFiles[1]
	laTextFiles = .NULL.

	*-- Get a list of just the text files for the current VFP file type.
	SELECT GL_FileName ;
		FROM ( m.lcRepoFilesAlias ) ;
		WHERE RTRIM( GL_FileExtension ) == m.lcTextExtension ;
		INTO ARRAY laTextFiles

	*-- If there are no text files for binary files of this type that
	*-- are committed to the repository, skip to the next type.
	lnFileCount = _TALLY
	IF m.lnFileCount = 0
		LOOP
	ENDIF

	DIMENSION laBinaryFiles[1]
	laBinaryFiles = .NULL.

	*-- Get a list of any VFP binary files tracked in the repository.
	SELECT GL_FileName ;
		FROM ( m.lcRepoFilesAlias ) ;
		WHERE RTRIM( GL_FileExtension ) == m.lcBinaryExtension ;
		INTO ARRAY laBinaryFiles

	This.ShowMessage( "Generating ." + m.lcTextExtension + " files for ." + m.lcBinaryExtension ;
			+ " files in repository:" + CHR(13) + m.lcRepository )

	*-- Initialize an array that will be used to track timestamp info
	*-- for the current file being processed.  The first column stores
	*-- all of the extensions associated with the current file type.
	*-- The second column will store the relative path and file name
	*-- of the binary file.  The third column will store the Windows
	*-- shell file object for the file, but since we can't define a
	*-- column as an object data type, just cast it as string.
	SELECT EM_Extension, ;
			CAST( .NULL. AS V(120) ), ;
			CAST( .NULL. AS C(1) ) ;
		FROM ( This.icVFPBinaryExtensionMapAlias ) ;
		WHERE EM_MainExtension = m.lcBinaryExtension ;
		INTO ARRAY laFileTimestampInfo

	*-- Generate all the text files.
	FOR xx = 1 TO m.lnFileCount
		*-- FoxBin2Prg takes control of the progress bar when it's
		*-- available, so the only thing we can really control is the
		*-- progress displayed in the first bar.  We'll use that to
		*-- give the user feedback on progress for the current file
		*-- type.
		lcMessage = "Generating file: " + laTextFiles[m.xx]
		This.UpdateProgressBar( m.lcMessage, m.xx, m.lnFileCount, 1 )

		*-- Get the full path to the VFP file corresponding to this
		*-- text file.
		lcBinaryFileName = FORCEEXT( CHRTRAN( ADDBS( m.lcRepository ) + laTextFiles[m.xx], "/", "\" ), ;
				m.lcBinaryExtension )

		DO CASE
			CASE NOT FILE( m.lcBinaryFileName )
				*-- The binary file doesn't exist, so there's nothing
				*-- to process.  Evidently the text file has not been
				*-- converted back to a binary yet.
				LOOP

			CASE NOT ISNULL( laBinaryFiles[1] ) ;
					AND ASCAN( laBinaryFiles, FORCEEXT( laTextFiles[m.xx], m.lcBinaryExtension ), ;
						1, -1, 1, 1+2+4 ) > 0
				*-- This repository is tracking binary files, and the
				*-- binary file for this specific text file is being
				*-- tracked in the repo.  The text file will be regenerated
				*-- by This.BinaryToTextRepo(), so no need to deal with
				*-- it again here.
				LOOP

			OTHERWISE
		ENDCASE

		lcJustFileName = JUSTFNAME( laTextFiles[m.xx] )

		*-- Get the full folder name and normalize it to backslashes.
		lcFolder = ADDBS( m.lcRepository ) + JUSTPATH( CHRTRAN( laTextFiles[m.xx], "/", "\" ) )
		loFolder = m.loShell.NameSpace( m.lcFolder )

		*-- Get the timestamp for the text file.
		loBinaryFile = m.loFolder.ParseName( lcJustFileName )
		ltFileTimestamp = IIF( ISNULL( m.loBinaryFile ), .NULL., m.loBinaryFile.ModifyDate )

		llTimestampsMatch = .T.

		*-- Set the relative path and file name for each of the binary
		*-- files that will be generated for the current text file, and
		*-- get the Windows shell file object reference.
		FOR yy = 1 TO ALEN( laFileTimestampInfo, 1 )
			laFileTimestampInfo[m.yy,2] = FORCEEXT( m.lcJustFileName, laFileTimestampInfo[m.yy,1] )

			loBinaryFile = m.loFolder.ParseName( laFileTimestampInfo[m.yy,2] )
			laFileTimestampInfo[m.yy,3] = m.loBinaryFile

			*-- If the text file doesn't exist, or a file with this
			*-- binary extension does not exist (which shouldn't be
			*-- the case), or the binary file's timestamp does not
			*-- match the timestamp saved for the text file, then the
			*-- text file needs to be (re)generated for the current
			*-- binary file.
			IF ISNULL( m.ltFileTimestamp ) ;
					OR ISNULL( m.loBinaryFile ) ;
					OR NOT m.loBinaryFile.ModifyDate = m.ltFileTimestamp
				llTimestampsMatch = .F.
			ENDIF
		ENDFOR

		*-- If the timestamps of the text file and all of the binary
		*-- files are exactly the same, then assume they are all in
		*-- synch.
		IF m.llTimestampsMatch
			LOOP
		ENDIF

		*-- Get the full path of the main binary file.  Note that FULLPATH()
		*-- normalizes any forward slashes (/) in the path to backslashes
		*-- (\).
		lcFullFileName = FULLPATH( ADDBS( m.lcRepository ) + FORCEEXT( laTextFiles[m.xx], m.lcBinaryExtension ) )

		*-- Attempt to generate the text file.
		IF NOT This.ConvertVFPFile( @m.toErrorInfo, m.lcFullFileName, m.lcRepository )
			llSuccess = .F.
			EXIT
		ENDIF

		*-- Get the timestamp for the text file, which will have changed
		*-- if the text file has been updated.
		loBinaryFile = m.loFolder.ParseName( lcJustFileName )
		ltFileTimestamp = IIF( ISNULL( m.loBinaryFile ), .NULL., m.loBinaryFile.ModifyDate )

		IF NOT ISNULL( m.ltFileTimestamp )
			*-- We have a timestamp, so attempt to set the modification
			*-- date of the binary files to match, so that if this
			*-- process runs again, we can determine this file was
			*-- already processed, and we can skip it.  If a timestamp
			*-- file is used for the repo, this is the modification
			*-- date that will be stored in the timestamp file when
			*-- that is updated by This.SaveRepoTimestampFile().  This
			*-- modification date will also be checked by
			*-- This.RegenerateRepoBinaries() to determine if the text
			*-- file and binaries match.
			FOR yy = 1 TO ALEN( laFileTimestampInfo, 1 )
				loBinaryFile = laFileTimestampInfo[m.yy,3]

				*-- If the binary file did not exist earlier (unlikely!),
				*-- then we might not have a reference to it, so try
				*-- again to get one now.
				IF ISNULL( m.loBinaryFile )
					loBinaryFile = m.loFolder.ParseName( laFileTimestampInfo[m.yy,2] )
				ENDIF

				*-- If we have a reference to the binary file, set the
				*-- modification timestamp of the binary file to match
				*-- the text file.
				IF NOT ISNULL( m.loBinaryFile )
					loBinaryFile.ModifyDate = m.ltFileTimestamp
				ENDIF
			ENDFOR
		ENDIF
	ENDFOR
ENDSCAN

This.ReleaseProgressBar()
This.ClearMessage()

USE IN SELECT( m.lcRepoFilesAlias )

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

LOCAL lcProjectName, ;
	llSuccess, ;
	loProjects

*-- Make sure we have the full path to the project to process.  If the
*-- project cannot be determined, abort.
lcProjectName = This.GetProjectName( @m.toErrorInfo, m.tcProjectName )
IF EMPTY( m.lcProjectName )
	RETURN .F.
ENDIF

llSuccess = .T.

*-- Check if the specified project is open, because we can't generate
*-- the text file if it is.
*-- Ordinarily, all projects will now be closed before this method is
*-- called, but this method is not protected, so it could conceivably
*-- be called in a context where the project file is still open.
loProjects = CREATEOBJECT( "colPushPopProjects" )

*-- Generate the text file for the project.
llSuccess = This.ConvertVFPFile( @m.toErrorInfo, m.lcProjectName )

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

LOCAL laFileList[1], ;
	lcFileContent, ;
	lcFilename, ;
	lcFullFileName, ;
	lcRepository, ;
	llSuccess, ;
	lnFileCount, ;
	lnListCount, ;
	lnRow, ;
	ltTimestamp, ;
	xx

llSuccess = .T.

lcRepository = This.GetRepositoryPath( m.tcRepository )

lcFullFileName = ADDBS( m.lcRepository ) + This.GetTimestampFileName( m.tcFileName, m.lcRepository )

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

	*-- Keep a separate count of the number of files added to the list.
	lnListCount = 0

	*-- Extract the file name and timestamp from the temporary array,
	*-- converting the timestamp to a date/time data type.
	FOR xx = 1 TO m.lnFileCount
		lcFilename = GETWORDNUM( laFileList[m.xx], 2, CHR(9) )
		ltTimestamp = EVALUATE( "{^" + GETWORDNUM( laFileList[m.xx], 1, CHR(9) ) + "}" )

		*-- Check if this file name already exists in the list.  This
		*-- is to correct a list that may have had duplicate file names
		*-- added to it, possibly during a merge.
		lnRow = ASCAN( taFileDateList, m.lcFilename, 1, -1, 1, 1+2+4+8 )

		DO CASE
			CASE m.lnRow = 0
				*-- The file isn't in the list yet, so add it.
				lnListCount = m.lnListCount + 1
				taFileDateList[m.lnListCount,1] = m.lcFilename
				taFileDateList[m.lnListCount,2] = m.ltTimestamp

			CASE taFileDateList[m.lnRow,2] < m.ltTimestamp
				*-- The file already exists, but has an older timestamp.
				*-- We will assume that the more recent timestamp is
				*-- probably the correct one.
				taFileDateList[m.lnRow,2] = m.ltTimestamp

			OTHERWISE
				*-- The file already exists, and doesn't require any
				*-- changes.
		ENDCASE
	ENDFOR

	*-- If the list contains fewer items than what was read from the
	*-- file, reduce the size of the array.
	IF m.lnListCount < m.lnFileCount
		DIMENSION taFileDateList[m.lnListCount,2]
	ENDIF
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

LOCAL laFileDateList[1], ;
	laFilesToIgnore[1], ;
	lcFileContent, ;
	lcFileName, ;
	lcFolder, ;
	lcFullFileName, ;
	lcOldFileContent, ;
	lcRepository, ;
	lcStatusAlias, ;
	lcTimestampFileName, ;
	llSuccess, ;
	lnFileCount, ;
	lnRow, ;
	loFolder AS SHELL.Folder, ;
	loFolderItem AS SHELL.FolderItem, ;
	loShell AS Shell.Shell, ;
	xx

lcRepository = This.GetRepositoryPath( m.tcRepository )

*-- Make sure a file name is specified.
lcTimestampFileName = This.GetTimestampFileName( m.tcFileName, m.lcRepository )

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
	*-- file, or our alternate text mapping files.
	DIMENSION laFilesToIgnore[4]
	laFilesToIgnore[1] = m.lcTimestampFileName
	laFilesToIgnore[2] = ".gitignore"
	laFilesToIgnore[3] = This.icGitAlternateTextFilename
	laFilesToIgnore[4] = This.icHgAlternateTextFilename

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
		*-- originally contained data, clear it.
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
	IF NOT This.SaveRepoTimestampFile( @m.toErrorInfo, PF_RepositoryFolder )
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

LOCAL laFileDateList[1], ;
	lcFileName, ;
	lcFolder, ;
	lcRepository, ;
	lcStatusAlias, ;
	llSuccess, ;
	lnFileCount, ;
	lnRow, ;
	loFolder AS SHELL.Folder, ;
	loFolderItem AS SHELL.FolderItem, ;
	loShell AS Shell.Shell

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

		*-- Make sure the folder still exists, in case it was deleted
		*-- after the timestamp file was created.
		IF NOT DIRECTORY( m.lcFolder )
			LOOP
		ENDIF

		*-- Get a shell object reference to the file.
		loFolder = m.loShell.NameSpace( m.lcFolder )
		loFolderItem = m.loFolder.ParseName( m.lcFileName )

		DO CASE
			CASE ISNULL( m.loFolderItem )
				*-- The current file specified in the timestamp list
				*-- no longer exists, so ignore it.

			CASE m.loFolderItem.ModifyDate = laFileDateList[m.lnRow, 2]
				*-- The file modification timestamp hasn't changed, so
				*-- leave it alone.

			OTHERWISE
				*-- The current modification date of this file is different
				*-- from what was saved, so replace it.
				loFolderItem.ModifyDate = laFileDateList[m.lnRow, 2]
		ENDCASE
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
	IF NOT This.RestoreRepoTimestamps( @m.toErrorInfo, PF_RepositoryFolder )
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

LOCAL lcMessage, ;
	lcRepoListAlias, ;
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
	*-- For now, don't allow tagging Mercurial repositories.
	IF PF_RepositoryType = "M"
		LOOP
	ENDIF

	*-- Attempt to tag the current repository.  An unsigned annotated
	*-- tag (-a) will be created, and if the tag already exists it will
	*-- be replaced (-f).  If we decide to make these options configurable
	*-- in the future, properties can be added to the class for that.
	IF NOT This.ExecuteCommand( @m.toErrorInfo, PF_RepositoryFolder, ;
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
	lcTagList, ;
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

*-- For each repository represented in the project, delete the specified
*-- tag, if it exists.
SELECT ( m.lcRepoListAlias )
GO TOP
SCAN
	lcTagList = SPACE(0)

	*-- For now, don't allow untagging Mercurial repositories.
	IF PF_RepositoryType = "M"
		LOOP
	ENDIF

	*-- Attempt to lookup the specified tag in the current repository.
	DO CASE
		CASE NOT This.ExecuteCommand( @m.toErrorInfo, PF_RepositoryFolder, ;
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

		CASE This.ExecuteCommand( @m.toErrorInfo, PF_RepositoryFolder, "git tag -d " + m.tcTag )
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

LOCAL lcChangesAlias, ;
	llSuccess

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
	llSuccess, ;
	loProjects

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

*-- Make sure any open projects are closed before processing files.
loProjects = CREATEOBJECT( "colPushPopProjects" )

*-- Process each repository represented in the project.
SELECT ( m.lcRepoListAlias )
GO TOP
SCAN
	IF NOT This.PostCheckoutProcessRepo( @m.toErrorInfo, PF_RepositoryFolder )
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

LOCAL laTimestampList[1], ;
	lcFileListAlias, ;
	llSuccess, ;
	loProjects

*-- If this method was called directly, make sure all open projects
*-- are closed before processing.
loProjects = CREATEOBJECT( "colPushPopProjects" )

*-- Make sure we have a unique name of the file list cursor, and that
*-- there are no prior instances open with with name.
lcFileListAlias = "C_GitRepoFileList" + SYS(2015)
USE IN SELECT( m.lcFileListAlias )

*-- Initialize the timestamp list array to be passed to the methods
*-- that are regenerating and recompiling files.
laTimestampList = .NULL.

*-- Make sure all binary files are in synch with their corresponding
*-- text file.
llSuccess = This.RegenerateRepoBinaries( @m.toErrorInfo, m.tcRepository, @m.lcFileListAlias, ;
		@m.laTimestampList )

*-- Make sure the program and object code files for all .MNX menu files
*-- are updated.
IF m.llSuccess
	llSuccess = This.RegenerateRepoMenus( @m.toErrorInfo, m.tcRepository, @m.lcFileListAlias, ;
			@laTimestampList )
ENDIF

*-- Make sure the object code for all program files is updated.
IF m.llSuccess
	llSuccess = This.RecompileRepoProgramFiles( @m.toErrorInfo, m.tcRepository, @m.lcFileListAlias, ;
			@laTimestampList )
ENDIF

*-- Restore file timestamps for all repository files, if applicable.
IF m.llSuccess ;
		AND This.AreTimestampsPreserved( m.tcRepository )
	llSuccess = This.RestoreRepoTimestamps( @m.toErrorInfo, m.tcRepository )
ENDIF

USE IN SELECT( m.lcFileListAlias )

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION RegenerateRepoBinaries

*!*	This method regenerates the VFP binary files for any corresponding text files committed to the
*!*	specified Git/Hg repository.  If the binary files are not committed to a repository, this method
*!*	ensures that those binary files are regenerated to match any text file versions which have been
*!*	checked out.

*!*	PARAMETERS:
*!*			  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*								this method.  This will be returned as an Exception object.  This
*!*								parameter is not required, but recommended.
*!*			 tcRepository (O) -	The full path to the repository folder where binary files are to be
*!*								regenerated.  If omitted, the current folder will be used as the
*!*								repository.
*!*		  tcFileListAlias (O) -	The alias of the cursor containing a list of all the files in the
*!*								specified repository.  If omitted or there is no cursor open with
*!*								the specified name, the file list will be retrieved here, and the
*!*								cursor name stored in this parameter.  The calling code can delegate
*!*								the task of retrieving the list to this method by passing a variable
*!*								to this parameter by reference, then it will have access to the
*!*								cursor afterward.
*!*		  taTimestampList (O) -	An array variable passed by reference, which is either already
*!*								populated with timestamp data by This.ReadRepoTimestampFile(), or
*!*								is to be populated with those values by this method.  If omitted,
*!*								the timestamp array will still be populated by this method, if
*!*								applicable.

*!*	RETURNS: Logical
*!*		.T. if all binary files are successfully regenerated, or if there are no binary files to
*!*		regenerate, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String, tcFileListAlias AS String, taTimestampList

LOCAL laBinaryFileList[1], ;
	laFileTimestampInfo[1], ;
	laTextFileList[1], ;
	lcBinaryExtension, ;
	lcFolder, ;
	lcFullFileName, ;
	lcJustFileName, ;
	lcMessage, ;
	lcRepository, ;
	lcTextExtension, ;
	lcTextExtensionsAlias, ;
	lcVFPExtensionProcessingOrder, ;
	llSuccess, ;
	llTimestampsMatch, ;
	lnBinaryTypeCount, ;
	lnFileCount, ;
	lnFileType, ;
	lnRow, ;
	loFile AS SHELL.FolderItem, ;
	loFolder AS SHELL.Folder, ;
	loProjects, ;
	loShell AS Shell.Shell, ;
	ltFileTimestamp, ;
	xx, ;
	yy

EXTERNAL ARRAY taTimestampList

*-- Since this method isn't protected, and could be called directly,
*-- make sure all projects are closed before processing.
loProjects = CREATEOBJECT( "colPushPopProjects" )

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

*-- Make sure the list of VFP binary extensions is populated.
This.FetchVFPExtensionMapAlias()

*-- Retrieve the list of text extensions and Bin2Prg settings for the
*-- specified repository.
lcTextExtensionsAlias = SPACE(0)
IF NOT This.FetchTextExtensionList( @m.toErrorInfo, m.lcRepository, @m.lcTextExtensionsAlias )
	RETURN .F.
ENDIF

*-- Make sure the timestamp list parameter is defined as an array.
IF NOT TYPE( "taTimestampList", 1 ) = "A"
	DIMENSION taTimestampList[1]
	taTimestampList = .NULL.
ENDIF

*-- If no timestamp list was specified, and timestamps are preserved
*-- by this repository, then attempt to get the timestamp list.
IF ISNULL( taTimestampList[1] ) ;
		AND This.AreTimestampsPreserved( m.lcRepository )
	*-- Note that we will not abort if we can't get the timestamp list.
	This.ReadRepoTimestampFile( @m.toErrorInfo, m.lcRepository, .NULL., @taTimestampList )
ENDIF

*-- Get a Windows shell object to set the modification dates.  Note
*-- that dates will be set even if a timestamp file is not used, so we
*-- can tell if this process has been run earlier.
loShell = CREATEOBJECT( "Shell.Application" )

This.ShowMessage( "Regenerating binaries for repository:" + CHR(13) + m.lcRepository )
This.LoadProgressBar()

*-- Specify the list of binaries to process, in the order to process
*-- them.  Note that VCX is first, in case there are SCX forms that
*-- need to reference the classes in the VCX files.  PJX files are last,
*-- so that any files they reference will exist.  The other files are
*-- rather arbitrarily sorted.
lcVFPExtensionProcessingOrder = "VCX,SCX,MNX,FRX,LBX,DBC,DBF,PJX"
lnBinaryTypeCount = GETWORDCOUNT( m.lcVFPExtensionProcessingOrder, "," )

*-- Process each type of binary file.
FOR lnFileType = 1 TO m.lnBinaryTypeCount
	lcBinaryExtension = GETWORDNUM( m.lcVFPExtensionProcessingOrder, m.lnFileType, "," )

	*-- Determine the text extension used for binary files in the current
	*-- repository.  Note that although each subfolder could use a
	*-- different extension, we will assume you didn't do anything that
	*-- crazy, and that the correct extension can be determined at the
	*-- repository root level.  We will also assume that the repository
	*-- root level specifies which text files will allow conversion to
	*-- binary.
	IF SEEK( m.lcBinaryExtension, m.lcTextExtensionsAlias, "TE_EXT" ) ;
			AND EVALUATE( m.lcTextExtensionsAlias + ".TE_SupportsPrg2Bin" ) = .T.
		lcTextExtension = EVALUATE( m.lcTextExtensionsAlias + ".TE_TextExtension" )
	ELSE
		*-- Either there is no text extension for this file type, or
		*-- you aren't generating text files for it in this repository.
		LOOP
	ENDIF

	*-- Retrieve a list of the text files generated for the binary files
	*-- in this repository folder.
	SELECT GL_FileName ;
		FROM ( m.tcFileListAlias ) ;
		WHERE UPPER( RTRIM( GL_FileExtension ) ) == m.lcTextExtension ;
		INTO ARRAY laTextFileList

	*-- If there are no text files for binary files of this type that
	*-- are committed to the repository, skip to the next type.
	lnFileCount = _TALLY
	IF m.lnFileCount = 0
		LOOP
	ENDIF

	DIMENSION laBinaryFileList[1]
	laBinaryFileList = .NULL.

	*-- Retrieve a list of any VFP binaries being tracked for the current
	*-- binary file type.  This is needed to determine whether binaries
	*-- should be generated for a particular file.
	SELECT GL_FileName ;
		FROM ( m.tcFileListAlias ) ;
		WHERE UPPER( RTRIM( GL_FileExtension ) ) == m.lcBinaryExtension ;
		INTO ARRAY laBinaryFileList

	*-- Initialize an array that will be used to track timestamp info
	*-- for the current file being processed.  The first column stores
	*-- all of the extensions associated with the current file type.
	*-- The second column will store the relative path and file name
	*-- of the binary file.  The third column will store the Windows
	*-- shell file object for the file, but since we can't define a
	*-- column as an object data type, just cast it as string.
	SELECT EM_Extension, ;
			CAST( .NULL. AS V(120) ), ;
			CAST( .NULL. AS C(1) ) ;
		FROM ( This.icVFPBinaryExtensionMapAlias ) ;
		WHERE EM_MainExtension = m.lcBinaryExtension ;
		INTO ARRAY laFileTimestampInfo

	*-- Regenerate all the binary files.
	FOR xx = 1 TO m.lnFileCount
		*-- FoxBin2Prg takes control of the progress bar when it's
		*-- available, so the only thing we can really control is the
		*-- progress displayed in the first bar.  We'll use that to
		*-- give the user feedback on progress for the current file
		*-- type.
		lcMessage = "Regenerating file: " + laTextFileList[m.xx]
		This.UpdateProgressBar( m.lcMessage, m.xx, m.lnFileCount, 1 )

		*-- If a VFP binary file is being tracked for the current text
		*-- file, then there is no need to regenerate binaries, so skip
		*-- this file.
		IF NOT ISNULL( laBinaryFileList[1] ) ;
				AND ASCAN( laBinaryFileList, FORCEEXT( laTextFileList[m.xx], m.lcBinaryExtension ), ;
					1, -1, 1, 1+2+4 ) > 0
			LOOP
		ENDIF

		lcJustFileName = JUSTFNAME( laTextFileList[m.xx] )

		*-- Get the full folder name and normalize it to backslashes.
		lcFolder = ADDBS( m.lcRepository ) + JUSTPATH( CHRTRAN( laTextFileList[m.xx], "/", "\" ) )
		loFolder = m.loShell.NameSpace( m.lcFolder )

		*-- Set the relative path and file name for each of the binary
		*-- files that will be generated for the current text file, and
		*-- make sure the Windows shell file object reference is reset.
		FOR yy = 1 TO ALEN( laFileTimestampInfo, 1 )
			laFileTimestampInfo[m.yy,2] = FORCEEXT( m.lcJustFileName, laFileTimestampInfo[m.yy,1] )
			laFileTimestampInfo[m.yy,3] = .NULL.
		ENDFOR

		DO CASE
			CASE NOT ISNULL( taTimestampList[1] )
				*-- Lookup the timestamp for the current text file.  If
				*-- one was found, store it.
				lnRow = ASCAN( taTimestampList, laTextFileList[m.xx], 1, -1, 1, 1+2+4+8 )
				ltFileTimestamp = IIF( m.lnRow > 0, taTimestampList[m.lnRow,2], .NULL. )

			CASE NOT ISNULL( m.loFolder )
				*-- There are no timestamps available, but we have a
				*-- folder object, so lookup the file object and use
				*-- its current modification date.  It is virtually
				*-- impossible for the binaries to have the same date
				*-- and time as the text file unless we set those values
				*-- here.
				loFile = m.loFolder.ParseName( lcJustFileName )
				ltFileTimestamp = IIF( ISNULL( m.loFile ), .NULL., m.loFile.ModifyDate )

			OTHERWISE
				*-- We can't get a timestamp for the text file.
				ltFileTimestamp = .NULL.
		ENDCASE

		IF ISNULL( ltFileTimestamp )
			*-- There is no timestamp, so nothing to check.
		ELSE
			llTimestampsMatch = .T.

			FOR yy = 1 TO ALEN( laFileTimestampInfo, 1 )
				*-- Get a shell object reference to the binary files
				*-- that will be generated.
				loFile = m.loFolder.ParseName( laFileTimestampInfo[m.yy,2] )
				laFileTimestampInfo[m.yy,3] = m.loFile

				*-- If a file with this extension does not exist yet,
				*-- or its timestamp does not match the timestamp saved
				*-- for the text file, then the binaries need to be
				*-- regenerated for the current text file.
				IF ISNULL( m.loFile ) ;
						OR NOT m.loFile.ModifyDate = m.ltFileTimestamp
					llTimestampsMatch = .F.

					*-- Don't bother to check the rest of the binary
					*-- files for this type.  If a file object isn't
					*-- created here, it will get created later if it
					*-- is needed.
					EXIT
				ENDIF
			ENDFOR

			*-- If all the binary files have the same timestamp as the
			*-- text file, assume the binary files do not need to be
			*-- regenerated and skip this file.
			IF m.llTimestampsMatch
				LOOP
			ENDIF
		ENDIF

		*-- Get the full path of the current file.  Note that FULLPATH()
		*-- normalizes any forward slashes (/) in the path to backslashes
		*-- (\), which will be important when accessing the Projects
		*-- collection below.
		lcFullFileName = FULLPATH( ADDBS( m.lcRepository ) + laTextFileList[m.xx] )

		*-- Attempt to regenerate the binary files.
		IF NOT This.ConvertVFPFile( @m.toErrorInfo, m.lcFullFileName, m.lcRepository, .T. )
			llSuccess = .F.
			EXIT
		ENDIF

		IF NOT ISNULL( m.ltFileTimestamp )
			*-- We have a timestamp, so attempt to set the modification
			*-- date of the generated binary files.
			FOR yy = 1 TO ALEN( laFileTimestampInfo, 1 )
				loFile = laFileTimestampInfo[m.yy,3]

				*-- If the binary file did not exist earlier, or didn't
				*-- need to be checked, then we might not have a reference
				*-- to it, so try again to get one now.
				IF ISNULL( m.loFile )
					loFile = m.loFolder.ParseName( laFileTimestampInfo[m.yy,2] )
				ENDIF

				*-- If we have a reference to the binary file, set the
				*-- modification timestamp of the binary file to match
				*-- the text file.
				IF NOT ISNULL( m.loFile )
					loFile.ModifyDate = m.ltFileTimestamp
				ENDIF
			ENDFOR
		ENDIF
	ENDFOR	&& xx = 1 TO ALEN( laTextFileList, 1 )

	*-- If something failed in the file processing, abort the rest of
	*-- this process.
	IF NOT m.llSuccess
		EXIT
	ENDIF
ENDFOR	&& lnFileType = 1 TO OCCURS( ",", m.lcVFPExtensionProcessingOrder ) + 1

This.ReleaseProgressBar()
This.ClearMessage()

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION RegenerateRepoMenus

*!*	This method makes sure that the menu code files (.MPR/.MPX) for any menu files committed to the
*!*	specified repository are regenerated or recompiled.  This method does NOT regenerate the menu
*!*	binary files (.MNX/.MNT), so This.RegenerateRepoBinaries() must be called before calling this
*!*	method.
*!*	-	If both the .MPR and .MPX file for a menu are tracked in the repository, then this method
*!*		will skip that menu.
*!*	-	If just the .MPR file is tracked in the repository, it will be recompiled to generate the
*!*		.MPX file.
*!*	-	If neither file is tracked in the repository, this method will call This.GenerateMenuCode()
*!*		to regenerate the .MPR file and recompile it.

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
*!*		  taTimestampList (O) -	An array variable passed by reference, which is either already
*!*								populated with timestamp data by This.ReadRepoTimestampFile(), or
*!*								is to be populated with those values by this method.  If omitted,
*!*								the timestamp array will still be populated by this method, if
*!*								applicable.

*!*	RETURNS: Logical
*!*		.T. if all menu code files are successfully regenerated, or if there are no menu files to
*!*		regenerate, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String, tcFileListAlias AS String, taTimestampList

EXTERNAL ARRAY taTimestampList

LOCAL laMenuFileList[1], ;
	laTextFileList[1], ;
	lcFolder, ;
	lcFullFileName, ;
	lcJustFileName, ;
	lcMessage, ;
	lcRepository, ;
	lcTextExtension, ;
	llRecompileMPR, ;
	llSuccess, ;
	lnRow, ;
	loFile AS SHELL.FolderItem, ;
	loFolder AS SHELL.Folder, ;
	loMNXItem AS SHELL.FolderItem, ;
	loMPRItem AS SHELL.FolderItem, ;
	loMPXItem AS SHELL.FolderItem, ;
	loShell AS Shell.Shell, ;
	ltFileTimestamp, ;
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

*-- Lookup the text extension specified for menu files in this repository.
lcTextExtension = This.GetTextExtension( "MNX", m.lcRepository )

DIMENSION laTextFileList[1]
laTextFileList = .NULL.

*-- Retrieve a list of the menu text files in this repository folder.
SELECT GL_FileName ;
	FROM ( m.tcFileListAlias ) ;
	WHERE UPPER( RTRIM( GL_FileExtension ) ) == m.lcTextExtension ;
	INTO ARRAY laTextFileList

*-- There are no menu files that are committed to the repository, so
*-- nothing to do here.
IF ISNULL( laTextFileList[1] )
	RETURN m.llSuccess
ENDIF

DIMENSION laMenuFileList[1]
laMenuFileList = .NULL.

*-- Retrieve a list of the menu files in this repository folder.
SELECT GL_FileName ;
	FROM ( m.tcFileListAlias ) ;
	WHERE UPPER( LEFT( GL_FileExtension, 3 ) ) IN ( "MNX", "MPR", "MPX" ) ;
	INTO ARRAY laMenuFileList

*-- Make sure the timestamp list parameter is defined as an array.
IF NOT TYPE( "taTimestampList", 1 ) = "A"
	DIMENSION taTimestampList[1]
	taTimestampList = .NULL.
ENDIF

*-- If no timestamp list was specified, and timestamps are preserved
*-- by this repository, then attempt to get the timestamp list.
IF ISNULL( taTimestampList[1] ) ;
		AND This.AreTimestampsPreserved( m.lcRepository )
	*-- Note that we will not abort if we can't get the timestamp list.
	This.ReadRepoTimestampFile( @m.toErrorInfo, m.lcRepository, .NULL., @taTimestampList )
ENDIF

*-- Get a Windows shell object to set the modification dates, even if
*-- a timestamp file is not used.
loShell = CREATEOBJECT( "Shell.Application" )


*********************************************************************
*-- Regenerate all the menu code.
*********************************************************************
lcMessage = "Regenerating menu code files for repository:" + CHR(13) ;
		+ m.lcRepository + CHR(13) ;
		+ "Regenerating menu: "

FOR xx = 1 TO ALEN( laTextFileList, 1 )
	This.ShowMessage( m.lcMessage + FORCEEXT( laTextFileList[m.xx], "MNX" ) )

	*-- Get the full folder name and normalize it to backslashes.
	lcFolder = ADDBS( m.lcRepository ) + JUSTPATH( CHRTRAN( laTextFileList[m.xx], "/", "\" ) )
	loFolder = m.loShell.NameSpace( m.lcFolder )

	lcJustFileName = JUSTFNAME( laTextFileList[m.xx] )

	*-- Check for the .MNX file.  There's nothing to do if this file
	*-- hasn't been generated yet.
	loMNXItem = m.loFolder.ParseName( FORCEEXT( m.lcJustFileName, "MNX" ) )

	llRecompileMPR = .F.
	DO CASE
		CASE ISNULL( m.loMNXItem )
			*-- The .MNX file doesn't exist yet, so nothing to do.
			LOOP

		CASE ISNULL( laMenuFileList[1] )
			*-- There are no menu binary files in the repository, so
			*-- the program file needs to be regenerated.

		CASE ASCAN( laMenuFileList, FORCEEXT( laTextFileList[m.xx], "MPR" ), 1, -1, 1, 1+2+4 ) = 0
			*-- The .MPR isn't being tracked in the repository, so it
			*-- needs to be regenerated.

		CASE ASCAN( laMenuFileList, FORCEEXT( laTextFileList[m.xx], "MPX" ), 1, -1, 1, 1+2+4 ) = 0
			*-- The .MPR was being tracked, but the .MPX file is not,
			*-- so the .MPR file needs to be recompiled.
			llRecompileMPR = .T.

		OTHERWISE
			*-- Both the .MPR and .MPX files are being tracked, so
			*-- nothing to do for this menu.
			LOOP
	ENDCASE

	IF m.llRecompileMPR
		*********************************************************************
		*-- The .MPR file is tracked in the repo, so it check if it needs to
		*-- be recompiled.
		*********************************************************************
		IF ISNULL( taTimestampList[1] )
			*-- There are no timestamps available, so just use the
			*-- current modification date of the .MPR file to check if
			*-- the file needs to be recompiled.
			loFile = m.loFolder.ParseName( FORCEEXT( m.lcJustFileName, "MPR" ) )
			ltFileTimestamp = IIF( ISNULL( m.loFile ), .NULL., m.loFile.ModifyDate )
		ELSE
			*-- Lookup the timestamp for the current .MPR file.  If a
			*-- timestamp was found for it, store it.
			lnRow = ASCAN( taTimestampList, FORCEEXT( laTextFileList[m.xx], "MPR" ), 1, -1, 1, 1+2+4+8 )
			ltFileTimestamp = IIF( m.lnRow > 0, taTimestampList[m.lnRow,2], .NULL. )
		ENDIF

		IF ISNULL( m.ltFileTimestamp )
			*-- There's no .MPR timestamp to compare, so no need to
			*-- retrieve the .MPX modification date.
			loMPXItem = .NULL.
		ELSE
			*-- Lookup the .MPX file for this menu.  If its modification
			*-- date matches the .MPR file, there's no need to compile
			*-- it.
			loMPXItem = m.loFolder.ParseName( FORCEEXT( m.lcJustFileName, "MPX" ) )

			IF NOT ISNULL( m.loMPXItem ) ;
					AND m.loMPXItem.ModifyDate = m.ltFileTimestamp
				LOOP
			ENDIF
		ENDIF

		*-- Get the full path of the .MPR file, and attempt to compile
		*-- it.  Note that FULLPATH() normalizes any forward slashes
		*-- (/) in the path to backslashes (\).
		lcFullFileName = FULLPATH( ADDBS( m.lcRepository ) + FORCEEXT( laTextFileList[m.xx], "MPR" ) )
		TRY
			COMPILE ( m.lcFullFileName )

		CATCH TO toErrorInfo
			llSuccess = .F.
		ENDTRY

		IF m.llSuccess ;
				AND NOT ISNULL( m.ltFileTimestamp )
			*-- The .MPX file was compiled, and the .MPR file had a
			*-- timestamp that we want to copy to the .MPX file. If
			*-- the .MPX file did not exist earlier, then we might not
			*-- have a reference to it, so try again to get one now.
			IF ISNULL( m.loMPXItem )
				loMPXItem = m.loFolder.ParseName( FORCEEXT( m.lcJustFileName, "MPX" ) )
			ENDIF

			*-- If we have a reference to the .MPX file, set the modification
			*-- timestamp of the .MPX file to match the .MNX file.
			IF NOT ISNULL( m.loMPXItem )
				loMPXItem.ModifyDate = m.ltFileTimestamp
			ENDIF
		ENDIF
	ELSE
		*********************************************************************
		*-- The .MPR file is not tracked in the repository, so it needs to be
		*-- regenerated and recompiled.
		*********************************************************************
		IF NOT ISNULL( laMenuFileList[1] ) ;
				AND ASCAN( laMenuFileList, FORCEEXT( laTextFileList[m.xx], "MNX" ), 1, -1, 1, 1+2+4 ) > 0
			*-- The .MNX file is being tracked in the repository, so
			*-- use its timestamp to check the program files.
			IF ISNULL( taTimestampList[1] )
				*-- There are no timestamps available, so just use the
				*-- current modification date of the .MNX file to check
				*-- if the program file needs to be regenerated.
				ltFileTimestamp = m.loMNXItem.ModifyDate
			ELSE
				*-- Lookup the timestamp for the current .MNX file.
				*-- If a timestamp was found for it, store it.
				lnRow = ASCAN( taTimestampList, FORCEEXT( laTextFileList[m.xx], "MNX" ), 1, -1, 1, 1+2+4+8 )
				ltFileTimestamp = IIF( m.lnRow > 0, taTimestampList[m.lnRow,2], .NULL. )
			ENDIF
		ELSE
			*-- Only the text file is being tracked in the repository,
			*-- so use its timestamp to check the program files.
			IF ISNULL( taTimestampList[1] )
				*-- There are no timestamps available, so just use the
				*-- current modification date of the text file to check
				*-- if the program file needs to be regenerated.
				loFile = m.loFolder.ParseName( m.lcJustFileName )
				ltFileTimestamp = IIF( ISNULL( m.loFile ), .NULL., m.loFile.ModifyDate )
			ELSE
				*-- Lookup the timestamp for the current text file.
				*-- If a timestamp was found for it, store it.
				lnRow = ASCAN( taTimestampList, laTextFileList[m.xx], 1, -1, 1, 1+2+4+8 )
				ltFileTimestamp = IIF( m.lnRow > 0, taTimestampList[m.lnRow,2], .NULL. )
			ENDIF
		ENDIF

		IF ISNULL( m.ltFileTimestamp )
			*-- Make sure the menu code objects are cleared when there
			*-- is no timestamp to restore.
			loMPRItem = .NULL.
			loMPXItem = .NULL.
		ELSE
			*-- Get a shell object reference to the .MPR and .MPX files
			*-- that will be generated.
			loMPRItem = m.loFolder.ParseName( FORCEEXT( m.lcJustFileName, "MPR" ) )
			loMPXItem = m.loFolder.ParseName( FORCEEXT( m.lcJustFileName, "MPX" ) )

			*-- If both the .MPR and .MPX files have the same timestamp
			*-- as the primary menu file (either the .MNX or text file),
			*-- assume the menu does not need to be regenerated, and
			*-- skip it.
			IF NOT ISNULL( m.loMPRItem ) ;
					AND NOT ISNULL( m.loMPXItem ) ;
					AND m.loMPRItem.ModifyDate = m.ltFileTimestamp ;
					AND m.loMPXItem.ModifyDate = m.ltFileTimestamp
				LOOP
			ENDIF
		ENDIF

		*-- Get the full path of the .MNX file.  Note that FULLPATH()
		*-- normalizes any forward slashes (/) in the path to backslashes
		*-- (\).
		lcFullFileName = FULLPATH( ADDBS( m.lcRepository ) + FORCEEXT( laTextFileList[m.xx], "MNX" ) )

		*-- Attempt to generate the code files for this menu file.
		llSuccess = This.GenerateMenuCode( @m.toErrorInfo, m.lcFullFileName )

		IF m.llSuccess ;
				AND NOT ISNULL( m.ltFileTimestamp )
			*-- The code files were successfully generated, and we have
			*-- a timestamp, so attempt to set the modification date of
			*-- the generated menu files.
			*-- If the .MPR file did not exist earlier, then we might
			*-- not have a reference to it, so try again to get one now.
			IF ISNULL( m.loMPRItem )
				loMPRItem = m.loFolder.ParseName( FORCEEXT( m.lcJustFileName, "MPR" ) )
			ENDIF

			*-- If we have a reference to the .MPR file, set the modification
			*-- timestamp of the .MPR file to match the .MNX file.
			IF NOT ISNULL( m.loMPRItem )
				loMPRItem.ModifyDate = m.ltFileTimestamp
			ENDIF

			*-- If the .MPX file did not exist earlier, then we might
			*-- not have a reference to it, so try again to get one now.
			IF ISNULL( m.loMPXItem )
				loMPXItem = m.loFolder.ParseName( FORCEEXT( m.lcJustFileName, "MPX" ) )
			ENDIF

			*-- If we have a reference to the .MPX file, set the modification
			*-- timestamp of the .MPX file to match the .MNX file.
			IF NOT ISNULL( m.loMPXItem )
				loMPXItem.ModifyDate = m.ltFileTimestamp
			ENDIF
		ENDIF	&& m.llSuccess AND NOT ISNULL( m.ltFileTimestamp )
	ENDIF	&& m.llRecompileMPR

	*-- One of the processes above failed, so abort.
	IF NOT m.llSuccess
		EXIT
	ENDIF
ENDFOR

This.ClearMessage()

RETURN m.llSuccess
ENDFUNC

*********************************************************************
FUNCTION RecompileRepoProgramFiles

*!*	This method recompiles all the program files committed to the specified Git repository.  The
*!*	object code files (.FXP) are typically not committed to the repository, so this ensures that
*!*	they are in synch with the program files if different versions of the program files have been
*!*	checked out.  If an .FXP file is being tracked along with its .PRG file, than that .PRG will
*!*	not be recompiled.

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
*!*		  taTimestampList (O) -	An array variable passed by reference, which is either already
*!*								populated with timestamp data by This.ReadRepoTimestampFile(), or
*!*								is to be populated with those values by this method.  If omitted,
*!*								the timestamp array will still be populated by this method, if
*!*								applicable.

*!*	RETURNS: Logical
*!*		.T. if all program files are successfully recompiled, or if there are no program files to
*!*		recompile, .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String, tcFileListAlias AS String, taTimestampList

EXTERNAL ARRAY taTimestampList

LOCAL laFXPFileList[1], ;
	laPRGFileList[1], ;
	lcCompiledFileName, ;
	lcErrorMessages, ;
	lcFolder, ;
	lcFullFileName, ;
	lcMessage, ;
	lcRepository, ;
	lcSetNotify, ;
	llSuccess, ;
	lnRow, ;
	loErrorInfo AS Exception, ;
	loFolder AS SHELL.Folder, ;
	loFolderItem AS SHELL.FolderItem, ;
	loShell AS Shell.Shell, ;
	ltFileTimestamp, ;
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

DIMENSION laPRGFileList[1]
laPRGFileList = .NULL.

*-- Retrieve a list of the program files in this repository folder.
SELECT GL_FileName ;
	FROM ( m.tcFileListAlias ) ;
	WHERE UPPER( RTRIM( GL_FileExtension ) ) == "PRG" ;
	INTO ARRAY laPRGFileList

*-- There are no program files that are committed to the repository, so
*-- nothing to do here.
IF ISNULL( laPRGFileList[1] )
	RETURN m.llSuccess
ENDIF

DIMENSION laFXPFileList[1]
laFXPFileList = .NULL.

*-- Retrieve a list of any compiled program files in this repository
*-- folder.
SELECT GL_FileName ;
	FROM ( m.tcFileListAlias ) ;
	WHERE UPPER( RTRIM( GL_FileExtension ) ) == "FXP" ;
	INTO ARRAY laFXPFileList

*-- Make sure the timestamp list parameter is defined as an array.
IF NOT TYPE( "taTimestampList", 1 ) = "A"
	DIMENSION taTimestampList[1]
	taTimestampList = .NULL.
ENDIF

*-- If no timestamp list was specified, and timestamps are preserved
*-- by this repository, then attempt to get the timestamp list.
IF ISNULL( taTimestampList[1] ) ;
		AND This.AreTimestampsPreserved( m.lcRepository )
	*-- Note that we will not abort if we can't get the timestamp list.
	This.ReadRepoTimestampFile( @m.toErrorInfo, m.lcRepository, .NULL., @taTimestampList )
ENDIF

*-- Get a Windows shell object to set the modification dates, even if
*-- a timestamp file is not used.
loShell = CREATEOBJECT( "Shell.Application" )

*-- Make sure SET NOTIFY is OFF during compiling.  We won't get any
*-- progress info when compiling very large files, but the compile is
*-- *significantly* faster.
lcSetNotify = SET("Notify")
SET NOTIFY OFF

lcErrorMessages = SPACE(0)

lcMessage = "Recompiling " + ALLTRIM( TRANSFORM( ALEN( laPRGFileList, 1 ), "999,999" ) ) ;
		+ " program files for repository:" + CHR(13) + m.lcRepository + CHR(13) ;
		+ "Please wait..."
This.ShowMessage( m.lcMessage )

TRY
	*-- Recomile all the program code.
	FOR xx = 1 TO ALEN( laPRGFileList, 1 )
		*-- Check if the .FXP for this .PRG file is being tracked in
		*-- the repository.  If it is, it doesn't need to be recompiled.
		IF NOT ISNULL( laFXPFileList[1] ) ;
				AND ASCAN( laFXPFileList, FORCEEXT( laPRGFileList[m.xx], "FXP" ), 1, -1, 1, 1+2+4 ) > 0
			LOOP
		ENDIF

		*-- Get the full folder name and normalize it to backslashes.
		lcFolder = ADDBS( m.lcRepository ) + JUSTPATH( CHRTRAN( laPRGFileList[m.xx], "/", "\" ) )
		loFolder = m.loShell.NameSpace( m.lcFolder )

		IF ISNULL( taTimestampList[1] )
			*-- There are no timestamps available.  Lookup the modification
			*-- date of the .PRG file, and use that.
			loFolderItem = m.loFolder.ParseName( JUSTFNAME( laPRGFileList[m.xx] ) )
			ltFileTimestamp = IIF( ISNULL( m.loFolderItem ), .NULL., m.loFolderItem.ModifyDate )
		ELSE
			*-- Lookup the timestamp for the current .PRG file.  If a
			*-- timestamp was found, store it.
			lnRow = ASCAN( taTimestampList, laPRGFileList[m.xx], 1, -1, 1, 1+2+4+8 )
			ltFileTimestamp = IIF( m.lnRow > 0, taTimestampList[m.lnRow,2], .NULL. )
		ENDIF

		IF ISNULL( ltFileTimestamp )
			*-- Make sure the folder item object is cleared when there
			*-- is no timestamp to restore.
			loFolderItem = .NULL.
		ELSE
			*-- There is a timestamp to restore, so get the name of the
			*-- .FXP file that will be created on recomiling.
			lcCompiledFileName = FORCEEXT( JUSTFNAME( laPRGFileList[m.xx] ), "FXP" )

			*-- Get a shell object reference to the .FXP file.
			loFolderItem = m.loFolder.ParseName( m.lcCompiledFileName )

			*-- If the timestamp of the .FXP file exactly matches the
			*-- timestamp of the .PRG file, assume that the .PRG does
			*-- not need to be recompiled and skip it.
			IF NOT ISNULL( m.loFolderItem ) ;
					AND m.loFolderItem.ModifyDate = m.ltFileTimestamp
				LOOP
			ENDIF
		ENDIF

		*-- Get the full path of the current file.  Note that FULLPATH()
		*-- normalizes any forward slashes (/) in the path to backslashes
		*-- (\).
		lcFullFileName = FULLPATH( ADDBS( m.lcRepository ) + laPRGFileList[m.xx] )

		*-- Attempt to recompile this program.  Trap individual compile
		*-- errors, but allow processing to continue so that as many
		*-- files as possible will be compiled.
		TRY
			COMPILE ( m.lcFullFileName )

		CATCH TO loErrorInfo
			*-- Add this error message to any prior ones we collected.
			*-- Include the file name so that we can figure out where
			*-- the problem came from, and how we might solve it.
			lcErrorMessages = lcErrorMessages + CHR(13) + CHR(13) ;
					+ m.loErrorInfo.Message + CHR(13) ;
					+ "   File: " + m.lcFullFileName
		ENDTRY

		IF NOT ISNULL( m.ltFileTimestamp )
			*-- We have a timestamp, so attempt to set the modification
			*-- date of the .FXP file.
			*-- If the .FXP file did not exist earlier, then we might
			*-- not have a reference to it, so try again to get one now.
			IF ISNULL( m.loFolderItem )
				loFolderItem = m.loFolder.ParseName( m.lcCompiledFileName )
			ENDIF

			*-- If we have a reference to the .FXP file, set the modification
			*-- timestamp of the .FXP file to match the .PRG file.
			IF NOT ISNULL( m.loFolderItem )
				loFolderItem.ModifyDate = m.ltFileTimestamp
			ENDIF
		ENDIF
	ENDFOR

	*-- If any of the compiles failed, generate a message which includes
	*-- the repository name.
	IF NOT EMPTY( m.lcErrorMessages )
		ERROR "Unable to compile all files in repository: " + m.lcRepository + m.lcErrorMessages
	ENDIF

CATCH TO toErrorInfo
	llSuccess = .F.
ENDTRY

*-- Make sure the original setting is restored.
SET NOTIFY &lcSetNotify.

This.ClearMessage()

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

LOCAL laLines[1], ;
	lcLine, ;
	lcSQL

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
*!*		 tcRepository (O) -	The path of a repository.  If omitted, it is assumed that the default
*!*							folder is the repository being used.

*!*	RETURNS: Character
*!*		The file name to use for storing timestamp data.
*********************************************************************
LPARAMETERS tcFileName AS String, tcRepository AS String

LOCAL lcFileName, ;
	lcRepoType

*-- Check the file name, and use the default if nothing was specified.
IF VARTYPE( m.tcFileName ) = "C" ;
		AND NOT EMPTY( m.tcFileName )
	lcFileName = ALLTRIM( m.tcFileName )
ELSE
	*-- A file name was not specified, so determine the type of repository
	*-- being processed, and get the corresponding file name.
	lcRepoType = This.GetRepoType( m.tcRepository )
	lcFileName = IIF( m.lcRepoType = "M", This.icHgTimestampFilename, This.icGitTimestampFilename )
ENDIF

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

LOCAL lcFileName, ;
	llSaveTimestamps

DO CASE
	CASE This.inPreserveFileTimestamps = 2
		*-- Timestamps are always to be saved.
		llSaveTimestamps = .T.

	CASE This.inPreserveFileTimestamps = 3
		*-- Timestamps are only to be saved if the timestamp file exists,
		*-- so lookup the name and make sure it exists in this repository.
		lcFileName = ADDBS( This.GetRepositoryPath( m.tcRepository ) ) ;
				+ This.GetTimestampFileName( m.tcFileName, m.tcRepository )

		llSaveTimestamps = FILE( m.lcFileName )

	OTHERWISE
		*-- Timestamps are never to be saved, or we somehow have an
		*-- invalid setting, so don't save them.
		llSaveTimestamps = .F.
ENDCASE

RETURN m.llSaveTimestamps
ENDFUNC

*********************************************************************
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
FUNCTION GetProcessScope

*!*	This method validates the scope for Git processing, and/or prompts the user for the scope.
*!*	A Thor selection form is used, which remembers the user's selections.

*!*	PARAMETERS:
*!*			  tcScope (O) -	A default scope to use, either a folder path, or a path and .PJX file
*!*							name.  If omitted or invalid, a form will be displayed where the user
*!*							can select the scope.
*!*		tcFormCaption (O) -	The caption to use on the scope selection form (if it needs to be
*!*							displayed.  If omitted or invalid, the default Git Utilities caption
*!*							will be used.

*!*	RETURNS: Object
*!*		Returns an object containing information about the selected scope.  The structure of the
*!*		object is as follows:
*!*			cScope			  -	Contains the selected scope, either a folder path, or a path and .PJX
*!*								file name, or empty if the user cancelled or an error occurred.
*!*			lScopeIsProject	  -	Indicates whether the scope is a project file or a folder.  This will
*!*								be NULL if the user cancelled or an error occurred.
*!*			oException		  -	If the user cancelled or an error occurred, this will contain a
*!*								reference to an Exception object containing information about what
*!*								happened.  Otherwise this is NULL.
*********************************************************************
LPARAMETERS tcScope AS String, tcFormCaption AS String

LOCAL llSuccess, ;
	loErrorInfo AS Exception, ;
	loScope, ;
	loScopeForm AS FrmScopeFinder OF "C:\Work\VFP\Shared\Tools\Thor\Tools\Procs\Thor_Proc_ScopeProcessor.vcx", ;
	loShape AS Shape

*-- Create an object to return the scope information to the calling code.
loScope = CREATEOBJECT( "Empty" )
ADDPROPERTY( m.loScope, "cScope", SPACE(0) )
ADDPROPERTY( m.loScope, "lScopeIsProject", .NULL. )
ADDPROPERTY( m.loScope, "oException", .NULL. )
ADDPROPERTY( m.loScope, "lUserCancelled", .F. )

tcScope = IIF( VARTYPE( m.tcScope ) = "C", ALLTRIM( m.tcScope ), SPACE(0) )
tcFormCaption = IIF( VARTYPE( m.tcFormCaption ) = "C" AND NOT EMPTY( m.tcFormCaption ), ;
		m.tcFormCaption, ccToolName )

llSuccess = .T.

*-- Determine what we are processing.
DO CASE
	CASE NOT EMPTY( m.tcScope ) ;
			AND DIRECTORY( m.tcScope )
		*-- A folder was passed, so process that.
		loScope.cScope = m.tcScope
		loScope.lScopeIsProject = .F.

	CASE NOT EMPTY( m.tcScope ) ;
			AND FILE( m.tcScope ) ;
			AND UPPER( JUSTEXT( m.tcScope ) ) == "PJX"
		*-- A project file was specified, so process all the files in
		*-- that project.
		loScope.cScope = m.tcScope
		loScope.lScopeIsProject = .T.

	OTHERWISE
		*-- Prompt the developer for the scope of the process using a
		*-- Thor form that simplifies selecting either a project or
		*-- folder.
		loScopeForm = EXECSCRIPT( _Screen.cThorDispatcher, ;
				"Class= FrmScopeFinder from Thor_Proc_ScopeProcessor.vcx", m.tcFormCaption )

		TRY
			*-- Disable these 2 options, since this process always
			*-- drills down into the project or folder, so these options
			*-- are irrelevant.
			loScopeForm.lProjectHomeDirectory = .F.
			loScopeForm.chklProjectHomeDirectory.Enabled = .F.
			loScopeForm.lSubDirectories = .F.
			loScopeForm.chklSubDirectories.Enabled = .F.

			*-- Because the form shows/hides the checkboxes based on
			*-- the type of scope you select, setting Visible = .F. for
			*-- them does nothing.  Create a shape that matches the
			*-- surface of the form, and size it to completely cover
			*-- the 2 checkboxes.
			loScopeForm.AddObject( "shpHideSubfolderOptions", "Shape" )
			loShape = m.loScopeForm.shpHideSubfolderOptions
			loShape.BorderStyle = 0	&& Transparent
			loShape.BackStyle = 1	&& Opaque
			loShape.BackColor = m.loScopeForm.BackColor
			loShape.Left = MIN( m.loScopeForm.chklProjectHomeDirectory.Left, m.loScopeForm.chklSubDirectories.Left )
			loShape.Top = MIN( m.loScopeForm.chklProjectHomeDirectory.Top, m.loScopeForm.chklSubDirectories.Top )
			loShape.Width = MAX( m.loScopeForm.chklProjectHomeDirectory.Width, m.loScopeForm.chklSubDirectories.Width )
			loShape.Height = MAX( m.loScopeForm.chklProjectHomeDirectory.Height, m.loScopeForm.chklSubDirectories.Height )
			loShape.Visible = .T.

			loScopeForm.Show(1)

			*-- If the form doesn't exist as this point, it's usually
			*-- because the form was closed without clicking the "Go"
			*-- button.
			IF NOT VARTYPE( m.loScopeForm ) = "O"
				*-- Set a flag to make it easier to check for a cancel
				*-- condition.
				loScope.lUserCancelled = .T.
				ERROR "Process cancelled by user -- no scope selected for this process."
			ENDIF

			*-- Determine what scope was selected in the form.
			DO CASE
				CASE DIRECTORY( m.loScopeForm.cScope )
					*-- Folder
					loScope.cScope = m.loScopeForm.cScope
					loScope.lScopeIsProject = .F.

				CASE FILE( m.loScopeForm.cScope ) ;
						AND UPPER( JUSTEXT( m.loScopeForm.cScope ) ) == "PJX"
					*-- Project
					loScope.cScope = m.loScopeForm.cScope
					loScope.lScopeIsProject = .T.

				OTHERWISE
					*-- Don't know what, but it isn't valid.
					ERROR "Selected scope is invalid for this process." + CHR(13) ;
							+ "Scope: " + TRANSFORM( m.loScopeForm.cScope )
			ENDCASE

		CATCH TO loErrorInfo
			llSuccess = .F.
			loScope.oException = m.loErrorInfo
		ENDTRY

		*-- If the user cancels the form, it is already released, but
		*-- if it still exists, release it now.
		IF VARTYPE( m.loScopeForm ) = "O"
			loScopeForm.Release()
		ENDIF
ENDCASE

RETURN loScope
ENDFUNC

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

LOCAL lcMenuCodeFile, ;
	lcMenuFile, ;
	lcProjectAlias, ;
	lcTempProjectName, ;
	llSuccess, ;
	lnMenuRecNo, ;
	lnWorkArea, ;
	loProject AS VisualFoxPro.IFoxProject

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

	* We finally have everything we need to call the VFP menu generation
	* program.
	DO ( _GenMenu ) WITH m.lcTempProjectName + ".PJX", m.lnMenuRecNo

	* Make sure the code file is compiled.
	lcMenuCodeFile = FORCEEXT( m.tcMenuFile, "MPR" )
	IF FILE( m.lcMenuCodeFile )
		COMPILE ( m.lcMenuCodeFile )
	ENDIF
	
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

LOCAL lcBin2PrgPath, ;
	loConverter

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

LOCAL lcAltTextFilename, ;
	llGenerateText, ;
	llSuccess, ;
	loConverter AS C_FoxBin2Prg OF "C:\Work\VFP\Shared\Tools\Thor\Tools\Components\FoxBin2Prg\FoxBin2Prg.PRG"

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
PROTECTED FUNCTION AddUntrackedFilesToRepo

*!*	This method checks a repository to determine if a primary VFP binary has been added to the repo,
*!*	but the secondary binaries or text file have not been added yet, and attempts to add them.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from this
*!*							method.  This will be returned as an Exception object.  This parameter is
*!*							not required, but recommended.
*!*		 tcRepository (O) -	The path of the repository where the files are to be added.  If omitted,
*!*							the current repository will be used.

*!*	RETURNS: Logical
*!*		Returns .T. if there is nothing to do, or the files are successfully added to the repository.
*!*		Returns .F. if an error occurs.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String

LOCAL laOtherExt[1], ;
	lcAddCommand, ;
	lcErrorMessage, ;
	lcFileToAdd, ;
	lcMainExtension, ;
	lcRepoType, ;
	lcStatusAlias, ;
	lcTextExtension, ;
	lcTrackedBinAlias, ;
	lcUntrackedAlias, ;
	llSuccess, ;
	lnExtensionCount, ;
	lnWorkArea, ;
	loErrorInfo AS Exception, ;
	xx

lnWorkArea = SELECT()
llSuccess = .T.
lcStatusAlias = "C_AllRepoStatus" + SYS(2015)
lcTrackedBinAlias = "C_TrackedVFPBinaries" + SYS(2015)
lcUntrackedAlias = "C_UntrackedRepoFiles" + SYS(2015)

TRY
	*-- Get a list of all changes for the repository.  Abort if this
	*-- fails, since we won't be able to do anything else.
	IF NOT This.FetchRepoStatus( @m.toErrorInfo, m.tcRepository, m.lcStatusAlias )
		llSuccess = .F.
		EXIT
	ENDIF

	*-- If there are no changes, there's nothing to do.
	IF RECCOUNT( m.lcStatusAlias ) = 0
		EXIT
	ENDIF

	*-- Get a list of all untracked files that are NOT a primary VFP
	*-- binary file.
	SELECT * ;
		FROM ( m.lcStatusAlias ) ;
		WHERE NOT EMPTY( GS_FileExtension ) ;
			AND NOT LEFT( GS_FileExtension, 3 ) IN ( "SCX", "VCX", "MNX", "FRX", "LBX", "DBF", "DBC" ) ;
			AND GS_IndexStatus = "?" ;
			AND GS_WorkTreeStatus = "?" ;
		INTO CURSOR ( m.lcUntrackedAlias ) NOFILTER

	*-- If there are no untracked files, then there's nothing to do
	*-- here.
	IF RECCOUNT( m.lcUntrackedAlias ) = 0
		EXIT
	ENDIF

	*-- Get a list of all primary VFP binary files that don't have
	*-- merge conflicts.  Omit files that are untracked, ignored, or
	*-- are being deleted.
	SELECT * ;
		FROM ( m.lcStatusAlias ) ;
		WHERE LEFT( GS_FileExtension, 3 ) IN ( "SCX", "VCX", "MNX", "FRX", "LBX", "DBF", "DBC" ) ;
			AND NOT GS_MergeConflict ;
			AND NOT GS_IndexStatus IN ( "?", "!", "D" ) ;
			AND NOT GS_WorkTreeStatus IN ( "?", "!", "D" ) ;
		INTO CURSOR ( m.lcTrackedBinAlias ) NOFILTER

	*-- If there are no primary files to process, then there's nothing
	*-- to do.
	IF RECCOUNT( m.lcTrackedBinAlias ) = 0
		EXIT
	ENDIF

	This.ShowMessage( "Adding untracked files to repository" ;
			+ IIF( EMPTY( m.tcRepository ), SPACE(0), CHR(13) + m.tcRepository ) )

	lcErrorMessage = SPACE(0)

	*-- Determine the type of repository being processed, and set the
	*-- corresponding add command to use.
	lcRepoType = This.GetRepoType( m.tcRepository )
	lcAddCommand = IIF( m.lcRepoType = "M", "hg add", "git add" )

	*-- Check all the primary files that are being tracked.
	SELECT ( m.lcTrackedBinAlias )
	GO TOP
	SCAN
		*-- Get the list of secondary file extensions that need to be
		*-- checked for the current file.
		lcMainExtension = RTRIM( EVALUATE( m.lcTrackedBinAlias + ".GS_FileExtension" ) )
		DO CASE
			CASE m.lcMainExtension == "DBC"
				*-- Get the 2 extensions that belong with a DBC.
				DIMENSION laOtherExt[2]
				laOtherExt[1] = "DCT"
				laOtherExt[2] = "DCX"

			CASE m.lcMainExtension = "DBF"
				*-- Get the 2 possible extensions that can belong with
				*-- a table.  If the table doesn't have one or both of
				*-- these files, nothing happens.
				DIMENSION laOtherExt[2]
				laOtherExt[1] = "CDX"
				laOtherExt[2] = "FPT"

			OTHERWISE
				*-- The rest of the extensions simply end with "T" in
				*-- place of the "X" in the main extension.
				DIMENSION laOtherExt[1]
				laOtherExt[1] = LEFT( m.lcMainExtension, 2 ) + "T"
		ENDCASE

		lnExtensionCount = ALEN( laOtherExt )

		*-- Check if a text file is generated for this binary type.
		*-- If so, add the text extension to the list of extensions
		*-- to process.
		lcTextExtension = This.GetTextExtension( m.lcMainExtension, m.tcRepository )
		IF NOT UPPER( m.lcTextExtension ) == UPPER( m.lcMainExtension )
			lnExtensionCount = m.lnExtensionCount + 1
			DIMENSION laOtherExt[m.lnExtensionCount]
			laOtherExt[m.lnExtensionCount] = m.lcTextExtension
		ENDIF

		*-- Check for untracked files that belong with the main file
		*-- being tracked.
		SELECT ( m.lcUntrackedAlias )
		FOR xx = 1 TO m.lnExtensionCount
			*-- Get the relative path and file name of the secondary
			*-- or text file, and check for it in the untracked files
			*-- list.
			lcFileToAdd = FORCEEXT( EVALUATE( m.lcTrackedBinAlias + ".GS_FileName" ), laOtherExt[m.xx] )
			LOCATE FOR UPPER( GS_FileName ) == UPPER( m.lcFileToAdd )
			IF FOUND( m.lcUntrackedAlias )
				loErrorInfo = .NULL.
				*-- This file belongs with a main file that is being
				*-- tracked, so attempt to add it.
				IF NOT This.ExecuteCommand( @m.loErrorInfo, m.tcRepository, m.lcAddCommand + SPACE(1) ;
						+ EVALUATE( m.lcUntrackedAlias + ".GS_FileName" ) )
					*-- When an add fails, log the error, but continue
					*-- processing so we add as many files as possible.
					lcErrorMessage = m.lcErrorMessage + "Unable to add '" ;
							+ EVALUATE( m.lcUntrackedAlias + ".GS_FileName" ) ;
							+ "'  (" + m.loErrorInfo.Message + ")" + CHR(13) + CHR(10)
				ENDIF
			ENDIF
		ENDFOR
	ENDSCAN

	*-- If any files could not be added, generate an error message with
	*-- all the details.
	IF NOT EMPTY( m.lcErrorMessage )
		ERROR m.lcErrorMessage
	ENDIF

CATCH TO toErrorInfo
	llSuccess = .F.

FINALLY
	*-- Make sure we clean up before leaving this method.
	USE IN SELECT( m.lcStatusAlias )
	USE IN SELECT( m.lcTrackedBinAlias )
	USE IN SELECT( m.lcUntrackedAlias )
	SELECT ( m.lnWorkArea )

	This.ClearMessage()
ENDTRY

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
	lcTextExtension, ;
	loConverter AS C_FoxBin2Prg OF "C:\Work\VFP\Shared\Tools\Thor\Tools\Components\FoxBin2Prg\FoxBin2Prg.PRG"

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
PROTECTED FUNCTION FetchTextExtensionList

*!*	This method returns the list of text extensions used for all VFP binary extensions in the specified
*!*	folder.  It also returns the Bin2Txt configuration settings for each extension.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from this
*!*							method.  This will be returned as an Exception object.  This parameter is
*!*							not required, but recommended.
*!*		   tcFilePath (O) -	The full path to the folder whose Bin2Prg text extensions and settings are
*!*							to be retrieved.  If omitted, the current repository folder will be used
*!*							as the path.
*!*		 tcCursorName (O) -	The name to use for the cursor that returns the extension list for the
*!*							folder.  It is not required to specify a cursor name, but if no name is
*!*							specified, a variable should be passed here by reference to receive the
*!*							name of the cursor generated.

*!*	RETURNS: Logical
*!*		Returns true if the extension list for the folder can be successfully retrieved, otherwise
*!*		returns .F.
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcFilePath AS String, tcCursorName AS String

LOCAL laVFPExtension[1], ;
	lcFilePath, ;
	lcTextExtension, ;
	llSupportsBin2Prg, ;
	llSupportsPrg2Bin, ;
	lnConversionSupport, ;
	lnExtensionCount, ;
	loConverter AS C_FoxBin2Prg OF "D:\Optimal\VFP\Shared\Tools\Thor\Tools\Components\FoxBin2Prg\FoxBin2Prg.PRG", ;
	xx

*-- Text extensions can vary by folder.  We don't recommend doing that,
*-- but we'll take that into account.  If the calling code didn't specify
*-- the folder being used, use the repository folder.
IF VARTYPE( m.tcFilePath ) = "C" ;
		AND NOT EMPTY( m.tcFilePath )
	lcFilePath = m.tcFilePath
ELSE
	lcFilePath = This.GetRepositoryPath()
ENDIF

*-- Make sure we have a cursor name, then generate a cursor to store
*-- the results of this method.
tcCursorName = IIF( VARTYPE( m.tcCursorName ) = "C" AND NOT EMPTY( m.tcCursorName ), ;
		ALLTRIM( m.tcCursorName ), "C_Bin2PrgTextExtensionList" )
USE IN SELECT( m.tcCursorName )
CREATE CURSOR ( m.tcCursorName ) ;
	( TE_VFPExtension C(3), ;
		TE_TextExtension C(3), ;
		TE_ConversionSupport I DEFAULT 0, ;
		TE_SupportsBin2Prg L DEFAULT .F., ;
		TE_SupportsPrg2Bin L DEFAULT .F. )
INDEX ON UPPER( TE_VFPExtension ) TAG TE_EXT CANDIDATE

*-- Use the Bin-to-Prg object to get the default extension used for
*-- the text file.
loConverter = This.GetBin2PrgConverter( @m.toErrorInfo )
IF ISNULL( m.loConverter )
	RETURN .F.
ENDIF

*-- Make sure the FoxBin2Prg configuration settings are loaded for the
*-- specified folder.
This.SetBin2PrgConfiguration( m.lcFilePath )

*-- Generate the list of VFP binary extensions to lookup.
lnExtensionCount = ALINES( laVFPExtension, "PJX,VCX,SCX,FRX,LBX,MNX,DBF,DBC", 1+4+8, "," )

FOR xx = 1 TO m.lnExtensionCount
	*-- Inialize the record in the results cursor.
	INSERT INTO ( m.tcCursorName ) ;
		( TE_VFPExtension ) ;
		VALUES ;
		( laVFPExtension[m.xx] )

	*-- Get the text extension for the current binary extension.
	lcTextExtension = UPPER( m.loConverter.get_Ext2FromExt( laVFPExtension[m.xx] ) )

	*-- There is only text support if the text extension is DIFFERENT
	*-- from the binary extension.
	IF NOT m.lcTextExtension == laVFPExtension[m.xx]
		*-- Lookup up the conversion support setting for the current
		*-- extension.
		IF laVFPExtension[m.xx] == "DBF"
			*-- The DBF support setting will be based on the MASTER
			*-- setting unless you specify an explicit path and file
			*-- name.  So including the path we are checking and a file
			*-- name gives the LOCAL setting.  The file name doesn't
			*-- actually have to be an existing file, as long as the
			*-- config file doesn't explicitly filter out that file
			*-- name.
			*-- Note that calling conversionSupportType() in this way
			*-- also ensures that the subsequent call to hasSupport_Prg2Bin()
			*-- will return the correct value.
			lnConversionSupport = m.loConverter.conversionSupportType( ADDBS( m.lcFilePath ) + "FileName." ;
					+ laVFPExtension[m.xx] )
		ELSE
			lnConversionSupport = m.loConverter.conversionSupportType( laVFPExtension[m.xx] )
		ENDIF

		llSupportsBin2Prg = m.loConverter.hasSupport_Bin2Prg( laVFPExtension[m.xx] )
		llSupportsPrg2Bin = m.loConverter.hasSupport_Prg2Bin( m.lcTextExtension )

		REPLACE TE_TextExtension WITH m.lcTextExtension, ;
				TE_ConversionSupport WITH m.lnConversionSupport, ;
				TE_SupportsBin2Prg WITH m.llSupportsBin2Prg, ;
				TE_SupportsPrg2Bin WITH m.llSupportsPrg2Bin ;
				IN ( m.tcCursorName )
	ENDIF
ENDFOR

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

LOCAL lcFilePath, ;
	lcTextExtension, ;
	lcTextFilename

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

LOCAL laAlternateTextRaw[1], ;
	lcAlternateTextFilename, ;
	lcRepoType, ;
	lcRepository, ;
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
*-- The mapping file name depends on the type of repository.
lcRepoType = This.GetRepoType( m.lcRepository )
lcAlternateTextFilename = m.lcRepository + IIF( m.lcRepoType = "M", ;
		This.icHgAlternateTextFilename, This.icGitAlternateTextFilename )
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

LOCAL lcBinaryExtension, ;
	lcExtension

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

*!*	This method attempts to execute a Git or Hg command for the specified VFP binary file.  Since
*!* VFP	binaries are composed of 2 or 3 files, this method attempts to execute the command for all
*!*	the companion files of the "main" binary file as well.

*!*	NOTES:
*!*		This method expects the repository folder to be set as the default folder BEFORE this
*!*		method is called.

*!*	PARAMETERS:
*!*		  toErrorInfo (O) -	A variable passed by reference to store any error info returned from
*!*							this method.  This will be returned as an Exception object.  This
*!*							parameter is not required, but recommended.
*!*			tcCommand (R) -	The Git or Hg command to execute.  This is expected to be a command that
*!*							works with individual files AND file masks, such as:
*!*								git reset
*!*								git checkout
*!*								git clean
*!*								git add
*!*								hg revert
*!*								hg add
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

LOCAL lcBeginDelim, ;
	lcEndDelim, ;
	lcExtensionExpr, ;
	lcMainExtension, ;
	llSuccess

llSuccess = .T.

tcFileName = ALLTRIM( m.tcFileName )

*-- Use the extension of the main binary, not the file passed here,
*-- which will allow us to call this method for the "companion" files
*-- as well as the main file.
lcMainExtension = This.GetMainBinaryExtension( JUSTEXT( m.tcFileName ) )

IF LOWER( GETWORDNUM( m.tcCommand, 1 ) ) = "git"
	*-- For Git commands, the file mask needs to be surrounded by quotes
	*-- and preceeded with a double-dash.
	lcBeginDelim = ' -- "'
	lcEndDelim = '"'
ELSE
	*-- In Mercurial, file masks don't need any special delimiters.
	lcBeginDelim = SPACE(1)
	lcEndDelim = SPACE(0)
ENDIF

DO CASE
	CASE ( "|" + m.lcMainExtension + "|" ) $ "|VCX|SCX|FRX|LBX|MNX|PJX|"
		*-- These file types all have a single companion file whose
		*-- extension begins with the same first 2 letters, and ends
		*-- in "T", so we handle all of them using the same formula.
		*-- In general, the main file and its memo file use the same
		*-- case for their extensions, however, I ran into a couple
		*-- cases where the extension of one file was uppercase and
		*-- the other was lowercase, so we need to account for that in
		*-- the expression for the entire extension.
		lcExtensionExpr = "[" + UPPER( SUBSTR( m.lcMainExtension, 1, 1 ) ) ;
				+ LOWER( SUBSTR( m.lcMainExtension, 1, 1 ) ) + "]" ;
				+ "[" + UPPER( SUBSTR( m.lcMainExtension, 2, 1 ) ) ;
				+ LOWER( SUBSTR( m.lcMainExtension, 2, 1 ) ) + "][TtXx]"

		llSuccess = This.ExecuteCommand( @m.toErrorInfo, .NULL., m.tcCommand + m.lcBeginDelim ;
				+ LEFT( m.tcFileName, LENC( m.tcFileName ) - 3 ) + m.lcExtensionExpr + m.lcEndDelim )

	CASE m.lcMainExtension = "DBC"
		*-- The .DBC is a set of 3 files with a little different naming
		*-- convention.  Explicitly specify the extension for all of
		*-- the files, in case it wasn't the .DBC itself that was passed.
		llSuccess = This.ExecuteCommand( @m.toErrorInfo, .NULL., m.tcCommand + m.lcBeginDelim ;
				+ LEFT( m.tcFileName, LENC( m.tcFileName ) - 3 ) + '[Dd][Bb][Cc]' + m.lcEndDelim )
		IF m.llSuccess
			llSuccess = This.ExecuteCommand( @m.toErrorInfo, .NULL., m.tcCommand + m.lcBeginDelim ;
					+ LEFT( m.tcFileName, LENC( m.tcFileName ) - 3 ) + '[Dd][Cc][TtXx]' + m.lcEndDelim )
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
PROCEDURE ShowMessage

*!*	This method manages how a static message is displayed during processing.

*!*	PARAMETERS:
*!*		tcMessage (R) -	The message to display.  If omitted or invalid, this method does nothing.

*!*	RETURNS: Nothing
*********************************************************************
LPARAMETERS tcMessage AS String

LOCAL loForm AS Form

*-- If the message parameter is invalid, there's nothing to do here.
IF NOT VARTYPE( m.tcMessage ) = "C" ;
		OR EMPTY( m.tcMessage )
	RETURN
ENDIF

*-- Check if there is some other form active, like the progress form.
*-- If so, temporarily activate the VFP _SCREEN to try to prevent the
*-- message from displaying in or over the other form.
loForm = .NULL.
IF TYPE( "_SCREEN.ActiveForm.BaseClass" ) = "C" ;
		AND UPPER( _SCREEN.ActiveForm.BaseClass ) == "FORM"
	loForm = _SCREEN.ActiveForm
	ACTIVATE SCREEN
ENDIF

*-- For now use a simple WAIT WINDOW, but we might eventually replace
*-- this with something a little nicer.
WAIT WINDOW m.tcMessage AT 10, 10 NOWAIT NOCLEAR

*-- If another form was active, make sure it's reactivated.
IF NOT ISNULL( m.loForm )
	ACTIVATE WINDOW ( m.loForm.Name )
ENDIF

ENDPROC

*********************************************************************
PROCEDURE ClearMessage

*!*	This method clears whatever message was displayed by This.ShowMessage().

*!*	PARAMETERS: None

*!*	RETURNS: Nothing
*********************************************************************
*-- We're only using a WAIT WINDOW to display messages, so clear it.
WAIT CLEAR

ENDPROC

*********************************************************************
PROCEDURE LoadProgressBar

*!*	This is a wrapper method for loading the FoxBin2Prg progress bar form.  It also adds some features
*!*	to enhance working with that progress bar.

*!*	PARAMETERS:
*!*			tcMessage (O) -	Pass a message to display for the first progress bar, if you want to
*!*							display something as soon as the form is loaded.
*!*		 tnTotalCount (O) -	Pass the total number of items for the first progress bar, if you want
*!*							to initialize that count for the rest of the process.

*!*	RETURNS: Nothing
*********************************************************************
LPARAMETERS tcMessage AS String, tnTotalCount AS Integer

LOCAL loConverter AS C_FoxBin2Prg OF "D:\Optimal\VFP\Shared\Tools\Thor\Tools\Components\FoxBin2Prg\FoxBin2Prg.PRG"

*-- Get a reference to the conversion object.
loConverter = This.GetBin2PrgConverter()
IF ISNULL( m.loConverter )
	RETURN
ENDIF

*-- The progress form will not refresh properly if the AutoYield setting
*-- is false, so make sure it's turned on before the form is loaded.
_VFP.AutoYield = .T.

*-- Load the progress form.
loConverter.LoadProgressBarForm()

*-- Initialize the properties used internally to keep track of the
*-- settings passed to the progress bar form.
STORE SPACE(0) TO This.icProgressBar1LastMessage, ;
				This.icProgressBar2LastMessage

STORE 0 TO This.inProgressBar1LastItem, ;
		This.inProgressBar2LastItem, ;
		This.inProgressBar1TotalCount, ;
		This.inProgressBar2TotalCount

*-- Make sure the parameters passed here are the correct data type.
tcMessage = IIF( VARTYPE( m.tcMessage ) = "C", m.tcMessage, SPACE(0) )
tnTotalCount = IIF( VARTYPE( m.tnTotalCount ) = "N", m.tnTotalCount, 0 )

*-- If a message or total count was passed, update the progress bar
*-- to display that information.
IF NOT EMPTY( m.tcMessage ) ;
		OR m.tnTotalCount > 0
	This.UpdateProgressBar( m.tcMessage, 0, m.tnTotalCount, 1 )
ENDIF

ENDPROC

*********************************************************************
PROCEDURE UpdateProgressBar

*!*	This is a wrapper method for updating the FoxBin2Prg progress bar form.

*!*	PARAMETERS:
*!*			tcMessage (O) -	The message to display for the specified progress bar.  If omitted, the
*!*							last message displayed for the specified bar will be used.
*!*		 tnItemNumber (O) -	The number of items that have been processed so far for the specified
*!*							progress bar.  If omitted, the last item number that was used will be
*!*							incremented and used as the new item number.
*!*		 tnTotalCount (O) -	The total number of items being processed for the specified progress bar.
*!*							If omitted, the total number of items last specified for the bar will be
*!*							used.
*!*		  tnBarNumber (O) -	Indicates which bar number to apply the other settings to.  Can be 1 or
*!*							2.  If omitted, defaults to 1.

*!*	RETURNS: Nothing
*********************************************************************
LPARAMETERS tcMessage AS String, tnItemNumber AS Integer, tnTotalCount AS Integer, tnBarNumber AS Integer

LOCAL loConverter AS C_FoxBin2Prg OF "D:\Optimal\VFP\Shared\Tools\Thor\Tools\Components\FoxBin2Prg\FoxBin2Prg.PRG"

*-- Make sure we have a reference to the conversion object.
loConverter = This.GetBin2PrgConverter()
IF ISNULL( m.loConverter )
	RETURN
ENDIF

*-- Make sure the progress bar form is loaded.  If it's already loaded,
*-- this method does nothing.
loConverter.LoadProgressBarForm()

*-- Make sure we have a valid bar number.
IF NOT VARTYPE( m.tnBarNumber ) = "N" ;
		OR NOT INLIST( m.tnBarNumber, 1, 2 )
	tnBarNumber = 1
ENDIF

*-- Make sure we have a message to display.
DO CASE
	CASE NOT VARTYPE( m.tcMessage ) = "C" ;
			OR EMPTY( m.tcMessage )
		*-- No message was specified, so use the last message displayed
		*-- for the specified bar.
		tcMessage = IIF( m.tnBarNumber = 1, This.icProgressBar1LastMessage, This.icProgressBar2LastMessage )

	CASE m.tnBarNumber = 1
		*-- A message was specified for bar 1, so save a copy of it.
		This.icProgressBar1LastMessage = m.tcMessage

	OTHERWISE
		*-- A message was specified for bar 2, so save a copy of it.
		This.icProgressBar1LastMessage = m.tcMessage
ENDCASE

*-- Make sure we have an item number to display.
DO CASE
	CASE NOT VARTYPE( m.tnItemNumber ) = "N" ;
			OR m.tnItemNumber < 0
		*-- No item number was specified, so increment the last item
		*-- number used for the bar and use it.
		IF m.tnBarNumber = 1
			tnItemNumber = This.inProgressBar1LastItem + 1
			This.inProgressBar1LastItem = m.tnItemNumber
		ELSE
			tnItemNumber = This.inProgressBar2LastItem + 1
			This.inProgressBar2LastItem = m.tnItemNumber
		ENDIF

	CASE m.tnBarNumber = 1
		*-- An item number was specified for bar 1, so save a copy of
		*-- it.
		This.inProgressBar1LastItem = m.tnItemNumber

	OTHERWISE
		*-- An item number was specified for bar 2, so save a copy of
		*-- it.
		This.inProgressBar2LastItem = m.tnItemNumber
ENDCASE

*-- Make sure we have a total count.
DO CASE
	CASE NOT VARTYPE( m.tnTotalCount ) = "N" ;
			OR m.tnTotalCount < 0
		*-- No total count was specified, so use the last total for the
		*-- specified bar.
		tnTotalCount = IIF( m.tnBarNumber = 1, This.inProgressBar1TotalCount, This.inProgressBar2TotalCount )

	CASE m.tnBarNumber = 1
		*-- A total count was specified for bar 1, so save a copy of it.
		This.inProgressBar1TotalCount = m.tnTotalCount

	OTHERWISE
		*-- A total count was specified for bar 2, so save a copy of it.
		This.inProgressBar2TotalCount = m.tnTotalCount
ENDCASE

*-- FoxBin2Prg refers to the bars as 0 and 1, so adjust our bar number
*-- to match.
tnBarNumber = m.tnBarNumber - 1

*-- Call the FoxBin2Prg method to update the progress bar.
loConverter.UpdateProgressBar( m.tcMessage, m.tnItemNumber, m.tnTotalCount, m.tnBarNumber )

ENDPROC

*********************************************************************
PROCEDURE ReleaseProgressBar

*!*	This is a wrapper method for releasing the FoxBin2Prg progress bar form.

*!*	PARAMETERS: None

*!*	RETURNS: Nothing
*********************************************************************
LOCAL loConverter AS C_FoxBin2Prg OF "D:\Optimal\VFP\Shared\Tools\Thor\Tools\Components\FoxBin2Prg\FoxBin2Prg.PRG"

*-- Make sure we have a reference to the conversion object.
loConverter = This.GetBin2PrgConverter()
IF ISNULL( m.loConverter )
	RETURN
ENDIF

*-- Force the progress bar form to be released.
loConverter.UnloadProgressBarForm(.T.)

ENDPROC

*********************************************************************
PROCEDURE ShowError

*!*	This method simplifies the task of displaying error info generated by this class.

*!*	PARAMETERS:
*!*		  toErrorInfo (R) -	An Exception object whose contents are to be displayed.  If omitted or
*!*							invalid, the call stack will be displayed to at least help to track down
*!*							what code failed without providing error info.
*!*		 tcRepository (O) -	The repository that was being processed when the error occurred.  This
*!*							is just added to the error message as-is to indicate which repository was
*!*							being processed when the error occurred.

*!*	RETURNS: Nothing
*********************************************************************
LPARAMETERS toErrorInfo AS Exception, tcRepository AS String

LOCAL laCallStack[1], ;
	lcResult, ;
	xx

*-- Initialize the message with the name of the repository, if it was
*-- specified.
lcResult = IIF( VARTYPE( m.tcRepository ) = "C" AND NOT EMPTY( m.tcRepository ), ;
		"Repository: " + ALLTRIM( m.tcRepository ) + CHR(13) + CHR(13), SPACE(0) )

IF VARTYPE( m.toErrorInfo ) = "O"
	*-- An exception object was passed.  Report any helpful error info
	*-- it contains.
	lcResult = m.lcResult + IIF( m.toErrorInfo.ErrorNo = 0, SPACE(0), ;
				"Error " + TRANSFORM( m.toErrorInfo.ErrorNo ) + CHR(13) ) ;
			+ m.toErrorInfo.Message ;
			+ IIF( EMPTY( m.toErrorInfo.LineContents ), SPACE(0), ;
				+ CHR(13) + CHR(13) + "Command:  " + m.toErrorInfo.LineContents )
ELSE
	*-- No error info was specified.  Report that, and include the call
	*-- stack to help us track down code which is failing without generating
	*-- error info.
	lcResult = lcResult + "No error information provided." + CHR(13) + CHR(13) ;
			+ "Current call stack:"

	ASTACKINFO( laCallStack )
	FOR xx = 1 TO ALEN( laCallStack, 1 )
		lcResult = m.lcResult + CHR(13) + SPACE(3) + EVL( laCallStack[m.xx,3], laCallStack[m.xx,4] )
	ENDFOR
ENDIF

MESSAGEBOX( m.lcResult, 16, "Git/Hg Utilities Error" )

RETURN
ENDPROC

*********************************************************************
PROCEDURE SelfTest

*!*	A method for code that can be run to test if this class is working properly.
*********************************************************************
LOCAL lcAlias, ;
	lcProjectName, ;
	lcRepository, ;
	lcResult, ;
	llCleanup, ;
	llSuccess, ;
	loErrorInfo AS Exception

lcRepository = "D:\Work\VFP\Shared\Lib"

lcRepository = GETDIR( m.lcRepository, "Select a Git/Hg repository to check its status", ;
		"Select Git/Hg Repository", 1+64+512 )
IF EMPTY( m.lcRepository )
	RETURN
ENDIF

*!*	ASSERT .f.

lcAlias = SPACE(0)
IF This.FetchTextExtensionList( @m.loErrorInfo, m.lcRepository, @m.lcAlias )
	WAIT WINDOW "Text settings for repository '" + m.lcRepository + "'" NOWAIT NOCLEAR
	SELECT ( m.lcAlias )
	BROWSE LAST NOCAPTIONS
	WAIT CLEAR
ELSE
	This.ShowError( m.loErrorInfo, m.lcRepository )
ENDIF

lcAlias = SPACE(0)
llSuccess = This.FetchRepoFileList( @m.loErrorInfo, m.lcRepository, @m.lcAlias )

IF m.llSuccess
	WAIT WINDOW "Files in repository '" + m.lcRepository + "'" NOWAIT NOCLEAR
	SELECT ( m.lcAlias )
	BROWSE LAST NOCAPTIONS
	WAIT CLEAR
ELSE
	This.ShowError( m.loErrorInfo, m.lcRepository )
ENDIF

lcAlias = SPACE(0)
llSuccess = This.FetchRepoStatus( @m.loErrorInfo, m.lcRepository, @m.lcAlias )

DO CASE
	CASE NOT m.llSuccess
		This.ShowError( m.loErrorInfo, m.lcRepository )

	CASE RECCOUNT( m.lcAlias ) = 0
		lcResult = "No changes detected"

	OTHERWISE
		lcResult = TRANSFORM( RECCOUNT( m.lcAlias ) ) + " change(s) detected"
ENDCASE

IF m.llSuccess
	MESSAGEBOX( "Repository: " + m.lcRepository + CHR(13) + CHR(13) + m.lcResult, 64, PROGRAM() )
ENDIF

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
	This.ShowError( m.loErrorInfo )
ENDIF

lcProjectName = SPACE(0)
llCleanup = ( MESSAGEBOX( "Cleanup binaries in the selected project?", 4+32, PROGRAM() ) = 6 )
llSuccess = This.BinaryToTextProject( @m.loErrorInfo, @m.lcProjectName, m.llCleanup )
IF m.llSuccess
	MESSAGEBOX( "Binary to Text successful for " + m.lcProjectName, 64, PROGRAM() )
ELSE
	This.ShowError( m.loErrorInfo )
ENDIF

ENDPROC

ENDDEFINE


*********************************************************************
DEFINE CLASS colPushPopProjects AS Collection
*********************************************************************

#IF .F.
Class:  Thor_Proc_GitUtilities.PRG/colPushPopProjects

DESCRIPTION:
	This class closes all open projects on instantiation, and opens them all again on release.

USAGE:
	LOCAL loProjects

	loProjects = CREATEOBJECT( "colPushPopProjects" )

	*-- Do stuff

	loProjects = .NULL.	&& or let the variable go out of scope

METHODS THAT HAVE BEEN ADDED/MODIFIED:
======================================

PROPERTIES THAT HAVE BEEN ADDED/MODIFIED:
=========================================

MEMBER OBJECTS THAT HAVE BEEN ADDED/MODIFIED:
=============================================

#ENDIF

*-- This property stores the name of the project that was the active
*-- project when this class was instantiated, so that we can make it
*-- the active project again on release.
icActiveProject = ""

*********************************************************************
PROCEDURE Init
*********************************************************************
LOCAL xx

*-- Don't even instantiate this class when there are no projects open.
IF _VFP.Projects.Count = 0
	RETURN .F.
ENDIF

*-- If the Project Explorer is being used, it manages its own projects,
*-- so close those projects first.
This.CloseProjectExplorerProjects()

*-- If there are still projects open, they must have been opened directly.
IF _VFP.Projects.Count > 0
	*-- Store the name of the active project before doing anything else.
	This.icActiveProject = _VFP.ActiveProject.Name

	*-- Store the names of all the open projects.
	FOR xx = 1 TO _VFP.Projects.Count
		This.Add( _VFP.Projects.Item(m.xx).Name )
	ENDFOR

	*-- Close all the projects.
	This.CloseAllProjects()
ENDIF

ENDPROC

*********************************************************************
PROCEDURE Destroy
*********************************************************************
*-- Attempt to reopen any projects that were open when this class was
*-- instantiated.
This.OpenAllProjects()

ENDPROC

*********************************************************************
PROCEDURE CloseProjectExplorerProjects

*!*	This method attempts to close all project files that are currently open for a Project Explorer
*!*	solution.

*!*	PARAMETERS: None

*!*	RETURNS: Nothing
*********************************************************************
LOCAL loExplorer

*-- Check if there are any Project Explorer instances loaded.
IF NOT VARTYPE( _SCREEN.oProjectExplorers ) = "O" ;
		OR _SCREEN.oProjectExplorers.Count = 0
	RETURN
ENDIF

*-- Close the projects for all solutions that are currently open.
FOR EACH loExplorer IN _SCREEN.oProjectExplorers FOXOBJECT
	loExplorer.oSolution.CloseProjects()
ENDFOR

ENDPROC

*********************************************************************
PROCEDURE CloseProject

*!*	This method attempts to close a specific VFP project file.

*!*	PARAMETERS:
*!*		tcProjectFileName (R) -	The full path and file name of the project to close.

*!*	RETURNS: Nothing
*********************************************************************
LPARAMETERS tcProjectFileName AS String

LOCAL loProject AS VisualFoxpro.IFoxProject

*-- Check if there are any open projects before attempting to close
*-- one.
IF _VFP.Projects.Count = 0
	RETURN
ENDIF

TRY
	*-- Attempt to get a reference to the project object.
	loProject = _VFP.Projects.Item( m.tcProjectFileName )
CATCH
	loProject = .NULL.
ENDTRY

*-- If the project was open, close it.
IF NOT ISNULL( m.loProject )
	loProject.Close()
	loProject = .NULL.
ENDIF

ENDPROC

*********************************************************************
PROCEDURE CloseAllProjects

*!*	This method attempts to close all project files that are currently open.

*!*	PARAMETERS: None

*!*	RETURNS: Nothing
*********************************************************************
LOCAL lcProjectName, ;
	xx

*-- Check if there are any projects open, otherwise there is nothing
*-- to do.
IF _VFP.Projects.Count = 0
	RETURN
ENDIF

*-- Go through the projects collection and close them all.  We need to
*-- work our way from the last item in the collection to the first,
*-- because the collection count will change as each item is closed.
FOR xx = _VFP.Projects.Count TO 1 STEP -1
	lcProjectName = _VFP.Projects.Item(m.xx).Name
	This.CloseProject( m.lcProjectName )
ENDFOR

ENDPROC

*********************************************************************
PROCEDURE OpenProjectExplorerProjects

*!*	This method attempts to reopen all project files that are managed by Project Explorer instances.

*!*	PARAMETERS: None

*!*	RETURNS: Nothing
*********************************************************************
LOCAL loExplorer

*-- Check if there are any Project Explorer instances loaded.
IF NOT VARTYPE( _SCREEN.oProjectExplorers ) = "O" ;
		OR _SCREEN.oProjectExplorers.Count = 0
	RETURN
ENDIF

*-- Open the projects for all solutions.
FOR EACH loExplorer IN _SCREEN.oProjectExplorers FOXOBJECT
	loExplorer.oSolution.OpenProjects()
ENDFOR

ENDPROC

*********************************************************************
PROCEDURE OpenProject

*!*	This method attempts to open a specified project file.

*!*	PARAMETERS:
*!*		tcProjectFileName (R) -	The full path and file name of the project to open.

*!*	RETURNS: Nothing
*********************************************************************
LPARAMETERS tcProjectFileName AS String

*-- Attempt to open the specified project.  Use NOWAIT so that processing
*-- can continue on after the project is open.
TRY
	MODIFY PROJECT ( m.tcProjectFileName ) NOWAIT
CATCH
ENDTRY

ENDPROC

*********************************************************************
PROCEDURE OpenAllProjects

*!*	This method attempts to re-open all projects that were originally open when this class was
*!*	instantiated.

*!*	PARAMETERS: None

*!*	RETURNS: Nothing
*********************************************************************
LOCAL lcProjectName, ;
	xx

*-- Attempt to reopen any projects used by Project Explorer instances.
This.OpenProjectExplorerProjects()

*-- Check if this class has any items stored, otherwise there is nothing
*-- more to do here.
IF This.Count = 0
	RETURN
ENDIF

*-- Attempt to open all the projects whose names were stored when the
*-- class was instantiated.
FOR xx = 1 TO This.Count
	lcProjectName = This.Item(m.xx)
	This.OpenProject( m.lcProjectName )
ENDFOR

*-- Opening a project that is already open will make it the active
*-- project.
This.OpenProject( This.icActiveProject )

ENDPROC

ENDDEFINE


*********************************************************************
*-- Define the option page for all the Git utilities options.
*********************************************************************
DEFINE CLASS ccEditClassName AS Container

	PROCEDURE Init
		LOCAL loRenderEngine

		loRenderEngine = EXECSCRIPT( _Screen.cThorDispatcher, "Class= OptionRenderEngine" )

		TEXT TO loRenderEngine.cBodyMarkup NOSHOW TEXTMERGE
			.lLabelsAbove = .F.
			|
			.Class = "Label"
			.Caption = "Should file modification dates be saved/restored for all files in Git or Mercurial repositories?  (This setting is ignored when explicitly saving or restoring file timestamps using the corresponding tools.)"
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
			.Caption = "Enter the names of the files where the file modification timestamps will be saved.  The file is created in the repository root, so do not include a path."
			.Width = 350
			.Left = 25
			.WordWrap = .T.
			|
			.Class = "Label"
			.Caption = "Git"
			.Width = 80
			.Left = 25
			.Alignment = 1
			|
			.Class = "Textbox"
			.Width = 150
			.Left = 110
			.row-increment = 0
			.cTool = ccToolName
			.cKey = ccKeyGitTimestampFileName
			|
			.Class = "Label"
			.Caption = "Mercurial"
			.Width = 80
			.Left = 25
			.Alignment = 1
			|
			.Class = "Textbox"
			.Width = 150
			.Left = 110
			.row-increment = 0
			.cTool = ccToolName
			.cKey = ccKeyHgTimestampFileName
		ENDTEXT

		loRenderEngine.Render( This, ccToolName )
	ENDPROC

ENDDEFINE
