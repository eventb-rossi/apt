# Bundled components in the LTSmin 3.0.2 Linux release

This inventory describes the upstream `ltsmin-v3.0.2-linux.tgz` artifact. It
was derived from the release-tagged Travis build scripts and checked against
the published ELF binaries. The release was built on Ubuntu 14.04 with GCC
7.3.0; the LTSmin build links the libraries below statically unless noted
otherwise.

| Component | Version | License | Provenance |
| --- | --- | --- | --- |
| LTSmin | 3.0.2 | BSD-3-Clause | release source and `COPYING` |
| ltl2ba | commit `92bed4de114eeda3c2ed93f89139cd5b6e56908a` | GPL-2.0-or-later | LTSmin submodule and bundled `README` |
| SpinS | 1.1, commit `bfca30be3ce81fd77b31b9d47043145ae66ddc96` | Apache-2.0; generated JavaCC code is BSD-3-Clause | LTSmin submodule, JAR manifest and SpinS license files |
| DiVinE | 2.4+89a87b2 (LTSmin integration release 1.3) | BSD-2-Clause, GPL-2.0-only, LGPL-2.1-only and LicenseRef-DiVinE-Murphi; full component terms are documented in `DiVinE-COPYING` | `travis/install-DiVinE.sh`, the tagged DiVinE release and helper `--version` output; the Ubuntu binary package omits this helper because noble has no ncurses 5 compatibility ABI |
| mCRL2 | 201707.1 | BSL-1.0 | `travis/install-mCRL2-generic.sh` and helper `--version` output |
| dparser | 1.26.mCRL2 | BSD-3-Clause | merged into mCRL2's static core archive by the release build |
| ZeroMQ | 4.1.5 | LGPL-3.0-or-later WITH Independent-modules-exception | `travis/install-generic.sh` |
| CZMQ | 3.0.2 | MPL-2.0 | `travis/install-generic.sh` |
| Sylvan | 1.1.1 | Apache-2.0 | `travis/install-generic.sh` |
| Spot, including its BuDDy fork | 2.3.3 | GPL-3.0-or-later | `travis/install-generic.sh` |
| ViennaCL | 1.7.1 | MIT | `travis/install-generic.sh` |
| Boost | 1.54.0 | BSL-1.0 | Ubuntu 14.04 `libboost-dev`; template code is compiled into the binaries |
| popt | 1.16 | MIT | Ubuntu 14.04 static archive copied by `travis/build-release-linux.sh` |
| GMP | 5.1.3 | LGPL-3.0-or-later (selected from GPL-2.0-or-later OR LGPL-3.0-or-later) | Ubuntu 14.04 static archive copied by the release build |
| GNU libltdl | 2.4.2 | LGPL-2.1-or-later | Ubuntu 14.04 static archive copied by the release build |
| libxml2 | 2.9.1 | MIT | Ubuntu 14.04 static archive copied by the release build |
| liblzma | 5.1.1alpha | 0BSD | Ubuntu 14.04 static archive copied by the release build |
| hwloc | 1.8 | BSD-3-Clause | Ubuntu 14.04 static archive copied by the release build |
| libnuma | 2.0.9 | LGPL-2.1-only | Ubuntu 14.04 static archive copied by the release build |
| zlib | 1.2.8 | Zlib | release build recipe and embedded zlib version strings |
| libgcc and libstdc++ runtime code | 7.3.0 | GPL-3.0-or-later WITH GCC-exception-3.1 | `-static-libgcc -static-libstdc++` and ELF compiler comments |

The release recipe is available under the `v3.0.2` tag in the upstream LTSmin
repository, principally in `travis/install-generic.sh`,
`travis/install-mCRL2-generic.sh`, `travis/install-DiVinE.sh`, and
`travis/build-release-linux.sh`.
