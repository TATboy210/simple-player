# fullscreen_window

This plugin makes your window fullscreen.


## Platform Support

| Windows | Linux | macOS | Web | Android | iOS |
| :-----: | :-----: | :-----: | :-----: | :-----: | :-----: |
|    ✔️    |    ✔️    |    ✔️    |    ✔️    |    ✔️    |    ✔️    |

* Windows: Native C++ (Win32 API)
* Linux: Native C (GTK3)
* macOS: Native Objective-C (NSWindow)
* Web: Dart (package:web)
* Android / iOS: Dart (Flutter API)


## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  fullscreen_window: ^1.3.0
```

Or from git:

```yaml
dependencies:
  fullscreen_window:
    git:
      url: https://github.com/jakky1/fullscreen_window.git
      ref: master
```


## Usage

```dart
import 'package:fullscreen_window/fullscreen_window.dart';

// Enter fullscreen
await fullScreenWindow.setFullScreen(true);

// Exit fullscreen
await fullScreenWindow.setFullScreen(false);

// Get screen size (logical pixel, with context)
Size logicalSize = await fullScreenWindow.getScreenSize(context);

// Get screen size (physical pixel, without context)
Size physicalSize = await fullScreenWindow.getScreenSize(null);
```


## Example

```dart
import 'package:flutter/material.dart';
import 'package:fullscreen_window/fullscreen_window.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String screenSizeText = "";

  void setFullScreen(bool isFullScreen) {
    fullScreenWindow.setFullScreen(isFullScreen);
  }

  void showScreenSize(BuildContext context) async {
    Size logicalSize = await fullScreenWindow.getScreenSize(context);
    Size physicalSize = await fullScreenWindow.getScreenSize(null);
    setState(() {
      screenSizeText = "Screen size (logical pixel): ${logicalSize.width} x ${logicalSize.height}\n";
      screenSizeText += "Screen size (physical pixel): ${physicalSize.width} x ${physicalSize.height}\n";
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('FullScreen example app'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () => setFullScreen(true),
                child: const Text("Enter FullScreen"),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => setFullScreen(false),
                child: const Text("Exit FullScreen"),
              ),
              const SizedBox(height: 10),
              Builder(builder: (context) => ElevatedButton(
                onPressed: () => showScreenSize(context),
                child: const Text("Show screen size"),
              )),
              const SizedBox(height: 10),
              if (screenSizeText.isNotEmpty) Text(screenSizeText),
            ],
          ),
        ),
      ),
    );
  }
}
```


## Testing

This package includes 39 unit tests across 3 test files:

| Test File | Tests | Description |
|-----------|-------|-------------|
| `fullscreen_window_test.dart` | 3 | Basic mock platform tests |
| `fullscreen_window_mock_test.dart` | 21 | Comprehensive platform interface tests |
| `method_channel_mock_test.dart` | 15 | Binary method channel simulation |

### Test Strategy

1. **Platform Interface Mock** — Tests business logic by replacing the platform singleton
2. **Method Channel Mock** — Tests at the binary message level, simulating each platform's native responses
3. **CI Matrix** — Tests run on Windows, Linux, and macOS via GitHub Actions

Run tests:

```bash
cd fullscreen_window
flutter test
```


## What's New in 1.3.0

- **macOS support** — Native fullscreen via `NSWindow.toggleFullScreen`
- **Dart 3.x** — Updated SDK constraint, migrated to `package:web`
- **Comprehensive tests** — 39 tests covering all platforms and edge cases
- **CI/CD** — GitHub Actions matrix testing on 3 platforms
