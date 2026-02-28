#!/usr/bin/env bash

test -z "$COMPRESSLEVEL" && COMPRESSLEVEL=9

if [ -n "$BINARYPACKAGE" ]; then
  SUFFIX=""
else
  SUFFIX="_src"
  BINARYPACKAGE="0"
fi

TMPDIR=$(mktemp -d)

BASEDIR=$(pwd)

set +e
REVHASH=$(git rev-parse --short HEAD)
set -e

OSXCROSSVER=$(grep "^VERSION=" build.sh | head -n1 | cut -d= -f2)

pushd "$TMPDIR"

mkdir osxcross
pushd osxcross

if [ $BINARYPACKAGE != "1" ]; then
  cp -r "$BASEDIR/tarballs" .
  cp -r "$BASEDIR/patches" .
  cp -r "$BASEDIR/tools" .
  cp -r "$BASEDIR/oclang" .
  cp -r "$BASEDIR/wrapper" .
else
  # Warn if ld is dynamically linked against libLTO.so (binary portability issue)
  set +e
  ld_bin=$(ls "$BASEDIR/target/bin/x86_64-apple-darwin"*"-ld" 2>/dev/null | head -n1)
  if [ -n "$ld_bin" ] && ldd "$ld_bin" 2>/dev/null | grep -q "libLTO.so"; then
    echo "-->> WARNING: ld is linked dynamically against libLTO.so!" \
         "Consider recompiling with DISABLE_LTO_SUPPORT=1 <<--"
    sleep 5
  fi
  set -e

  cp -r "$BASEDIR/target"/* .
  cp "$BASEDIR/build/cctools"*/cctools/APPLE_LICENSE CCTOOLS.LICENSE

  READMEINSTALL="README_INSTALL"
  {
    echo "- BINARY INSTALLATION INSTRUCTIONS -"
    echo ""
    echo "Add "
    echo ""
    echo "  \`<absolute path>/bin/osxcross-env\`"
    echo ""
    echo "To your ~/.profile or ~/.bashrc,"
    echo "then restart your shell session."
    echo ""
    echo "That's it."
    echo ""
  } > "$READMEINSTALL"
fi

find "$BASEDIR" -maxdepth 1 -type f -exec cp {} . \;

if [ $BINARYPACKAGE == "1" ]; then
  rm -f *.sh
  rm -f TODO
fi

rm -rf tarballs/old* tarballs/gcc* tarballs/MacOSX*
rm -f tools/cpucount
rm -f osxcross*.tar.*

find . \( -name "*.save" -o -name "*~" -o -name "*.kate-swp" \) -exec rm {} \;

rm -rf osxcross*.tar.*

popd

tar -cf - * | xz -$COMPRESSLEVEL -c - > "$BASEDIR/osxcross-v${OSXCROSSVER}_${REVHASH}${SUFFIX}.tar.xz"

popd

rm -rf "$TMPDIR"