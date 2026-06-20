# Event-B / B-method packages for Ubuntu & Debian

Debian/Ubuntu packaging for the [Event-B](https://www.event-b.org/) and B-method
tool ecosystem: the Rodin platform, ProB, Atelier B, and a set of supporting
command-line tools. The same software is also packaged for
[Fedora (COPR)](https://copr.fedorainfracloud.org/coprs/g/eventb-rossi/eventb-copr/),
Gentoo, and macOS (Homebrew); this repository is the Ubuntu/Debian counterpart and
tracks the same versions.

Built and tested on **Ubuntu 24.04 LTS (noble)**, `amd64`.

## Packages

| Package | Arch | Description |
|---|---|---|
| `eventb-to-txt` | all | Convert Event-B machines/contexts to CamilleX text |
| `evbt` | all | EventBTool — code generation and documentation |
| `eventb-checker` | all | Standalone Event-B model type checker |
| `eventb-animate` | all | Animate Event-B models with ProB, without Rodin |
| `tlc4b` | all | Model-check classical B via TLA+/TLC |
| `b2program` | all | Generate code from B in several languages |
| `prob2-ui` | all | ProB2 JavaFX animator / model checker UI |
| `prob` | amd64 | ProB animator, constraint solver, model checker (`prob`, `probcli`) |
| `rodin` | amd64 | Rodin Platform — Eclipse-based Event-B IDE |
| `rodin-rc` | amd64 | Rodin Platform release candidate (conflicts with `rodin`) |
| `atelier-b` | amd64 | Atelier B Community Edition (B method IDE) |
| `rossi` | amd64 | Rust toolchain for Event-B (`rossi`, `eventb-language-server`) |

## Install from the APT repository

```sh
# 1. Trust the repository signing key
curl -fsSL https://eventb-rossi.github.io/apt/KEY.gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/eventb.gpg

# 2. Add the repository
echo "deb [signed-by=/etc/apt/keyrings/eventb.gpg] https://eventb-rossi.github.io/apt noble main" \
  | sudo tee /etc/apt/sources.list.d/eventb.list

# 3. Install what you need
sudo apt update
sudo apt install rodin prob prob2-ui
```

> Replace the host (`https://eventb-rossi.github.io/apt`) with wherever you
> publish the generated `repo/` tree.

## Install from a PPA

Once the source packages are uploaded to a Launchpad PPA:

```sh
sudo add-apt-repository ppa:<owner>/eventb
sudo apt update
sudo apt install rodin prob prob2-ui
```

## Building locally

The repository ships only the Debian packaging; upstream artifacts are fetched
at build time.

```sh
# Install the build toolchain (one time)
sudo apt install dpkg-dev debhelper devscripts fakeroot lintian dh-python \
  python3-all python3-setuptools build-essential reprepro gnupg \
  desktop-file-utils unzip cpio wget curl xz-utils default-jdk openjdk-25-jre-headless

# rossi is built with Cargo and noble's apt rustc is too old, so install a
# recent toolchain via rustup (https://rustup.rs); needed for build-rossi/build-all
rustup default stable

make build-eventb-to-txt     # build one package  -> build/*.deb
make build-all               # build every package
make lint                    # run lintian over build/*.deb

# Assemble a signed APT repository under repo/
REPO_GPG_KEY=you@example.com make repo
```

Each package lives under `packages/<name>/`:

```
packages/<name>/
├── debian/        Debian packaging (control, rules, changelog, copyright, ...)
└── get-orig.sh    fetches/assembles the upstream artifact for the build
```

### Source packages for a PPA

```sh
make source-eventb-to-txt    # build/<pkg>_<ver>_source.changes
# Append ~noble1 to the changelog revision per upload, then:
dput ppa:<owner>/eventb build/<pkg>_<ver>_source.changes
```

## Layout

```
.
├── packages/            one directory per package (debian/ + get-orig.sh)
├── scripts/             build-deb.sh, make-repo.sh, version-check.py
├── conf/distributions   reprepro repository definition
├── Makefile             build / repo / lint orchestration
└── .github/workflows/   build + daily upstream version check
```

## License

The packaging in this repository is MIT-licensed (see `LICENSE`). Each packaged
project keeps its own upstream license; see the per-package `debian/copyright`.
