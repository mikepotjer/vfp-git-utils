LPARAMETERS lxParam1

#DEFINE TOOL_PROMPT		"Add Git-Hg Beta to Check for Updates"

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
		.Summary       = 'Add the Git-Hg Beta to Thor Check for Updates'

		* Optional
		Text to .Description NoShow && a description for the tool
Adds the Git-Hg Utilities Beta to the My Updates folder, so it can be installed or updated via Thor Check for Updates.
		EndText 
		.StatusBarText = .Summary
		.CanRunAtStartUp = .F.

		* These are used to group and sort tools when they are displayed in menus or the Thor form
		.Source		   = 'MJP' && where did this tool come from?  Your own initials, for instance
		.Category      = 'Applications|Git-Hg Utilities' && allows categorization for tools with the same source
		.Sort		   = 6 && the sort order for all items from the same Source, Category and Sub-Category

		* For public tools, such as PEM Editor, etc.
		.Version	   = '2017.02.25' && e.g., 'Version 7, May 18, 2011'
		.Author        = 'Mike Potjer'
		*!* .Link          = 'https://github.com/mikepotjer/vfp-git-utils'	&& 'http://www.optimalinternet.com/' && link to a page for this tool
		.Link          = 'https://bitbucket.org/mikepotjer/vfp-git-utils'	&& 'http://www.optimalinternet.com/' && link to a page for this tool
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

LOCAL lcFileName, ;
	lcGitUtilsBetaInstall, ;
	lcToolFolder, ;
	llSuccess, ;
	loErrorInfo AS Exception

llSuccess = .T.

*-- Lookup the folder where custom updates are installed, and set the
*-- file name to use for the beta install.
lcToolFolder = EXECSCRIPT( _Screen.cThorDispatcher, 'Tool Folder=' )
lcFileName = ADDBS( m.lcToolFolder ) + 'Updates\My Updates\Thor_Update_Git-Utils-Beta.prg'

*-- Generate the contents of the beta install .PRG.
TEXT TO m.lcGitUtilsBetaInstall TEXTMERGE NOSHOW
LPARAMETERS loUpdateObject

WITH loUpdateObject
    .ApplicationName      = 'Git Utilities (Beta)'
    .Component            = 'No'
    .ToolName             = 'Thor_Tool_ThorInternalRepository'
    .VersionLocalFilename = 'GitUtilitiesVersionFile-Beta.txt'
	.VersionFileURL       = 'https://bitbucket.org/mikepotjer/vfp-git-utils/downloads/GitUtilitiesVersionFile-Beta.txt'
ENDWITH

RETURN loUpdateObject
ENDTEXT

IF FILE( m.lcFileName )
	*-- The install file already exists, so let the user know and do
	*-- nothing.
	MESSAGEBOX( "Git-Hg Utilities Beta install file already exists.", 64, TOOL_PROMPT, 3000 )
ELSE
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

*-- Provide a return value that can be used if you call this process
*-- from some other code.
RETURN EXECSCRIPT( _Screen.cThorDispatcher, "Result=", m.llSuccess )
ENDPROC
