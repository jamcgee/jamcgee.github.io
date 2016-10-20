HTMLDIR?=/var/www/test
CSSTIDY=bin/css-compress
XSLTPROC=xsltproc
INSTALL=bin/minstall -v


.PHONY: all clean install

all: content/index.html content/resume.html style/theme-min.css \
	error/401.html error/403.html error/404.html error/410.html error/50x.html

bin/css-compress: bin/css-compress.c

clean:
	rm -f ${CSSTIDY} content/*.html error/*.html style/*-min.*

install: all
	${INSTALL} -d ${HTMLDIR}/resume ${HTMLDIR}/style ${HTMLDIR}/images \
		${HTMLDIR}/error
	${INSTALL} -z content/index.html ${HTMLDIR}/index.html
	${INSTALL} -z content/resume.html ${HTMLDIR}/resume/index.html
	${INSTALL}    data/BingSiteAuth.xml data/google*.html data/robots.txt \
		${HTMLDIR}/
	${INSTALL}    error/*.html ${HTMLDIR}/error
	${INSTALL}    images/*.jpg ${HTMLDIR}/images
	${INSTALL} -z style/theme-min.css ${HTMLDIR}/style/theme.css


.SUFFIXES: .html .xhtml

.xhtml.html: style/theme.xslt
	${XSLTPROC} -o $@ style/theme.xslt $<


style/theme-min.css: style/theme.css ${CSSTIDY}
	${CSSTIDY} < style/theme.css > $@
