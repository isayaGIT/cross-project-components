#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RESOURCES="$ROOT/Resources"
mkdir -p "$RESOURCES"

xcrun -sdk iphonesimulator metal -c -target air64-apple-ios17.0-simulator \
  -o "$RESOURCES/LiquidBlobBar-simulator.air" "$ROOT/LiquidBlobBar.metal"
xcrun -sdk iphonesimulator metallib "$RESOURCES/LiquidBlobBar-simulator.air" \
  -o "$RESOURCES/LiquidBlobBar-simulator.metallib"
xcrun -sdk iphoneos metal -c -target air64-apple-ios17.0 \
  -o "$RESOURCES/LiquidBlobBar-device.air" "$ROOT/LiquidBlobBar.metal"
xcrun -sdk iphoneos metallib "$RESOURCES/LiquidBlobBar-device.air" \
  -o "$RESOURCES/LiquidBlobBar-device.metallib"
rm "$RESOURCES/LiquidBlobBar-simulator.air" "$RESOURCES/LiquidBlobBar-device.air"
