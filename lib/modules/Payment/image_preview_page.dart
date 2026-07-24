import 'dart:io';
import 'package:flutter/material.dart';

class ImagePreviewPage extends StatelessWidget {
  final File file;

  const ImagePreviewPage({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image Preview')),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(file),
        ),
      ),
    );
  }
}
