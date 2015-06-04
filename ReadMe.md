# Git Utilities  

Thor repository tools to make it easier to work with Git in a VFP development environment.  

### Prerequisites

The following items are required to take full advantage of the Git utilities:  

 - [Thor](http://vfpx.codeplex.com/wikipage?title=Thor) - The Thor framework must be loaded as part of
   the VFP development environment.  
 - The Thor Repository (this is a collection of tools, and not to be confused with a Git repository)  
 - [FoxBin2Prg](http://vfpx.codeplex.com/wikipage?title=FoxBin2Prg) - The minimum required version
   is 1.19.42.  For best results, FoxBin2Prg should be installed via Thor's "Check for Updates"
   feature.  If FoxBin2Prg is installed some other way, the Thor plug-in "Get FoxBin2Prg Folder"
   can be edited to tell Thor where you have FoxBin2Prg installed.  
 - [Git for Windows](http://git-scm.com/download/win) - When installing Git for Windows, at the step
   entitled **Adjusting your Path environment**, select the second option "Use Git from the Windows
   Command Prompt".  
 - Windows Scripting Host - This is installed as part of Windows, but system administrators will
   sometimes disable it on the PCs on their networks.  

#### Getting Started with Git

If you are new to Git, I've created a
[setup guide](https://drive.google.com/file/d/0B1GXcfuc1fBubFpUS2VmSVNpUEk/view?usp=sharing)
for getting started with Git.  This guide includes:  

 - some basic instructions for installing Git and some useful third-party tools
 - some tips on configuring Git and the tools
 - information on SSH keys
 - a list of resources, including documentation, articles, and links to Git and all the tools
   referenced  

### Installation

Installation is simple.  Just copy the include file (.h) and the .PRG files into the `My Tools` folder
of Thor.  This can be easily accessed from the Thor menu by selecting `Thor > More > Open Folder >
My Tools`.  

When installed, these tools will appear in the Thor tools menus under `Applications > Git Utilities`.

### Tool Options

The options for these tools are found under **Git Utilities** on the Options page of the Thor
Configuration form.  The same options can also be accessed from the _Options_ link on the tool
page of each tool that is affected by the options.

### Description of Tools

#### `Thor_Proc_GitUtilities.PRG`
This is the main program file, which defines the Git utilities class that contains all the features
used by the other tools in this collection.  If you want to access the features of this class
directly, you can do so using the following command:  

```
loGitUtils = EXECSCRIPT( _Screen.cThorDispatcher, "Thor_Proc_GitUtilities" )
```  

The code contains documentation for all of the properties, methods, parameters, and return values.

#### `Thor_Tool_GitUtilities_PrepareForCommit.PRG`
This tool appears under the Git Utilities menu as **Prepare for Git commit**.  It operates on either
an entire VFP project, or an individual Git repository folder.  It performs several operations to
prepare VFP files to be committed to their respective repositories.  

 - When a project is processed, a text version of the project file itself is generated.
 - A text file is generated for each VFP binary file which has been modified since the last commit.
   The FoxBin2Prg configuration settings determine which binary files have text files generated
   for them, and how the file is generated.
 - For any binary file that has changed because VFP generated new object code, but the source code
   has *not* changed (the text file is still the same), the changes to the binary file will be
   reverted.
 - In the Git Utilities options, if you have specified that timestamp files are be generated,
   then the timestamp file for each repository being processed will be updated accordingly.

**Please Note:** This tool assumes that both the VFP binary files and their corresponding text
files are being committed to the Git repositories (with the exception of the .PJX file).  If
only binary or only text files are being committed, then this tool will not be very helpful,
and may even undo some legitimate changes, and therefore should not be used.

#### `Thor_Tool_GitUtilities_PostCheckoutSynch.PRG`
This tool appears under the Git Utilities menu as **Post-checkout file synchronization**.  It
operates on either an entire VFP project (all the repositories in that project), or an individual
Git repository folder.  It performs several operations to synchronize binary files and object code
to files that have been checked out from a branch of a Git repository.  

 - If the selected repositories contain FoxBin2Prg text files for .PJX files, the .PJX files will
   be regenerated.  
   **Note:** This assumes you don't commit .PJX/.PJT files to your repositories.
 - For any binary menu files (.MNX) in the repositories, the code files (.MPR) will be regenerated
   and recompiled using whatever program is specified in the VFP `_GENMENU` system variable.  
   **Note:** This assumes you don't commit .MPR/.MPX files to your repositories.
 - All program files in the repositories will be recompiled.   
   **Note:** This assumes you don't commit .FXP files to your repositories.  

Since this tool finds and regenerates .PJX files for all the project text files in the selected
repositories, it is normally simpler and faster than running FoxBin2Prg directly.  In addition,
regenerating and recompiling just the menus and programs is faster than recompiling an entire
project to accomplish the same end result, and will save time when running the **Prepare for Git
commit** tool, since it won't change the object code in the other VFP binary files.  

#### `Thor_Tool_GitUtilities_SaveProjectTimeStamps.PRG`
This tool appears under the Git Utilities menu as **Save file timestamps**.  It operates on either
an entire VFP project, or an individual Git repository folder.  The purpose of this tool is to
preserve the modification date of each file being tracked in a repository, which Git does not do.
Whenever files are checked out of a Git repository, they are assigned the current system date and
time.  However, sometimes it is nice to know the last time a particular file was modified.  This
tool creates/updates a timestamp file in the root folder of each repository being processed, saving
the last modification date for each file being tracked in the repository.

#### `Thor_Tool_GitUtilities_RestoreProjectTimeStamps.PRG`
This tool appears under the Git Utilities menu as **Restore file timestamps**.  It operates on
either an entire VFP project, or an individual Git repository folder.  Its purpose is to restore
the modification dates for all files listed in the timestamp files created by the *Save file
timestamps* tool.

#### `Thor_Tool_GitUtilities_ShowReposInProject.PRG`
This tool appears under the Git Utilities menu as **Show Git repos in project**.  It operates on
the active VFP project, or if no project is open, it prompts for one.  This is strictly an
informational tool, which displays a cursor containing a list of all Git repositories which
include files from the project, and the branch that is currently checked out for each project.
