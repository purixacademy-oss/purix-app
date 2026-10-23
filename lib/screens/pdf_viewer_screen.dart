import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.title,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Google Drive URL ko preview format me badalna
    String finalUrl = widget.pdfUrl.trim();
    if (finalUrl.contains('drive.google.com')) {
      finalUrl = finalUrl.replaceAll('/view?usp=sharing', '/preview').replaceAll('/view', '/preview');
    }

    // STRICT MODE: Viewport aur Overflow fix kiya gaya smooth Pinch-to-Zoom ke liye
    final String htmlCode = '''
    <!DOCTYPE html>
    <html>
    <head>
        <!-- 🔴 YAHAN FIX KIYA GAYA HAI: user-scalable=yes aur maximum-scale=4.0 -->
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=4.0, user-scalable=yes">
        <style>
            body, html { margin: 0; padding: 0; height: 100%; overflow: hidden; background-color: #070B14; }
            .iframe-container {
                width: 100%;
                height: 100%;
                overflow: auto; /* 🔴 hidden se auto kiya taaki zoom ke baad pan/scroll ho sake */
                position: relative;
            }
            iframe {
                position: absolute;
                top: -56px; /* Hides the 56px Google Drive header completely */
                left: 0;
                width: 100%;
                height: calc(100% + 56px); /* Keeps the rest of the PDF full size */
                border: none;
            }
        </style>
    </head>
    <body>
        <div class="iframe-container">
            <iframe src="$finalUrl"></iframe>
        </div>
    </body>
    </html>
    ''';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF070B14))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadHtmlString(htmlCode);
  }

  @override
  Widget build(BuildContext context) {
    const neonCyan = Color(0xFF00F0FF);

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1D),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 13, 
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: neonCyan),
            ),
        ],
      ),
    );
  }
}