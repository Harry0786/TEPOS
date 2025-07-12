import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const IconGeneratorApp());
}

class IconGeneratorApp extends StatelessWidget {
  const IconGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Icon Generator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const IconGeneratorScreen(),
    );
  }
}

class IconGeneratorScreen extends StatefulWidget {
  const IconGeneratorScreen({super.key});

  @override
  IconGeneratorScreenState createState() => IconGeneratorScreenState();
}

class IconGeneratorScreenState extends State<IconGeneratorScreen> {
  final GlobalKey _globalKey = GlobalKey();
  String _status = 'Click "Generate Icon" to create the app icon';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TEPOS Icon Generator'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            RepaintBoundary(
              key: _globalKey,
              child: Container(
                width: 300,
                height: 300,
                color: const Color(0xFF6B8E7F),
                child: const Center(
                  child: Text(
                    'TE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 150,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(_status),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _captureAndSavePng,
              child: const Text('Generate Icon'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureAndSavePng() async {
    try {
      // Get render object
      final RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      
      // Convert to image
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        
        // Get directory to save the file
        final Directory directory = await getApplicationDocumentsDirectory();
        final String path = '${directory.path}/app_icon.png';
        
        // Write to file
        final File file = File(path);
        await file.writeAsBytes(pngBytes);
        
        setState(() {
          _status = 'Icon saved to: $path';
        });
        
        // Display where the icon was saved
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Icon saved to: $path')),
        );
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }
}
