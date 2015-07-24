LPARAMETERS loUpdateObject

WITH loUpdateObject
    .ApplicationName      = 'Git Utilities'
    .Component            = 'No'
    .ToolName             = 'Thor_Tool_ThorInternalRepository'
    .VersionLocalFilename = 'GitUtilitiesVersionFile.txt'
	.VersionFileURL       = 'https://bitbucket.org/mikepotjer/vfp-git-utils/downloads/GitUtilitiesVersionFile.txt'
ENDWITH

RETURN loUpdateObject
