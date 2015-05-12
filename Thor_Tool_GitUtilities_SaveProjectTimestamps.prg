LPARAMETERS lxParam1

#INCLUDE Thor_Proc_GitUtilities.h
#DEFINE TOOL_PROMPT		"Save file timestamps"

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
		.Summary       = 'Save the timestamps of files belonging to a Git repository'

		* Optional
		Text to .Description NoShow && a description for the tool
Saves the modification date for all files in the Git repositories of the selected project or repository folder.  If the timestamp file already exists, then only the modification dates for files that have changed since the most recent commit are updated.

This tool requires Git for Windows and some Thor Repository tools.
		EndText 
		.StatusBarText = .Summary
		.CanRunAtStartUp = .F.

		* These are used to group and sort tools when they are displayed in menus or the Thor form
		.Source		   = 'MJP' && where did this tool come from?  Your own initials, for instance
		.Category      = 'Applications|Git Utilities' && allows categorization for tools with the same source
		.Sort		   = 0 && the sort order for all items from the same Source, Category and Sub-Category

		* For public tools, such as PEM Editor, etc.
		.Version	   = '2015.5.12' && e.g., 'Version 7, May 18, 2011'
		.Author        = 'Mike Potjer'
		.Link          = ''	&& 'http://www.optimalinternet.com/' && link to a page for this tool
		.VideoLink     = '' && link to a video for this tool

		.OptionTool    = ccToolName
		.OptionClasses = "clsTimestampFileName"
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
	lcScope, ;
	llScopeIsProject, ;
	loScopeForm AS FrmScopeFinder OF "C:\Work\VFP\Shared\Tools\Thor\Tools\Procs\Thor_Proc_ScopeProcessor.vcx", ;
	loErrorInfo AS Exception, ;
	loGitUtilities AS cusGitUtilities OF Thor_Proc_GitUtilities.PRG

lxParam1 = IIF( VARTYPE( m.lxParam1 ) = "C", ALLTRIM( m.lxParam1 ), SPACE(0) )
llSuccess = .T.

*-- Determine what we are processing.
DO CASE
	CASE NOT EMPTY( m.lxParam1 ) ;
			AND DIRECTORY( m.lxParam1 )
		*-- A folder was passed to this procedure, so process that.
		lcScope = m.lxParam1
		llScopeIsProject = .F.

	CASE NOT EMPTY( m.lxParam1 ) ;
			AND FILE( m.lxParam1 ) ;
			AND UPPER( JUSTEXT( m.lxParam1 ) ) == "PJX"
		*-- A project file was specified, so process all the files in
		*-- that project.
		lcScope = m.lxParam1
		llScopeIsProject = .T.

*!*		CASE EMPTY( m.lxParam1 ) ;
*!*				AND _VFP.Projects.Count > 0
*!*			lcScope = _VFP.ActiveProject.Name
*!*			llScopeIsProject = .T.

	OTHERWISE
		*-- Prompt the developer for the scope of the process using a
		*-- Thor form that simplifies selecting either a project or
		*-- folder.
		loScopeForm = EXECSCRIPT( _Screen.cThorDispatcher, ;
				"Class= FrmScopeFinder from Thor_Proc_ScopeProcessor.vcx", TOOL_PROMPT )

		TRY
			*-- Disable these 2 options, since this process always
			*-- drills down into the project or folder, so these options
			*-- are irrelevant.
			loScopeForm.lProjectHomeDirectory = .F.
			loScopeForm.chklProjectHomeDirectory.Enabled = .F.
			loScopeForm.lSubDirectories = .F.
			loScopeForm.chklSubDirectories.Enabled = .F.

			loScopeForm.Show(1)

			*-- If the form doesn't exist as this point, it's usually
			*-- because the form was closed without clicking the "Go"
			*-- button.
			IF NOT VARTYPE( m.loScopeForm ) = "O"
				ERROR "Process cancelled by user -- no scope selected for this process."
			ENDIF

			lcScope = m.loScopeForm.cScope

			*-- Determine what scope was selected in the form.
			DO CASE
				CASE DIRECTORY( m.lcScope )
					*-- Folder
					llScopeIsProject = .F.

				CASE FILE( m.lcScope ) ;
						AND UPPER( JUSTEXT( m.lcScope ) ) == "PJX"
					*-- Project
					llScopeIsProject = .T.

				OTHERWISE
					*-- Don't know what, but it isn't valid.
					ERROR "Selected scope is invalid for this process." + CHR(13) ;
							+ "Scope: " + TRANSFORM( m.lcScope )
			ENDCASE

		CATCH TO loErrorInfo
			llSuccess = .F.
		ENDTRY

		loScopeForm.Release()
ENDCASE

IF m.llSuccess
	*-- We're ready to process, so get a reference to our Git tools
	*-- class.
	TRY
		loGitUtilities = EXECSCRIPT( _Screen.cThorDispatcher, "Thor_Proc_GitUtilities" )

	CATCH TO loErrorInfo
		llSuccess = .F.
	ENDTRY
ENDIF

*-- Here's where the processing actually occurs.
DO CASE
	CASE NOT m.llSuccess
		*-- Something failed already, so nothing to do.

	CASE m.llScopeIsProject
		*-- Process a project.
		WAIT WINDOW "Saving timestamps for files in project" + CHR(13) + m.lcScope NOWAIT NOCLEAR
		llSuccess = m.loGitUtilities.SaveProjectTimestampFiles( @m.loErrorInfo, m.lcScope )

	OTHERWISE
		*-- Processing a folder.
		WAIT WINDOW "Saving timestamps for files in folder" + CHR(13) + m.lcScope NOWAIT NOCLEAR
		llSuccess = m.loGitUtilities.SaveRepoTimestampFile( @m.loErrorInfo, m.lcScope )
ENDCASE

WAIT CLEAR

*-- Display the results.
IF m.llSuccess
	MESSAGEBOX( "Timestamps successfully saved for" + CHR(13) + m.lcScope, 64, TOOL_PROMPT, 3000 )
ELSE
	MESSAGEBOX( m.loErrorInfo.Message, 16, TOOL_PROMPT )
ENDIF

*-- Provide a return value that can be used if you call this process
*-- from some other code.
RETURN EXECSCRIPT( _Screen.cThorDispatcher, "Result=", m.llSuccess )
ENDPROC


*********************************************************************
*-- Option classes
*********************************************************************
DEFINE CLASS clsTimestampFileName AS Custom
	Tool = ccToolName
	Key = ccKeyTimestampFileName
	Value = ccInitialValueTSFileName
	EditClassName = [ccEditClassName of Thor_Proc_GitUtilities.PRG]
ENDDEFINE
