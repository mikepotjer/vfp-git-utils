LPARAMETERS lxParam1

#DEFINE TOOL_PROMPT		"Add/Remove Git-Hg Beta in Check for Updates"

****************************************************************
****************************************************************
* Standard prefix for all tools for Thor, allowing this tool to
*   tell Thor about itself.

IF PCOUNT() = 1 ;
		AND 'O' = VARTYPE( m.lxParam1 ) ;
		AND 'thorinfo' = LOWER( m.lxParam1.Class )

	WITH lxParam1

		* Required
		.Prompt		   = TOOL_PROMPT && used when tool appears in a menu
		.Summary       = 'Add or Remove the Git-Hg Beta in Thor Check for Updates'

		* Optional
		Text to .Description NoShow && a description for the tool
Adds or removes the Git-Hg Utilities Beta installer in the My Updates folder.

If the beta installer doesn't exist, you will be prompted to create it, so it can be installed or updated via Thor Check for Updates.

If the beta installer already exists, you will be prompted to remove it, so it no longer appears in Thor Check for Updates.
		EndText 
		.StatusBarText = .Summary
		.CanRunAtStartUp = .F.

		* These are used to group and sort tools when they are displayed in menus or the Thor form
		.Source		   = 'MJP' && where did this tool come from?  Your own initials, for instance
		.Category      = 'Applications|Git-Hg Utilities' && allows categorization for tools with the same source
		.Sort		   = 6 && the sort order for all items from the same Source, Category and Sub-Category

		* For public tools, such as PEM Editor, etc.
		.Version	   = '2018.05.18' && e.g., 'Version 7, May 18, 2011'
		.Author        = 'Mike Potjer'
		.Link          = 'https://github.com/mikepotjer/vfp-git-utils'	&& link to a page for this tool
		.VideoLink     = '' && link to a video for this tool

	ENDWITH

	RETURN m.lxParam1
ENDIF

IF PCOUNT() = 0
	DO ToolCode
ELSE
	DO ToolCode WITH m.lxParam1
ENDIF

RETURN


****************************************************************
****************************************************************
* Normal processing for this tool begins here.
PROCEDURE ToolCode
LPARAMETERS lxParam1

LOCAL lcFileContent, ;
	lcFileName, ;
	lcGitUtilsBetaInstall, ;
	lcToolFolder, ;
	llSuccess, ;
	loErrorInfo AS Exception

llSuccess = .T.

*********************************************************************
*-- Generate the contents of the beta install .PRG.
TEXT TO m.lcGitUtilsBetaInstall TEXTMERGE NOSHOW
LPARAMETERS loUpdateObject

WITH loUpdateObject
    .ApplicationName      = 'Git Utilities (Beta)'
    .Component            = 'No'
    .ToolName             = 'Thor_Tool_ThorInternalRepository'
    .VersionLocalFilename = 'GitUtilitiesVersionFile-Beta.txt'
	.VersionFileURL       = 'https://raw.githubusercontent.com/mikepotjer/vfp-git-utils/beta/ThorUpdater/GitUtilitiesVersionFile-Beta.txt'
ENDWITH

RETURN loUpdateObject
ENDTEXT
*********************************************************************

*-- Lookup the folder where custom updates are installed, and set the
*-- file name to use for the beta install.
lcToolFolder = EXECSCRIPT( _Screen.cThorDispatcher, 'Tool Folder=' )
lcFileName = ADDBS( m.lcToolFolder ) + 'Updates\My Updates\Thor_Update_Git-Utils-Beta.prg'

IF FILE( m.lcFileName )
	*-- If the install file exists, but it's content doesn't match the
	*-- current installer settings, then delete it, because there's a
	*-- good chance it no longer works.
	lcFileContent = FILETOSTR( m.lcFileName )
	IF NOT m.lcFileContent == m.lcGitUtilsBetaInstall
		ERASE ( m.lcFileName )
	ENDIF
ENDIF

IF FILE( m.lcFileName )
	*-- The install file already exists, so give the user the option
	*-- to remove it.
	IF MESSAGEBOX( "Git-Hg Utilities Beta install file was found in the My Updates folder." ;
			+ "  Do you want to remove it?", 4+32, TOOL_PROMPT ) = 6	&& Yes
		*-- The file exists, so attempt to delete it.
		TRY
			ERASE ( m.lcFileName )

			IF FILE( m.lcFileName )
				*-- The file could not be deleted for some reason, so abort.
				ERROR "Unable to remove Git-Hg Beta install file."
			ELSE
				*-- Let the user know the file was successfully deleted.
				MESSAGEBOX( "Git-Hg Utilities Beta install file successfully removed.", 64, ;
						TOOL_PROMPT, 3000 )
			ENDIF

		CATCH TO loErrorInfo
			*-- Report any error that occurred.
			llSuccess = .F.
			MESSAGEBOX( m.loErrorInfo.Message, 16, TOOL_PROMPT )
		ENDTRY
	ENDIF
ELSE
	*-- The install file doesn't exist, so give the user the option to
	*-- add it.
	IF MESSAGEBOX( "Git-Hg Utilities Beta install file does not exist in the My Updates folder." ;
			+ "  Do you want to add it?", 4+32, TOOL_PROMPT ) = 6	&& Yes
		*-- Attempt to create the install file.
		TRY
			STRTOFILE( m.lcGitUtilsBetaInstall, m.lcFileName )

			IF FILE( m.lcFileName )
				*-- The file was successfully created, so let the user know.
				MESSAGEBOX( "Git-Hg Utilities Beta install file was successfully created.", 64, ;
						TOOL_PROMPT, 3000 )
			ELSE
				*-- For some reason the file could not be created, so abort.
				ERROR "Unable to create Git-Hg Beta install file."
			ENDIF

		CATCH TO loErrorInfo
			*-- An error occurred attempting to create the file, so report
			*-- it to the user.
			llSuccess = .F.
			MESSAGEBOX( m.loErrorInfo.Message, 16, TOOL_PROMPT )
		ENDTRY
	ENDIF
ENDIF

*-- Provide a return value that can be used if you call this process
*-- from some other code.
RETURN EXECSCRIPT( _Screen.cThorDispatcher, "Result=", m.llSuccess )
ENDPROC
