#!/bin/bash

set -e

# Get the latest armhf release version
VERSION=$(curl --silent -qI https://github.com/vrince/arm-beats/releases/latest \
| awk -F '/' '/^location/ {print  substr($NF, 1, length($NF)-1)}') VERSION="${VERSION#v}"

FILEBEAT_ARMHF_NAME="filebeat-${VERSION}-linux-armv7l"

# Get the filebeat binary for armhf (compatible with armv6l/armv7l)
if [ ! -f "filebeat-${VERSION}-linux-armv7l.tar.gz" ]; then
  wget "https://github.com/vrince/arm-beats/releases/download/v${VERSION}/${FILEBEAT_ARMHF_NAME}.tar.gz"
fi

INSTALL_DIR=$(pwd)

# Extract the filebeat armhf binary
rm -rf "${FILEBEAT_ARMHF_NAME}"
tar -xf "${FILEBEAT_ARMHF_NAME}.tar.gz"

# Get the official filebeat arm64 deb package
wget --no-clobber --continue "https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-${VERSION}-arm64.deb" -P "$INSTALL_DIR"
FILEBEAT_ARM64_DEB="$(find "$INSTALL_DIR" -name "filebeat-${VERSION}*-arm64.deb" -type f -printf "%f\n" | awk 'FNR <= 1')"

# Extract the official filebeat arm64 deb package
mkdir -p "$INSTALL_DIR"/armhf
dpkg-deb -x "$INSTALL_DIR"/"$FILEBEAT_ARM64_DEB" "$INSTALL_DIR"/armhf/
dpkg-deb -e "$INSTALL_DIR"/"$FILEBEAT_ARM64_DEB" "$INSTALL_DIR"/armhf/DEBIAN

# Replace the arm64 filebeat binary with the armhf filebeat binary
rm "$INSTALL_DIR"/armhf/usr/share/filebeat/bin/filebeat
rm "$INSTALL_DIR"/armhf/usr/share/filebeat/bin/filebeat-god
cp "$INSTALL_DIR"/"${FILEBEAT_ARMHF_NAME}"/filebeat "$INSTALL_DIR"/armhf/usr/share/filebeat/bin/

# Update the control file and md5sums
FILEBEAT_MD5="$(md5sum "$INSTALL_DIR"/armhf/usr/share/filebeat/bin/filebeat | awk '{print $1}')"
sed -i 's/arm64/armhf/g' "$INSTALL_DIR"/armhf/DEBIAN/control
sed -i '/filebeat-god/d' "$INSTALL_DIR"/armhf/DEBIAN/md5sums
sed -i "s/.*usr\/share\/filebeat\/bin\/filebeat.*/$FILEBEAT_MD5  usr\/share\/filebeat\/bin\/filebeat/g" "$INSTALL_DIR"/armhf/DEBIAN/md5sums

# Build the armhf filebeat deb package
cd "$INSTALL_DIR" ; dpkg-deb --root-owner-group --build armhf "filebeat-${VERSION}-armhf.deb"
