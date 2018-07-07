import 'package:flutter/material.dart';
import 'package:flutter_advanced_networkimage/flutter_advanced_networkimage.dart';
import 'package:flutter_advanced_networkimage/zoomable_widget.dart';
import 'package:flutter_advanced_networkimage/transition_to_image.dart';

main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    TransitionToImage imageWidget = TransitionToImage(
      AdvancedNetworkImage(
        'https://assets-cdn.github.com/images/modules/logos_page/GitHub-Mark.png',
      ),
      useReload: true,
      fit: BoxFit.contain,
    );

    return MaterialApp(
      title: 'Flutter Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Flutter Advanced Network Image Example'),
        ),
        body: ZoomableWidget(
          minScale: 0.3,
          maxScale: 2.0,
          child: imageWidget,
          tapCallback: imageWidget.reloadImage,
        ),
      ),
    );
  }
}
