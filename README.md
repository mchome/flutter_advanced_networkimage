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
new Image(
  image: new AdvancedNetworkImage(url, header: header, useDiskCache: true),
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
new ZoomableWidget(
  minScale: 0.3,
  maxScale: 2.0,
  child: new Container(
    child: new TransitionToImage(
      new AdvancedNetworkImage(url),
      // This is the default placeholder widget at loading status,
      // you can write your own widget with CustomPainter.
      placeholder: new CircularProgressIndicator(),
      // This is default duration
      duration: new Duration(milliseconds: 300),
    ),
  ),
)
```

```dart
// using reload feature(you can use a `GestureDetector`
// widget to wrap `TransitionToImage` widget)
TransitionToImage imageWidget = new TransitionToImage(
  new AdvancedNetworkImage(url),
  useReload: true,
);
new ZoomableWidget(
  minScale: 0.3,
  maxScale: 2.0,
  child: imageWidget,
  tapCallback: imageWidget.reloadImage,
),
```

Details in [example/](https://github.com/mchome/flutter_advanced_networkimage/tree/master/example) folder.

## Q&A

- Q: Why the cached files stored in documents directory instead of temporary directory?  
  A: I think your cached files should be a part of your app, and you can manual clear your cached files.
