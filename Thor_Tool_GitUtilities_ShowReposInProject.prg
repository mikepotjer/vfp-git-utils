LPARAMETERS lxParam1

#DEFINE TOOL_PROMPT		"Show Git-Hg repos in project"

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
		.Summary       = 'Display a cursor of all the Git or Mercurial repositories in a VFP project'

		* Optional
		Text to .Description NoShow && a description for the tool
Populates a cursor with a list of all the Git or Mercurial repositories containing files from the selected project, and the branch currently checked out for each repo.  Prompts for a project if no project is open, otherwise processes the active project.

This tool requires Git for Windows or Mercurial for Windows and some Thor Repository tools.
		EndText 
		.StatusBarText = .Summary
		.CanRunAtStartUp = .F.

		* These are used to group and sort tools when they are displayed in menus or the Thor form
		.Source		   = 'MJP' && where did this tool come from?  Your own initials, for instance
		.Category      = 'Applications|Git-Hg Utilities' && allows categorization for tools with the same source
		.Sort		   = 3 && the sort order for all items from the same Source, Category and Sub-Category

		* For public tools, such as PEM Editor, etc.
		.Version	   = '2016.06.24' && e.g., 'Version 7, May 18, 2011'
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

LOCAL llSuccess, ;
	loErrorInfo AS Exception, ;
	loGitUtilities AS cusGitUtilities OF Thor_Proc_GitUtilities.PRG, ;
	lcProjectName, ;
	lcAlias

llSuccess = .T.

*-- Get a reference to our Git tools class.
TRY
	loGitUtilities = EXECSCRIPT( _Screen.cThorDispatcher, "Thor_Proc_GitUtilities" )

CATCH TO loErrorInfo
	llSuccess = .F.
ENDTRY

IF m.llSuccess
	*-- Validate the passed parameter.  If it's a valid project, it
	*-- will be used, otherwise the project will be determined based
	*-- on the rules in this method.
	lcProjectName = m.loGitUtilities.GetProjectName( @m.loErrorInfo, m.lxParam1 )
	llSuccess = NOT EMPTY( m.lcProjectName )
ENDIF

IF m.llSuccess
	*-- Use the project name in the alias name for the cursor, then
	*-- attempt to retrieve the list of repositories.
	lcAlias = "Repositories_For_" + JUSTSTEM( m.lcProjectName ) + "_PJX"
	llSuccess = m.loGitUtilities.FetchReposInProject( @m.loErrorInfo, m.lcProjectName, m.lcAlias )
ENDIF

*-- Display the results.
IF m.llSuccess
	SELECT ( m.lcAlias )
	BROWSE LAST NOCAPTIONS NODELETE NOEDIT NOWAIT
ELSE
	MESSAGEBOX( m.loErrorInfo.Message, 16, TOOL_PROMPT )
ENDIF

*-- Provide a return value that can be used if you call this process
*-- from some other code.
RETURN EXECSCRIPT( _Screen.cThorDispatcher, "Result=", m.llSuccess )
ENDPROC
