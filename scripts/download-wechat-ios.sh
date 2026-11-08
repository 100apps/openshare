#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build
curl --fail --location --retry 3 \
  https://dldir1.qq.com/WechatWebDev/opensdk/XCFramework/OpenSDK2.0.9.zip \
  --output .build/wechat-ios.zip
echo 'ebbdd935f840bedabe1c39ad6149356b37764645ff939ce0160a438520545697  .build/wechat-ios.zip' | shasum -a 256 -c -
unzip -oq .build/wechat-ios.zip -d .build
