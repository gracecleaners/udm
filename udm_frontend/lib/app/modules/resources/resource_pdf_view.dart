import 'package:flutter/material.dart';
import 'package:internet_file/internet_file.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/theme/app_colors.dart';

/// Reads a ministry PDF in the app, with pinch zoom and page navigation.
class ResourcePdfView extends StatefulWidget {
  const ResourcePdfView({required this.title, required this.url, super.key});

  final String title;
  final String url;

  @override
  State<ResourcePdfView> createState() => _ResourcePdfViewState();
}

class _ResourcePdfViewState extends State<ResourcePdfView> {
  late PdfControllerPinch _pdfController;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _openDocument();
  }

  void _openDocument() {
    _failed = false;
    _pdfController = PdfControllerPinch(
      document: PdfDocument.openData(InternetFile.get(widget.url)),
    );
  }

  void _retry() {
    _pdfController.dispose();
    setState(_openDocument);
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF2F6FD),
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.deepBlue,
      title: Text(
        widget.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    body: _failed
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 48,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This PDF could not be opened.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.deepBlue,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _retry,
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          )
        : PdfViewPinch(
            controller: _pdfController,
            onDocumentError: (_) {
              if (mounted) setState(() => _failed = true);
            },
          ),
  );
}
