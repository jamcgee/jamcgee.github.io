#!/bin/sh
XSLTPROC=/usr/local/bin/xsltproc
CSSTIDY=/usr/local/bin/csstidy
INSTALL=/bin/cp
STYLESHEET=style/theme.xslt
OUTPUT=/var/www/html
INPUT=`pwd`

# Build HTML files
for i in `find . -name \*.xhtml`; do
  basename=`echo $i | sed -E 's/^\\.+//'`
  out=`echo $i | sed 's/xhtml$/html/'`
  outfile="${OUTPUT}/${out}"
  if [ ! -f "${outfile}" -o "$i" -nt "${outfile}" \
        -o "${STYLESHEET}" -nt "${outfile}" ]; then
    echo "Building ${basename}..."
    ${XSLTPROC} --stringparam "documentUri" "${basename}" \
            -o "${outfile}" "${STYLESHEET}" "$i"
  else
    echo "Skipping ${basename}."
  fi
done

# Minify CSS files
for i in `find . -name \*.css`; do
  basename=`echo $i | sed -E 's/^\\.+//'`
  outfile="${OUTPUT}/${basename}"
  if [ ! -f "${outfile}" -o "$i" -nt "${outfile}" ]; then
    echo "Minifying ${basename}..."
    ${INSTALL} "$i" "${outfile}"
  else
    echo "Skipping ${basename}."
  fi
done

# Copy Remaining files
for i in `find . -name \*.jpg -or -name \*.html`; do
  basename=`echo $i | sed -E 's/^\\.+//'`
  outfile="${OUTPUT}/${basename}"
  if [ ! -f "${outfile}" -o "$i" -nt "${outfile}" ]; then
    echo "Installing ${basename}..."
    ${INSTALL} "$i" "${outfile}"
  else
    echo "Skipping ${basename}."
  fi
done
