#!/bin/sh
cd "$1"

sed '/^#/q' common.mk # mode-line
for f in version.h revision.h; do
    test -f "$f" || continue
    sed -n \
	-e '/^#define \(RUBY_RELEASE_[A-Z]*\) \([0-9][0-9]*\)/{' \
	-e   's//\1 = \2/' \
	-e   's/ \([0-9]\)$/ 0\1/' \
	-e   p \
	-e '}' "$f"
done
exec sed '1s/^#.*//;s/{\$([^(){}]*)[^{}]*}//g' common.mk
