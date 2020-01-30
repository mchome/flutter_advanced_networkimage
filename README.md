# Flutter Advanced Network Image Provider

[![Pub Package](https://img.shields.io/pub/v/flutter_advanced_networkimage.svg)](https://pub.dev/packages/flutter_advanced_networkimage)
[![Pre Pub Package](https://img.shields.io/pub/vpre/flutter_advanced_networkimage.svg)](https://pub.dev/packages/flutter_advanced_networkimage)
[![Build Status](https://travis-ci.org/mchome/flutter_advanced_networkimage.svg?branch=master)](https://travis-ci.org/mchome/flutter_advanced_networkimage?branch=master)
[![Coverage Status](https://coveralls.io/repos/github/mchome/flutter_advanced_networkimage/badge.svg?branch=master)](https://coveralls.io/github/mchome/flutter_advanced_networkimage?branch=master)

An advanced image provider provides caching and retrying for flutter app.
Now with zoomable widget and transition to image widget.

## Getting Started

### Installation

Add this to your pubspec.yaml (or create it):

```yaml
dependencies:
  flutter_advanced_networkimage: any
```

Then run the flutter tooling:

```bash
flutter packages get
```

### Example

```dart
// using image provider
Image(
  image: AdvancedNetworkImage(
    url,
    header: header,
    useDiskCache: true,
    cacheRule: CacheRule(maxAge: const Duration(days: 7)),
  ),
  fit: BoxFit.cover,
)
// work with precacheImage
precacheImage(
  AdvancedNetworkImage(
    url,
    header: header,
    useDiskCache: true,
    cacheRule: CacheRule(maxAge: const Duration(days: 7)),
  ),
  context,
);

// or svg provider (flutter_svg)
SvgPicture(
  AdvancedNetworkSvg(url, SvgPicture.svgByteDecoder, useDiskCache: true),
)
```

```dart
// get the disk cache folder size
int cacheSize = await DiskCache().cacheSize();
```

```dart
// clean the disk cache
bool isSucceed = await DiskCache().clear();
```

```dart
// using zooming widget & transitiontoimage widget
ZoomableWidget(
  minScale: 0.3,
  maxScale: 2.0,
  // default factor is 1.0, use 0.0 to disable boundary
  panLimit: 0.8,
  child: Container(
    child: TransitionToImage(
      image: AdvancedNetworkImage(url, timeoutDuration: Duration(minutes: 1)),
      // This is the default placeholder widget at loading status,
      // you can write your own widget with CustomPainter.
      placeholder: CircularProgressIndicator(),
      // This is default duration
      duration: Duration(milliseconds: 300),
    ),
  ),
)
```

```dart
// Reload feature included
TransitionToImage(
  image: AdvancedNetworkImage(url,
    loadedCallback: () {
      print('It works!');
    },
    loadFailedCallback: () {
      print('Oh, no!');
    },
    loadingProgress: (double progress) {
      print('Now Loading: $progress');
    },
  ),
  loadingWidgetBuilder: (_, double progress, __) => Text(progress.toString()),
  fit: BoxFit.contain,
  placeholder: const Icon(Icons.refresh),
  width: 400.0,
  height: 300.0,
  enableRefresh: true,
);
```

```dart
// Scale the widget size. (Origin point was fixed to screen's center)
ZoomableWidget(
  panLimit: 1.0,
  maxScale: 2.0,
  minScale: 0.5,
  singleFingerPan: true,
  multiFingersPan: false,
  enableRotate: true,
  child: Image(
    image: AssetImage('graphics/background.png'),
  ),
  zoomSteps: 3,
),
```

Details in [example/](https://github.com/mchome/flutter_advanced_networkimage/tree/master/example) folder.

![demo gif](https://user-images.githubusercontent.com/7392658/38853766-db25add4-4250-11e8-9f6e-af550e43ef9a.gif)

If you have any problem or question, feel free to file issues.
