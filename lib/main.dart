import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'ascii_converter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image to ASCII',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const ImageToAsciiPage(),
    );
  }
}

class ImageToAsciiPage extends StatefulWidget {
  const ImageToAsciiPage({super.key});

  @override
  State<ImageToAsciiPage> createState() => _ImageToAsciiPageState();
}

class _ImageToAsciiPageState extends State<ImageToAsciiPage> {
  XFile? _pickedImage;
  String? _asciiArt;
  bool _isProcessing = false;
  int _width = 120;
  bool _invert = false;
  bool _useDetailed = true;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      
      if (image != null) {
        setState(() {
          _pickedImage = image;
          _asciiArt = null;
        });
        await _convertToAscii();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _convertToAscii() async {
    if (_pickedImage == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final Uint8List imageBytes = await _pickedImage!.readAsBytes();
      final String ascii = await AsciiConverter.convertToAscii(
        imageBytes,
        width: _width,
        invert: _invert,
        useDetailed: _useDetailed,
      );

      setState(() {
        _asciiArt = ascii;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error converting image: $e')),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image to ASCII'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Controls section
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Width slider
                Row(
                  children: [
                    const Text('Width: '),
                    Expanded(
                      child: Slider(
                        value: _width.toDouble(),
                        min: 40,
                        max: 200,
                        divisions: 22,
                        label: _width.toString(),
                        onChanged: (value) {
                          setState(() {
                            _width = value.round();
                          });
                          if (_pickedImage != null) {
                            _convertToAscii();
                          }
                        },
                      ),
                    ),
                    Text('$_width'),
                  ],
                ),
                // Detailed mode checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _useDetailed,
                      onChanged: (value) {
                        setState(() {
                          _useDetailed = value ?? true;
                        });
                        if (_pickedImage != null) {
                          _convertToAscii();
                        }
                      },
                    ),
                    const Text('Detailed mode (better quality)'),
                  ],
                ),
                // Invert checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _invert,
                      onChanged: (value) {
                        setState(() {
                          _invert = value ?? false;
                        });
                        if (_pickedImage != null) {
                          _convertToAscii();
                        }
                      },
                    ),
                    const Text('Invert colors'),
                  ],
                ),
              ],
            ),
          ),
          
          // Image preview or ASCII art display
          Expanded(
            child: _isProcessing
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _asciiArt != null
                    ? Container(
                        padding: const EdgeInsets.all(8.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: SelectableText(
                              _asciiArt!,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 8,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      )
                    : _pickedImage != null
                        ? Center(
                            child: Image.file(
                              File(_pickedImage!.path),
                              fit: BoxFit.contain,
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image,
                                  size: 80,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No image selected',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap the button below to select an image',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showImageSourceDialog,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Select Image'),
      ),
    );
  }
}
