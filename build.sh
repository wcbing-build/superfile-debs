#!/bin/sh
set -e

# Check and extract version number
[ $# != 1 ] && echo "Usage:  $0 <latest_releases_tag>" && exit 1
VERSION=$(echo "$1" | sed -n 's|[^0-9]*\([^_]*\).*|\1|p') && test "$VERSION"

PACKAGE=superfile
REPO=yorukot/superfile

ARCH_LIST="amd64 arm64"
AMD64_FILENAME=superfile-linux-v"$VERSION"-amd64.tar.gz
ARM64_FILENAME=superfile-linux-v"$VERSION"-arm64.tar.gz

prepare() {
    mkdir -p output tmp
    curl -fs https://api.github.com/repos/$REPO/releases/latest | jq -r '.body' | gzip > tmp/changelog.gz
}

build() {
    BASE_DIR=tmp/"$PACKAGE"_"$ARCH" && rm -rf "$BASE_DIR"
    install -D templates/copyright -t "$BASE_DIR/usr/share/doc/$PACKAGE"
    install -D tmp/changelog.gz -t "$BASE_DIR/usr/share/doc/$PACKAGE"

    # Download and move file
    curl -fsLo "tmp/$PACKAGE-$ARCH.tar.gz" "$(get_url_by_arch "$ARCH")"
    TMPDIR=$(mktemp -dp .)
    tar -xf "tmp/$PACKAGE-$ARCH.tar.gz" -C "$TMPDIR"
    install -D -m 755 -t "$BASE_DIR/usr/bin" "$TMPDIR/dist/superfile-linux-v$VERSION-$ARCH/spf"
    rm -rf "$TMPDIR"

    # Package deb
    mkdir -p "$BASE_DIR/DEBIAN"
    SIZE=$(du -sk "$BASE_DIR"/usr | cut -f1)
    echo "Package: $PACKAGE
Version: $VERSION+1
Architecture: $ARCH
Installed-Size: $SIZE
Maintainer: wcbing <i@wcbing.top>
Section: utils
Priority: optional
Homepage: https://github.com/$REPO
Description: Perfect Terminal-based file manager!
 superfile is a very fancy and modern terminal file manager
 that can complete the file operations you need!!
 .
 Please note: the executable were named 'spf'.
" > "$BASE_DIR/DEBIAN/control"

    dpkg-deb -b --root-owner-group -Z xz "$BASE_DIR" output
}

get_url_by_arch() {
    DOWNLOAD_PREFIX="https://github.com/$REPO/releases/latest/download"
    case $1 in
    "amd64") echo "$DOWNLOAD_PREFIX/$AMD64_FILENAME" ;;
    "arm64") echo "$DOWNLOAD_PREFIX/$ARM64_FILENAME" ;;
    esac
}

prepare

for ARCH in $ARCH_LIST; do
    echo "Building $ARCH package..."
    build
done

# Create repo files
cd output && apt-ftparchive packages . > Packages && apt-ftparchive release . > Release
