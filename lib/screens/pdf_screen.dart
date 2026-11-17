import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

class PdfScreen extends StatelessWidget {
  final String title;
  final String fileName;
  final Future<Uint8List> Function() builder;

  const PdfScreen({
    super.key,
    required this.title,
    required this.fileName,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PdfPreview(
        build: (format) => builder(),
        pdfFileName: fileName,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
      ),
    );
  }
}

void openPdf(BuildContext context, String title, String fileName,
    Future<Uint8List> Function() builder) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => PdfScreen(title: title, fileName: fileName, builder: builder),
  ));
}
