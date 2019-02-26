import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:flutter_advanced_networkimage/transition.dart';
import 'package:flutter_advanced_networkimage/zoomable.dart';
import 'package:flutter_advanced_networkimage/provider.dart';
import 'package:flutter_advanced_networkimage/cropper.dart';
import 'package:flutter_svg/flutter_svg.dart';

// import 'package:flutter_advanced_networkimage/src/stream_loading_image.dart';

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

  Uint8List imageCropperData;

  void cropImage(Uint8List data) => setState(() => imageCropperData = data);

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
              // Tab(text: 'stream loading(DEMO)'),
            ],
          ),
        ),
        body: TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: <Widget>[
            Column(
              children: <Widget>[
                TransitionToImage(
                  image: AdvancedNetworkImage(
                    url,
                    loadedCallback: () => print('It works!'),
                    loadFailedCallback: () => print('Oh, no!'),
                    // loadingProgress: (double progress) => print(progress),
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
                  loadingWidgetBuilder: (progress) {
                    return Container(
                      width: 300.0,
                      height: 300.0,
                      alignment: Alignment.center,
                      child: Text(progress.toString()),
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
            ),

            ZoomableWidget(
              panLimit: 0.7,
              maxScale: 2.0,
              minScale: 0.5,
              multiFingersPan: false,
              enableRotate: true,
              autoCenter: true,
              child: Image(image: AdvancedNetworkImage(url)),
              // onZoomChanged: (double value) => print(value),
            ),

            Builder(builder: (BuildContext context) {
              GlobalKey _key = GlobalKey();
              return ZoomableList(
                childKey: _key,
                maxScale: 2.0,
                child: Column(
                  key: _key,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Image(image: AdvancedNetworkImage(url)),
                    Image(image: AdvancedNetworkImage(url)),
                    Image(image: AdvancedNetworkImage(url)),
                  ],
                ),
              );
            }),

            Column(
              children: <Widget>[
                Container(
                  height: 400.0,
                  color: Colors.grey,
                  child: ImageCropper(
                    image: AdvancedNetworkImage(url),
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
            ),

            // StreamLoadingImage(
            //   url: url,
            // ),
          ],
        ),
      ),
    );
  }
}
