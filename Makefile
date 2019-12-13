HTMLDIR?=/zdata/db/www/test.etherealwake.com
RELEASE?=/zdata/db/www/etherealwake.com
PARAMS=--cleanDestinationDir --enableGitInfo --noChmod --noTimes

all:
	hugo -v ${PARAMS}
clean:
	rm -rf public
install:
	hugo ${PARAMS} --minify --destination ${HTMLDIR}
server:
	hugo server
release:
	hugo ${PARAMS} --minify --destination ${RELEASE}
