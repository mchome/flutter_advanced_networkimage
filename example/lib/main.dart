import 'package:flutter/material.dart';

import 'package:flutter_advanced_networkimage/flutter_advanced_networkimage.dart';
import 'package:flutter_advanced_networkimage/zoomable_widget.dart';
import 'package:flutter_advanced_networkimage/transition_to_image.dart';

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
                Tab(text: 'image loading'),
                Tab(text: 'image controlling'),
              ],
            ),
          ),
          body: TabBarView(
            children: <Widget>[
              Container(
                child: Builder(builder: (BuildContext context) {
                  TransitionToImage imageWidget = TransitionToImage(
                    AdvancedNetworkImage(
                      'https://assets-cdn.github.com/images/modules/logos_page/GitHub-Mark.png',
                    ),
                    fit: BoxFit.contain,
                  );
                  return GestureDetector(
                    onTap: imageWidget.reloadImage,
                    child: imageWidget,
                  );
                }),
              ),
              Container(),
            ],
          ),
        ),
      ),
    );
  }
}
