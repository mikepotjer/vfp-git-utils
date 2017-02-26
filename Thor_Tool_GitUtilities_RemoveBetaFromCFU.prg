LPARAMETERS lxParam1

#DEFINE TOOL_PROMPT		"Remove Git-Hg Beta from Check for Updates"

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
		.Summary       = 'Remove the Git-Hg Beta from Thor Check for Updates'

		* Optional
		Text to .Description NoShow && a description for the tool
Removes the Git-Hg Utilities Beta from the My Updates folder, so it no longer appears in Thor Check for Updates.
		EndText 
		.StatusBarText = .Summary
		.CanRunAtStartUp = .F.

		* These are used to group and sort tools when they are displayed in menus or the Thor form
		.Source		   = 'MJP' && where did this tool come from?  Your own initials, for instance
		.Category      = 'Applications|Git-Hg Utilities' && allows categorization for tools with the same source
		.Sort		   = 7 && the sort order for all items from the same Source, Category and Sub-Category

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
	lcToolFolder, ;
	llSuccess, ;
	loErrorInfo AS Exception

llSuccess = .T.

*-- Lookup the folder where custom installs are located, and set the
*-- file name we use for the beta install.
lcToolFolder = EXECSCRIPT( _Screen.cThorDispatcher, 'Tool Folder=' )
lcFileName = ADDBS( m.lcToolFolder ) + 'Updates\My Updates\Thor_Update_Git-Utils-Beta.prg'

IF FILE( m.lcFileName )
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
ELSE
	*-- The install file doesn't exist, so let the user know there's
	*-- nothing to do.
	MESSAGEBOX( "Git-Hg Utilities Beta install file does not exist in the My Updates folder.", 64, ;
			TOOL_PROMPT, 3000 )
ENDIF

*-- Provide a return value that can be used if you call this process
*-- from some other code.
RETURN EXECSCRIPT( _Screen.cThorDispatcher, "Result=", m.llSuccess )
ENDPROC
