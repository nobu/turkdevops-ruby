#!/bin/sh -e

# usage: $0 [up]
#
# Prepare platform independent source files.
# If argument `up` is given, update the source tree first.

PWD=

tooldir=`dirname $0`/
srcdir=`dirname "$tooldir"`

"$srcdir/autogen.sh"

: ${MAKE=make}

tmpdir=`mktemp -d`
trap 'rm -rf "$tmpdir"' 0 2
echo "all:; @echo yes" > "$tmpdir/GNUmakefile"
echo "all:; @:" > "$tmpdir/Makefile"
gnumake=`(cd "$tmpdir"; ${MAKE})`
rm "$tmpdir/Makefile" "$tmpdir/GNUmakefile"
rmdir "$tmpdir"

clean=
trap 'rm -f $clean'  0 2
for touch in config.status .rbconfig.time; do
    if [ ! -f $touch ]; then
        clean="$clean $touch"
        > $touch
    fi
done
prereq="sed -f ${tooldir}prereq.status"
{
    ${gnumake:+$prereq \
        -e '/^include Makefile/{' -e 's/^/#/' -e 'q' -e '}'
        "$srcdir/template/GNUmakefile.in"}
    $prereq "$srcdir/template/Makefile.in"
    ${gnumake:+$prereq \
        -e '1,/^include Makefile/d' \
        -e '/^-include uncommon\.mk/{' -e 's/^/#/' -e 'q' -e '}' \
        "$srcdir/template/GNUmakefile.in"}
    $prereq "$srcdir/common.mk"
    ${gnumake:+$prereq \
        -e '1,/^-include uncommon\.mk/d' \
        "$srcdir/template/GNUmakefile.in"}
} |
${MAKE} -f - ${@-prereq} clean
