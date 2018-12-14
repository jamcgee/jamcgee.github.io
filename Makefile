HTMLDIR?=/var/www/test
PARAMS=--cleanDestinationDir --enableGitInfo --noChmod --noTimes

all:
	hugo -v ${PARAMS}
clean:
	rm -rf public
install:
	hugo ${PARAMS} --minify --destination ${HTMLDIR}
server:
	hugo server
