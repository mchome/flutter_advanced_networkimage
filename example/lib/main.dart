import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:flutter_advanced_networkimage/flutter_advanced_networkimage.dart';
import 'package:flutter_advanced_networkimage/transition_to_image.dart';
import 'package:flutter_advanced_networkimage/zoomable_widget.dart';
import 'package:flutter_advanced_networkimage/zoomable_list.dart';
import 'package:flutter_advanced_networkimage/image_cropper.dart';

main() => runApp(MaterialApp(
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
  ValueChanged<ByteData> onImageCropperChanged;

  cropImage(ByteData data) => setState(() => imageCropperData = data);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Flutter Advanced Network Image Example'),
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: 'load image'),
              Tab(text: 'zooming'),
              Tab(text: 'widget list'),
              Tab(text: 'crop image(WIP)'),
              // Tab(text: 'cropped image'),
            ],
          ),
        ),
        body: TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: <Widget>[
            TransitionToImage(
              AdvancedNetworkImage(
                'https://assets-cdn.github.com/images/modules/logos_page/GitHub-Mark.png',
                loadedCallback: () => print('It works!'),
                loadFailedCallback: () => print('Oh, no!'),
              ),
              fit: BoxFit.contain,
              placeholder: Container(
                width: 300.0,
                height: 300.0,
                color: Color(0),
                child: const Icon(Icons.refresh),
              ),
              width: 300.0,
              height: 300.0,
            ),

            ZoomableWidget(
              panLimit: 0.7,
              maxScale: 2.0,
              minScale: 0.5,
              multiFingersPan: false,
              child: Image(
                image: AdvancedNetworkImage(
                  'https://assets-cdn.github.com/images/modules/logos_page/GitHub-Mark.png',
                ),
              ),
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

            ImageCropper(
              AdvancedNetworkImage(
                'https://assets-cdn.github.com/images/modules/logos_page/GitHub-Mark.png',
              ),
              onImageCropperChanged: cropImage,
            ),
            // Container(
            //   color: Colors.limeAccent,
            //   child: imageCropperData != null
            //       ? Image.memory(
            //           Uint8List.view(imageCropperData.buffer),
            //           fit: BoxFit.contain,
            //         )
            //       : Container(),
            // ),
          ],
        ),
      ),
    );
  }
}
