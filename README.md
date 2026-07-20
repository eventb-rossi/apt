# Event-B / B-method packages for Ubuntu & Debian

Debian/Ubuntu packaging for the [Event-B](https://www.event-b.org/) and B-method
tool ecosystem: the Rodin platform, ProB, Atelier B, and a set of supporting
command-line tools.

Built and tested on **Ubuntu 24.04 LTS (noble)**, `amd64`. One exception:
`rossi` needs `rustc >= 1.85` (Rust 2024 edition), which noble's archive does not
provide, so it targets **Ubuntu 26.04 LTS (resolute)** and is published to a
separate `resolute` suite.

## Packages

| Package | Arch | Description |
|---|---|---|
| `eventb-to-txt` | all | Convert Event-B machines/contexts to CamilleX text |
| `evbt` | all | EventBTool — code generation and documentation |
| `eventb-checker` | all | Standalone Event-B model type checker |
| `eventb-animate` | all | Animate Event-B models with ProB, without Rodin |
| `tlc4b` | all | Model-check classical B via TLA+/TLC |
| `b2program` | all | Generate code from B in several languages |
| `ltsmin` | amd64 | Language-independent sequential, multi-core, symbolic and distributed model checking |
| `prob2-ui` | all | ProB2 JavaFX animator / model checker UI |
| `prob` | amd64 | ProB animator, constraint solver, model checker (`prob`, `probcli`) |
| `rodin` | amd64 | Rodin Platform — Eclipse-based Event-B IDE |
| `rodin-rc` | amd64 | Rodin Platform release candidate (conflicts with `rodin`) |
| `rodin-headless` | all | Headless CLI to build, check, and prove Rodin Event-B models |
| `atelier-b` | amd64 | Atelier B Community Edition (B method IDE) |
| `rossi` | amd64 | Rust toolchain for Event-B (`rossi`, `eventb-language-server`) |

## Install from the APT repository

Most packages are published for **noble (24.04)**; `rossi` is published for
**resolute (26.04)**. The snippet below picks the suite matching your release.

```sh
# 1. Trust the repository signing key
curl -fsSL https://eventb-rossi.github.io/apt/KEY.gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/eventb.gpg

# 2. Add the repository for your Ubuntu release (noble or resolute)
. /etc/os-release
echo "deb [signed-by=/etc/apt/keyrings/eventb.gpg] https://eventb-rossi.github.io/apt ${VERSION_CODENAME} main" \
  | sudo tee /etc/apt/sources.list.d/eventb.list

# 3. Install what you need
sudo apt update
sudo apt install rodin prob prob2-ui ltsmin   # on resolute (26.04), rossi is also available
```

## Building locally

The repository ships only the Debian packaging; upstream artifacts are fetched
at build time.

```sh
# Install the build toolchain (one time)
sudo apt install dpkg-dev debhelper devscripts fakeroot lintian dh-python \
  python3-all python3-setuptools build-essential reprepro gnupg \
  desktop-file-utils unzip cpio wget curl xz-utils chrpath default-jdk openjdk-25-jre-headless

# rossi targets resolute (26.04) for rustc >= 1.85, so it needs two extra
# host-side tools beyond the list above:
#  - a cargo >= 1.85 to vendor its Rust 2024 crates during orig assembly
#    (install via rustup, https://rustup.rs):
rustup default stable
#  - sbuild + mmdebstrap + zstd to build it in a resolute chroot, created
#    automatically on first build (the build uses that chroot's archive rustc,
#    not rustup):
sudo apt install sbuild mmdebstrap uidmap zstd

make build-eventb-to-txt     # build one package  -> build/*.deb
make build-all               # build every package
make lint                    # run lintian over build/*.deb

# Assemble a signed APT repository under repo/
REPO_GPG_KEY=you@example.com make repo
# make repo refuses to run without REPO_GPG_KEY; pass REPO_ALLOW_UNSIGNED=1
# to build an unsigned repo for local testing only.
```

### LTSmin

`ltsmin` repackages the official 3.0.2 amd64 Linux release. It includes the
sequential, multi-core, symbolic and distributed backends and automatically
integrates with the packaged ProB commands. Java and GCC are recommended for
the optional SpinS frontend. The standalone `divine` helper is omitted because
it requires the obsolete ncurses 5 ABI, which noble does not provide; ProB and
the other LTSmin frontends do not use it.

Each package lives under `packages/<name>/`:

```
packages/<name>/
├── debian/        Debian packaging (control, rules, changelog, copyright, ...)
└── get-orig.sh    fetches/assembles the upstream artifact for the build
```

## License

The packaging in this repository is MIT-licensed (see `LICENSE`). Each packaged
project keeps its own upstream license; see the per-package `debian/copyright`.
