FLAGS ?= --minify
TESTFLAGS ?= --buildDrafts --buildFuture --cleanDestinationDir
BASEDIR ?= /zdata/db/www

# Build for release
all:
	hugo -v ${FLAGS}

# Clear out all generated content
clean:
	rm -rf public resources

# Run local server for testing
server:
	hugo server --baseURL=http://localhost/ ${TESTFLAGS}

# Install into test server
TESTHOST ?= test.etherealwake.com
TESTBASE ?= ${BASEDIR}/${TESTHOST}
test:
	hugo --baseURL=https://${TESTHOST}/ --destination=${TESTBASE} ${TESTFLAGS}

# Install into production server
RELHOST ?= etherealwake.com
RELBASE ?= ${BASEDIR}/${RELHOST}
release:
	hugo --destination=${RELBASE} ${FLAGS}
