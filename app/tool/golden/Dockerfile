# Linux image that renders and checks golden images (T-015).
#
# Goldens are rendered only on Linux so they match CI exactly
# (docs/decisions.md 2026-10-11). This image installs the same Flutter
# release as app.yml, with the same checksum-verified script, on the same OS
# as the CI runner (ubuntu-24.04, x64). Do not run it directly: use
# app/tool/golden/goldens.sh, which builds it and mounts the repository.
#
# Base image: the official Ubuntu 24.04 image, pinned by index digest. Like
# the CI runner it contains GPL and LGPL system packages; the image is built
# and run only on developer machines and is never pushed or distributed.
# goldens.sh builds and runs it with --platform linux/amd64, like CI.
FROM ubuntu:24.04@sha256:534baea6a22c03a63003dbc8dbe78fe34bc0d7e595d9a9dc9834884ff530eb55

ARG FLUTTER_VERSION

# curl and jq for the install script, xz-utils to unpack the SDK, unzip for
# the Flutter tool's own downloads (the Material fonts are a zip), git
# because the Flutter SDK is a git checkout, ca-certificates for https.
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl git jq unzip xz-utils \
  && rm -rf /var/lib/apt/lists/*

COPY ci/install_flutter.sh /tmp/install_flutter.sh
RUN test -n "$FLUTTER_VERSION" \
  && bash /tmp/install_flutter.sh "$FLUTTER_VERSION" /opt \
  && rm /tmp/install_flutter.sh

ENV PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH

# One throwaway test run downloads exactly what `flutter test` needs (the
# Linux flutter_tester engine and the Material fonts the goldens load), so
# later runs need the network only for pub packages. `flutter precache`
# would also fetch iOS tools the goldens do not need.
COPY golden/warm_up.sh /tmp/warm_up.sh
RUN bash /tmp/warm_up.sh && rm /tmp/warm_up.sh

COPY golden/in_container.sh /usr/local/bin/bgc-goldens
ENTRYPOINT ["bash", "/usr/local/bin/bgc-goldens"]
