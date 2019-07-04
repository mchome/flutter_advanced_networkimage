import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:flutter_advanced_networkimage/provider.dart';
import 'package:flutter_advanced_networkimage/transition.dart';
import 'package:flutter_advanced_networkimage/zoomable.dart';
import 'package:flutter_advanced_networkimage/cropper.dart';

void main() {
  runApp(MaterialApp(
    title: 'Flutter Example',
    theme: ThemeData(primaryColor: Colors.blue),
    home: MyApp(),
  ));
}

class MyApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => Example();
}

class Example extends State<MyApp> {
  final String url = 'https://flutter.io/images/flutter-logo-sharing.png';
  final String svgUrl =
      'https://flutter.dev/assets/flutter-lockup-4cb0ee072ab312e59784d9fbf4fb7ad42688a7fdaea1270ccf6bbf4f34b7e03f.svg';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Flutter Advanced Network Image Example'),
          bottom: TabBar(
            isScrollable: true,
            tabs: <Widget>[
              const Tab(text: 'load image'),
              const Tab(text: 'zoomable widget'),
              const Tab(text: 'zoomable list'),
              const Tab(text: 'crop image(WIP)'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: <Widget>[
            LoadImage(url: url, svgUrl: svgUrl),
            ZoomableImage(url: url),
            ZoomableImages(url: url),
            CropImage(url: url),
          ],
        ),
      ),
    );
  }
}

class LoadImage extends StatelessWidget {
  const LoadImage({@required this.url, @required this.svgUrl});

  final String url;
  final String svgUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TransitionToImage(
          image: AdvancedNetworkImage(
            url,
            loadedCallback: () => print('It works!'),
            loadFailedCallback: () => print('Oh, no!'),
            // loadingProgress: (double progress, _) => print(progress),
            timeoutDuration: Duration(seconds: 30),
            retryLimit: 1,
            // disableMemoryCache: true,
          ),
          // loadedCallback: () => print('It works!'),
          // loadFailedCallback: () => print('Oh, no!'),
          // disableMemoryCache: true,
          fit: BoxFit.contain,
          placeholder: Container(
            width: 300.0,
            height: 300.0,
            color: Colors.transparent,
            child: const Icon(Icons.refresh),
          ),
          width: 300.0,
          height: 300.0,
          enableRefresh: true,
          loadingWidgetBuilder: (
            BuildContext context,
            double progress,
            Uint8List imageData,
          ) {
            // print(imageData.lengthInBytes);
            return Container(
              width: 300.0,
              height: 300.0,
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                value: progress == 0.0 ? null : progress,
              ),
            );
          },
        ),
        Expanded(
          child: SvgPicture(
            AdvancedNetworkSvg(
              svgUrl,
              SvgPicture.svgByteDecoder,
            ),
          ),
        ),
      ],
    );
  }
}

class ZoomableImage extends StatelessWidget {
  const ZoomableImage({@required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ZoomableWidget(
      maxScale: 5.0,
      minScale: 0.5,
      multiFingersPan: false,
      autoCenter: true,
      child: Image(image: AdvancedNetworkImage(url)),
      // onZoomChanged: (double value) => print(value),
    );
  }
}

class ZoomableImages extends StatelessWidget {
  const ZoomableImages({@required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ZoomableList(
      maxScale: 2.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Image(image: AdvancedNetworkImage(url)),
          Image(image: AdvancedNetworkImage(url)),
          Image(image: AdvancedNetworkImage(url)),
          Image(image: AdvancedNetworkImage(url)),
          Image(image: AdvancedNetworkImage(url)),
        ],
      ),
    );
  }
}

class CropImage extends StatefulWidget {
  const CropImage({@required this.url});

  final String url;

  @override
  State<StatefulWidget> createState() => _CropImageState();
}

class _CropImageState extends State<CropImage> {
  Uint8List imageCropperData;

  void cropImage(Uint8List data) => setState(() => imageCropperData = data);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          height: 400.0,
          color: Colors.grey,
          child: ImageCropper(
            child: Image(image: AdvancedNetworkImage(widget.url)),
            onCropperChanged: cropImage,
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              IconButton(
                color: Theme.of(context).primaryColor,
                icon: Icon(Icons.flip),
                onPressed: () {},
              ),
              IconButton(
                color: Theme.of(context).primaryColor,
                icon: Icon(Icons.crop),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Cropped!'),
                        content: SingleChildScrollView(
                          child: Container(
                            child: imageCropperData != null
                                ? Image.memory(imageCropperData)
                                : Container(),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
