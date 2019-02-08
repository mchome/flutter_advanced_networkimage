import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:flutter_advanced_networkimage/transition.dart';
import 'package:flutter_advanced_networkimage/zoomable.dart';
import 'package:flutter_advanced_networkimage/provider.dart';
import 'package:flutter_advanced_networkimage/cropper.dart';

// import 'package:flutter_advanced_networkimage/src/stream_loading_image.dart';

void main() => runApp(MaterialApp(
      title: 'Flutter Example',
      theme: ThemeData(primaryColor: Colors.blue),
      home: MyApp(),
    ));

class MyApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => Example();
}

class Example extends State<MyApp> {
  ByteData imageCropperData;

  cropImage(ByteData data) => setState(() => imageCropperData = data);

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
              Tab(text: 'load image'),
              Tab(text: 'zoomable widget'),
              Tab(text: 'zoomable list'),
              Tab(text: 'crop image(WIP)'),
              // Tab(text: 'stream loading(DEMO)'),
            ],
          ),
        ),
        body: TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: <Widget>[
            TransitionToImage(
              image: AdvancedNetworkImage(
                'https://assets-cdn.github.com/images/modules/logos_page/GitHub-Mark.png',
                // loadedCallback: () => print('It works!'),
                // loadFailedCallback: () => print('Oh, no!'),
                // loadingProgress: (double progress) => print(progress),
              ),
              loadedCallback: () => print('It works!'),
              loadFailedCallback: () => print('Oh, no!'),
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
              loadingWidgetBuilder: (progress) =>
                  Center(child: Text(progress.toString())),
            ),

            ZoomableWidget(
              panLimit: 0.7,
              maxScale: 2.0,
              minScale: 0.5,
              multiFingersPan: false,
              enableRotate: true,
              autoCenter: true,
              child: Image(
                image: AdvancedNetworkImage(
                  'https://assets-cdn.github.com/images/modules/logos_page/GitHub-Mark.png',
                ),
              ),
              // onZoomChanged: (double value) => print(value),
            ),

            Builder(builder: (BuildContext context) {
              GlobalKey _key = GlobalKey();
              return ZoomableList(
                childKey: _key,
                panLimit: 1.0,
                maxScale: 2.0,
                minScale: 0.5,
                child: Column(
                  key: _key,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Image(
                      image: AdvancedNetworkImage(
                        'https://assets-cdn.github.com/images/modules/logos_page/GitHub-Mark.png',
                      ),
                    ),
                    Image(
                      image: AdvancedNetworkImage(
                        'https://assets-cdn.github.com/images/modules/logos_page/GitHub-Mark.png',
                      ),
                    ),
                    Image(
                      image: AdvancedNetworkImage(
                        'https://assets-cdn.github.com/images/modules/logos_page/GitHub-Mark.png',
                      ),
                    ),
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
                    image: AdvancedNetworkImage(
                      'https://assets-cdn.github.com/images/modules/logos_page/GitHub-Mark.png',
                    ),
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
                                        ? Image.memory(
                                            Uint8List.view(
                                                imageCropperData.buffer),
                                          )
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
            //   url: 'https://assets-cdn.github.com/images/modules/logos_page/GitHub-Mark.png',
            // ),
          ],
        ),
      ),
    );
  }
}
