#!/bin/sh
set -eu

rm -rf ./flutter-sdk ./flutter
curl -L https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.38.9-stable.tar.xz | tar -xJ
mv ./flutter ./flutter-sdk
git config --global --add safe.directory "$(pwd)/flutter-sdk"
./flutter-sdk/bin/flutter config --no-analytics
./flutter-sdk/bin/flutter pub get
