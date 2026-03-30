#!/usr/bin/env bash
set -e

# Version Deduction Script for Navidrome Build
# Fetches the latest stable releases from GitHub and Debian Salsa.

echo "Detecting latest stable versions..."

# Navidrome
NAVIDROME_VERSION=$(curl -s https://api.github.com/repos/navidrome/navidrome/releases/latest | jq -r .tag_name | sed 's/^v//')
echo "Navidrome: ${NAVIDROME_VERSION}"

# FFmpeg (Tracking tags starting with 'n', filtering out -dev)
FFMPEG_VERSION=$(curl -s https://api.github.com/repos/FFmpeg/FFmpeg/tags | jq -r '.[].name' | grep '^n[0-9]' | grep -v '\-dev' | head -n 1 | sed 's/^n//')
echo "FFmpeg: ${FFMPEG_VERSION}"

# Opus (GitHub Mirror Releases)
OPUS_VERSION=$(curl -s https://api.github.com/repos/xiph/opus/releases/latest | jq -r .tag_name | sed 's/^v//')
echo "Opus: ${OPUS_VERSION}"

# TagLib
TAGLIB_VERSION=$(curl -s https://api.github.com/repos/taglib/taglib/releases/latest | jq -r .tag_name | sed 's/^v//')
echo "TagLib: ${TAGLIB_VERSION}"

# Lame (Debian Salsa)
# Project ID 8041 for multimedia-team/lame
MP3LAME_VERSION=$(curl -s "https://salsa.debian.org/api/v4/projects/8041/repository/tags?per_page=100" | jq -r '.[].name' | grep '^debian/' | grep -v 'svn' | sort -V | tail -n 1 | sed 's/^debian\///')
# Note: If svn is preferred as "latest maintained", remove the grep -v 'svn'. User asked for "where it's maintained".
echo "Lame (Debian): ${MP3LAME_VERSION}"

# Zlib (GitHub Mirror)
ZLIB_VERSION=$(curl -s https://api.github.com/repos/madler/zlib/releases/latest | jq -r .tag_name | sed 's/^v//')
# If GitHub releases are empty, fallback to a known stable or scrape zlib.net
if [ "${ZLIB_VERSION}" == "null" ] || [ -z "${ZLIB_VERSION}" ]; then
    ZLIB_VERSION=$(curl -s https://zlib.net/ | grep -oE 'zlib-[0-9.]+\.tar\.gz' | head -n 1 | sed 's/zlib-//;s/\.tar\.gz//')
fi
echo "Zlib: ${ZLIB_VERSION}"

# Update package-versions.txt
# Using KEY=VALUE format for easier shell parsing if needed, but keeping it simple for Dockerfile.
cat <<EOF > package-versions.txt
# Navidrome Build Versions (Generated)
navidrome-${NAVIDROME_VERSION}
ffmpeg-${FFMPEG_VERSION}
opus-${OPUS_VERSION}
mp3lame-${MP3LAME_VERSION}
taglib-${TAGLIB_VERSION}
zlib-${ZLIB_VERSION}
EOF

echo "Done! package-versions.txt updated."
