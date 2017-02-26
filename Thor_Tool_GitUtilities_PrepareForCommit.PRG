LPARAMETERS lxParam1

#INCLUDE Procs\Thor_Proc_GitUtilities.h
#DEFINE TOOL_PROMPT		"Prepare for Git-Hg commit"

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
		.Summary       = 'Prepare modified files in a VFP project or repository for commit into a Git or Mercurial repository'

		* Optional
		Text to .Description NoShow && a description for the tool
Prepares all VFP binary files in a selected repository, or in the Git or Mercurial repositories of the selected project, for commit, including regenerating text files as needed.
Whenever VFP binary files are being tracked in a repository and have changed due to a recompile, but not because of a code change, those binaries are reset.

NOTE: Make sure that any VFP binary files which have changed are closed before running this process.  This process can "hang" if it attempts to replace a file that is still open.

This tool requires Git for Windows or Mercurial for Windows, FoxBin2Prg, and some Thor Repository tools.
		EndText 
		.StatusBarText = .Summary
		.CanRunAtStartUp = .F.

		* These are used to group and sort tools when they are displayed in menus or the Thor form
		.Source		   = 'MJP' && where did this tool come from?  Your own initials, for instance
		.Category      = 'Applications|Git-Hg Utilities' && allows categorization for tools with the same source
		.Sort		   = 1 && the sort order for all items from the same Source, Category and Sub-Category

		* For public tools, such as PEM Editor, etc.
		.Version	   = '2016.12.09' && e.g., 'Version 7, May 18, 2011'
		.Author        = 'Mike Potjer'
		*!* .Link          = 'https://github.com/mikepotjer/vfp-git-utils'	&& 'http://www.optimalinternet.com/' && link to a page for this tool
		.Link          = 'https://bitbucket.org/mikepotjer/vfp-git-utils'	&& 'http://www.optimalinternet.com/' && link to a page for this tool
		.VideoLink     = '' && link to a video for this tool

		.OptionTool    = ccToolName
		.OptionClasses = "clsPreserveTimestamp, clsGitTimestampFileName, clsHgTimestampFileName"
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

LOCAL lcRepository, ;
	llSuccess, ;
	loErrorInfo AS Exception, ;
	loGitUtilities AS cusGitUtilities OF Procs\Thor_Proc_GitUtilities.PRG, ;
	loScope

llSuccess = .T.

*-- Get a reference to our Git tools class.
TRY
	loGitUtilities = EXECSCRIPT( _Screen.cThorDispatcher, "Thor_Proc_GitUtilities" )

CATCH TO loErrorInfo
	llSuccess = .F.
ENDTRY

*-- Determine what we are processing.
IF m.llSuccess
	loScope = m.loGitUtilities.GetProcessScope( m.lxParam1, TOOL_PROMPT )
	IF EMPTY( m.loScope.cScope )
		llSuccess = .F.
		loErrorInfo = m.loScope.oException
	ENDIF
ENDIF

*-- Here's where the processing actually occurs.
DO CASE
	CASE NOT m.llSuccess
		*-- Something failed already, so nothing to do.

	CASE m.loScope.lScopeIsProject
		*-- Process a project.
		WAIT WINDOW "Preparing project for commit" + CHR(13) + m.loScope.cScope NOWAIT NOCLEAR
		llSuccess = m.loGitUtilities.BinaryToTextProject( @m.loErrorInfo, m.loScope.cScope, .T. )

	OTHERWISE
		*-- Processing a folder.
		WAIT WINDOW "Preparing repository for commit" + CHR(13) + m.loScope.cScope NOWAIT NOCLEAR
		llSuccess = m.loGitUtilities.BinaryToTextRepo( @m.loErrorInfo, m.loScope.cScope, .T. )
ENDCASE

WAIT CLEAR

*-- Display the results.
DO CASE
	CASE m.llSuccess
		MESSAGEBOX( "Preparation for commit was successful for" + CHR(13) + m.loScope.cScope, ;
				64, TOOL_PROMPT, 3000 )

	CASE TYPE( "m.loScope.lUserCancelled" ) = "L" ;
			AND m.loScope.lUserCancelled
		*-- The process failed because the user cancelled, set a timeout
		*-- so the user doesn't have to close the message dialog.
		MESSAGEBOX( m.loErrorInfo.Message, 16, TOOL_PROMPT, 2000 )

	CASE VARTYPE( m.loGitUtilities ) = "O"
		*-- If the Git utilities object is available, use that to report
		*-- the error, since it gives you more detail.
		lcRepository = .NULL.
		IF TYPE( "m.loScope.cScope" ) = "C" ;
				AND NOT EMPTY( NVL( m.loScope.cScope, SPACE(0) ) ) ;
				AND NOT m.loScope.lScopeIsProject
			lcRepository = m.loScope.cScope
		ENDIF

		loGitUtilities.ShowError( m.loErrorInfo, m.lcRepository )

	OTHERWISE
		*-- No goodies available, so just report the error message.
		MESSAGEBOX( m.loErrorInfo.Message, 16, TOOL_PROMPT )
ENDCASE

*-- Provide a return value that can be used if you call this process
*-- from some other code.
RETURN EXECSCRIPT( _Screen.cThorDispatcher, "Result=", m.llSuccess )
ENDPROC


*********************************************************************
*-- Option classes
*********************************************************************
DEFINE CLASS clsPreserveTimestamp AS Custom
	Tool = ccToolName
	Key = ccKeyPreserveTimestamps
	Value = ccInitialValuePreserveTS
	EditClassName = [ccEditClassName of Thor_Proc_GitUtilities.PRG]
ENDDEFINE

DEFINE CLASS clsGitTimestampFileName AS Custom
	Tool = ccToolName
	Key = ccKeyGitTimestampFileName
	Value = ccInitialValueGitTSFileName
	EditClassName = [ccEditClassName of Thor_Proc_GitUtilities.PRG]
ENDDEFINE

*-- MJP -- 06/24/2016 04:24:39 PM
DEFINE CLASS clsHgTimestampFileName AS Custom
	Tool = ccToolName
	Key = ccKeyHgTimestampFileName
	Value = ccInitialValueHgTSFileName
	EditClassName = [ccEditClassName of Thor_Proc_GitUtilities.PRG]
ENDDEFINE
