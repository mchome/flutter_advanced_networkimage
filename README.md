# Flutter Advanced Network Imageprovider

[![pub package](https://img.shields.io/pub/v/flutter_advanced_networkimage.svg)](https://pub.dartlang.org/packages/flutter_advanced_networkimage)

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
  image: AdvancedNetworkImage(url, header: header, useDiskCache: true),
  fit: BoxFit.cover,
)
```

```dart
// get the disk cache folder size
int folderSize = await getDiskCachedImagesSize();
```

```dart
// clean the disk cache
bool isSucceed = await clearDiskCachedImages();
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
      AdvancedNetworkImage(url, timeoutDuration: Duration(minutes: 1)),
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
  AdvancedNetworkImage(url,
    loadedCallback: () {
      print('It works!');
    },
    loadFailedCallback: () {
      print('Oh, no!');
    }),
  loadingWidget: const CircularProgressIndicator(),
  fit: BoxFit.contain,
  placeholder: const Icon(Icons.refresh),
  width: 400.0,
  height: 300.0,
);
```

```dart
// Scale the widget size. (Origin point was fixed to screen's center)
ZoomableWidget(
  panLimit: 1.0,
  maxScale: 2.0,
  minScale: 0.5,
  singleFingerPan: true,
  multiFingersPan: true,
  child: Image(
    image: AssetImage('graphics/background.png'),
  ),
  zoomSteps: 3,
),
```

Details in [example/](https://github.com/mchome/flutter_advanced_networkimage/tree/master/example) folder.

![demo gif](https://user-images.githubusercontent.com/7392658/38853766-db25add4-4250-11e8-9f6e-af550e43ef9a.gif)
