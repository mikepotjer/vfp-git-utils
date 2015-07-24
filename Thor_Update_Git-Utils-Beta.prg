LPARAMETERS loUpdateObject

WITH loUpdateObject
    .ApplicationName      = 'Git Utilities (Beta)'
    .Component            = 'No'
    .ToolName             = 'Thor_Tool_ThorInternalRepository'
    .VersionLocalFilename = 'GitUtilitiesVersionFile-Beta.txt'
	.VersionFileURL       = 'https://bitbucket.org/mikepotjer/vfp-git-utils/downloads/GitUtilitiesVersionFile-Beta.txt'
ENDWITH

RETURN loUpdateObject
