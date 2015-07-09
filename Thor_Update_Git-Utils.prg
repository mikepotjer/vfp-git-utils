LPARAMETERS loUpdateObject

WITH loUpdateObject
    .VersionLocalFilename = 'GitUtilitiesVersionFile.txt'
	.VersionFileURL       = 'https://bitbucket.org/mikepotjer/vfp-git-utils/downloads/GitUtilitiesVersionFile.txt'
ENDWITH

RETURN loUpdateObject
