#!/usr/bin/env bash
# Assemble the LTSmin orig tarball from the complete upstream Linux binary
# release and its matching source release.  The source tree supplies generated
# manuals, shell completion and notices; the package intentionally does not
# rebuild the legacy release.
set -euo pipefail
: "${ROOT:?}" "${PKG:?}" "${UVER:?}" "${ORIG:?}" "${DOWNLOADS:?}"
source "$ROOT/scripts/lib.sh"

base="https://github.com/utwente-fmt/ltsmin/releases/download/v${UVER}"
binary="$DOWNLOADS/ltsmin-${UVER}-linux.tgz"
source_archive="$DOWNLOADS/ltsmin-${UVER}-source.tgz"
fetch "$base/ltsmin-v${UVER}-linux.tgz" "$binary"
fetch "$base/ltsmin-v${UVER}-source.tgz" "$source_archive"

work=$(mktemp -d)
tar -C "$work" -xzf "$binary"
[ -d "$work/v${UVER}" ] || {
    echo "binary archive did not yield v${UVER}/" >&2
    exit 1
}

d="$ROOT/build/${PKG}-${UVER}"
rm -rf "$d"
mv "$work/v${UVER}" "$d"
rm -rf "$work"

# Keep the source tree nested, matching the Fedora package layout.  This makes
# it unambiguous which files are installed binaries and which are documentation
# inputs only.
tar -C "$d" -xzf "$source_archive"
[ -d "$d/ltsmin-${UVER}/doc" ] || {
    echo "source archive did not yield ltsmin-${UVER}/doc/" >&2
    exit 1
}

# The releases omit complete notices for several statically linked components.
# Fetch the same canonical and component-specific texts audited by eventb-copr.
license_dir="$d/licenses"
mkdir -p "$license_dir"
fetch_license() {
    local url="$1" name="$2" cached
    cached="$DOWNLOADS/ltsmin-${UVER}-${name}"
    fetch "$url" "$cached"
    cp "$cached" "$license_dir/$name"
}

spdx="https://raw.githubusercontent.com/spdx/license-list-data/main/text"
fetch_license "$spdx/GPL-2.0-or-later.txt" GPL-2.0-or-later.txt
fetch_license "$spdx/Apache-2.0.txt" Apache-2.0.txt
fetch_license "$spdx/BSL-1.0.txt" BSL-1.0.txt
fetch_license "$spdx/BSD-2-Clause.txt" BSD-2-Clause.txt
fetch_license "$spdx/GPL-3.0-or-later.txt" GPL-3.0-or-later.txt
fetch_license "$spdx/GCC-exception-3.1.txt" GCC-exception-3.1.txt
fetch_license "$spdx/LGPL-2.1-or-later.txt" LGPL-2.1-or-later.txt
fetch_license "$spdx/LGPL-3.0-or-later.txt" LGPL-3.0-or-later.txt
fetch_license "$spdx/MIT.txt" MIT.txt
fetch_license "$spdx/MPL-2.0.txt" MPL-2.0.txt
fetch_license "$spdx/Zlib.txt" Zlib.txt
fetch_license "$spdx/0BSD.txt" 0BSD.txt
fetch_license \
    "https://raw.githubusercontent.com/utwente-fmt/divine2/1.3/COPYING" \
    DiVinE-COPYING
fetch_license \
    "https://raw.githubusercontent.com/utwente-fmt/spins/bfca30be3ce81fd77b31b9d47043145ae66ddc96/doc/LICENSE.txt" \
    SpinS-LICENSE.txt
fetch_license \
    "https://raw.githubusercontent.com/utwente-fmt/spins/bfca30be3ce81fd77b31b9d47043145ae66ddc96/lib/javacc.LICENSE" \
    SpinS-JavaCC-LICENSE
fetch_license \
    "https://raw.githubusercontent.com/zeromq/zeromq4-1/v4.1.5/README.md" \
    ZeroMQ-README.md
fetch_license \
    "https://raw.githubusercontent.com/mCRL2org/mCRL2/mcrl2-201707.1/3rd-party/dparser/COPYRIGHT" \
    dparser-COPYRIGHT

cp "$PKGDIR/bundled-components.md" "$d/BUNDLED-COMPONENTS.md"
pack_orig
