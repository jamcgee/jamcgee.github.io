HTMLDIR?=/var/www/test

all:
	hugo -v --cleanDestinationDir --enableGitInfo
clean:
	rm -rf public
install:
	hugo --cleanDestinationDir --destination ${HTMLDIR} --enableGitInfo
server:
	hugo server
