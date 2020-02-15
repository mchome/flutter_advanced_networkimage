import 'dart:ui' show ImageFilter;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:flutter_advanced_networkimage/provider.dart';
import 'package:flutter_advanced_networkimage/transition.dart';
import 'package:flutter_advanced_networkimage/zoomable.dart';

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
      'https://github.com/dart-lang/site-shared/raw/master/src/_assets/image/flutter/logo/default.svg';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Flutter Advanced Network Image Example'),
          bottom: TabBar(
            isScrollable: true,
            tabs: <Widget>[
              const Tab(text: 'load image'),
              const Tab(text: 'zoomable widget'),
              const Tab(text: 'zoomable list'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: <Widget>[
            LoadImage(url: url, svgUrl: svgUrl),
            ZoomableImage(url: url),
            ZoomableImages(url: url),
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
          imageFilter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
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
