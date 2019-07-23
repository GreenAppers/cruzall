#!/bin/sh

if ! [ -d desktop ]; then
  echo "error: Run from Flutter App directory"
  exit 1
fi

if [ "$#" -ne 1 ]; then
  echo "error Usage $0 <cruzall-desktop directory>"
  exit 1
fi

rm -rf macos linux windows
cp -R $1/example/macos .
cp -R $1/example/linux .
cp -R $1/example/windows .
cp desktop/pubspec.* .
cp desktop/main.dart lib/main.dart
