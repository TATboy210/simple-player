## 1.3.0

* Add macOS native fullscreen support (NSWindow.toggleFullScreen)
* Update SDK constraint for Dart 3.x (>=3.0.0 <4.0.0)
* Migrate deprecated APIs: dart:html → package:web
* Add plugin_platform_interface dependency for proper federated plugin structure
* Rename FullScreenWindow → fullScreenWindow (lowerCamelCase convention)
* Add comprehensive test suite (39 tests):
  - Method channel mock tests (platform-level binary simulation)
  - Platform interface mock tests (business logic verification)
  - Mock platform tests (original test restoration)
* Add GitHub Actions CI/CD (Windows/Linux/macOS matrix)
* Fix dart format compliance

## 1.2.1

* Support multi window with package `desktop_multi_window`

## 1.2.0

* support Linux platform

## 1.1.0

* migrate dart:html to package:web to support WASM in web

## 1.0.4

* change sdk version limitation

## 1.0.3

* Fix plugin issue

## 1.0.2

* Add support for Web / Android / iOS

## 1.0.1

* Fix layout issue when maximize -> enter fullscreen -> exit fullscreen.

## 1.0.0

* Initial version
