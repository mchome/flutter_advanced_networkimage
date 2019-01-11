/// Demo only, do not use it

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart';

class StreamLoadingImage extends StatefulWidget {
  const StreamLoadingImage({
    Key key,
    @required this.url,
    this.placeholder = const Icon(Icons.image),
  });

  final String url;
  final Widget placeholder;

  @override
  State<StatefulWidget> createState() => StreamLoadingImageState();
}

class StreamLoadingImageState extends State<StreamLoadingImage> {
  List<int> buffer = [];
  double progress = 0.0;
  StreamSubscription subscription;

  @override
  void initState() {
    super.initState();
    getImage();
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  void getImage() async {
    StreamedResponse res = await Request('GET', Uri.parse(widget.url)).send();
    int fileSize = 0;
    subscription = res.stream.listen((bytes) {
      buffer.addAll(bytes);
      fileSize += bytes.length;
      setState(() => progress = fileSize / res.contentLength);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: progress > 0.1
          ? Image.memory(Uint8List.fromList(buffer), gaplessPlayback: true)
          : widget.placeholder,
    );
  }
}
