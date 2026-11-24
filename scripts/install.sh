#!/bin/sh
set -eu

repo="moislang/moil"
api="https://api.github.com/repos/$repo/releases?per_page=100"
version="${MOIL_VERSION:-}"
install_dir="${MOIL_INSTALL_DIR:-$HOME/.local/bin}"

if [ -z "$version" ]; then
    version=$(curl -fsSL "$api" \
        | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
        | grep -E '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?$' \
        | sed 's/^v//' \
        | head -n 1)
fi
if [ -z "$version" ]; then
    echo "No Moil CLI release is available. Wait for a release or set MOIL_VERSION to an existing version." >&2
    exit 1
fi
version=${version#v}
if ! printf '%s' "$version" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?$'; then
    echo "Invalid Moil version: $version" >&2
    exit 1
fi

os=$(uname -s)
arch=$(uname -m)
case "$os:$arch" in
    Linux:x86_64|Linux:amd64) platform=linux-x86_64 ;;
    Darwin:x86_64|Darwin:amd64) platform=darwin-x86_64 ;;
    Darwin:arm64|Darwin:aarch64) platform=darwin-aarch64 ;;
    *)
        echo "No Moil CLI package for $os/$arch. Available: Linux x86_64 and macOS x86_64/ARM64." >&2
        exit 1
        ;;
esac

archive="moil-$version-$platform.tar.gz"
base="https://github.com/$repo/releases/download/v$version/$archive"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM
curl -fsSL "$base" -o "$tmp_dir/$archive"
curl -fsSL "$base.sha256" -o "$tmp_dir/$archive.sha256"
expected=$(awk '{print $1}' "$tmp_dir/$archive.sha256")
if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$tmp_dir/$archive" | awk '{print $1}')
else
    actual=$(shasum -a 256 "$tmp_dir/$archive" | awk '{print $1}')
fi
if [ "$actual" != "$expected" ]; then
    echo "Checksum verification failed for $archive" >&2
    exit 1
fi

mkdir -p "$tmp_dir/extracted" "$install_dir"
tar -xzf "$tmp_dir/$archive" -C "$tmp_dir/extracted"
install "$tmp_dir/extracted/moil" "$install_dir/moil"
echo "Installed Moil $version at $install_dir/moil"
case ":$PATH:" in
    *":$install_dir:"*) ;;
    *) echo "Add $install_dir to PATH if it is not already configured." ;;
esac
echo "Run: $install_dir/moil --version"
