all:
	hugo -v --cleanDestinationDir --enableGitInfo
clean:
	rm -rf public
server:
	hugo server
