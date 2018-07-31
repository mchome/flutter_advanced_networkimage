import 'package:flutter/material.dart';

import 'package:flutter_advanced_networkimage/flutter_advanced_networkimage.dart';
import 'package:flutter_advanced_networkimage/transition_to_image.dart';
import 'package:flutter_advanced_networkimage/zoomable_list.dart';

main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text('Flutter Advanced Network Image Example'),
            bottom: TabBar(
              tabs: <Widget>[
                Tab(text: 'load image'),
                Tab(text: 'widget list'),
              ],
            ),
          ),
          body: TabBarView(
            physics: NeverScrollableScrollPhysics(),
            children: <Widget>[
              TransitionToImage(
                AdvancedNetworkImage(
                  'https://assets-cdn.github.com/images/modules/logos_page/GitHub-Mark.png',
                ),
                fit: BoxFit.contain,
                placeholder: const Icon(Icons.refresh),
                width: 400.0,
                height: 300.0,
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
            ],
          ),
        ),
      ),
    );
  }
}
