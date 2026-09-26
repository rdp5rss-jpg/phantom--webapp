import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI styling for premium feel
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Phantom',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        primaryColor: const Color(0xFF6366F1), // Indigo 500
      ),
      home: const WebAppScreen(),
    );
  }
}

class WebAppScreen extends StatefulWidget {
  const WebAppScreen({super.key});

  @override
  State<WebAppScreen> createState() => _WebAppScreenState();
}

class _WebAppScreenState extends State<WebAppScreen> {
  final String targetUrl = "https://phantom-server-j2a0.onrender.com/";
  InAppWebViewController? webViewController;
  
  double _progress = 0;
  bool _isOffline = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _requestNativePermissions();
    _initConnectivity();
  }

  // 1. Request device Camera and Mic permissions
  Future<void> _requestNativePermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  // 2. Monitor Network Status
  void _initConnectivity() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final isDisconnected = results.contains(ConnectivityResult.none);
      setState(() {
        _isOffline = isDisconnected;
      });

      if (!isDisconnected && webViewController != null) {
        webViewController?.reload();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (webViewController != null && await webViewController!.canGoBack()) {
          webViewController!.goBack();
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // WebView
              if (!_isOffline)
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(targetUrl)),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    allowsInlineMediaPlayback: true,
                    mediaPlaybackRequiresUserGesture: false,
                    useHybridComposition: true,
                    transparentBackground: true,
                  ),
                  onWebViewCreated: (controller) {
                    webViewController = controller;
                  },
                  onProgressChanged: (controller, progress) {
                    setState(() {
                      _progress = progress / 100;
                    });
                  },
                  // Grant camera & microphone to the Web application directly
                  onPermissionRequest: (controller, request) async {
                    return PermissionResponse(
                      resources: request.resources,
                      action: PermissionResponseAction.GRANT,
                    );
                  },
                  onReceivedError: (controller, request, error) {
                    setState(() {
                      _isOffline = true;
                    });
                  },
                ),

              // Thin Progress Bar
              if (_progress < 1.0 && !_isOffline)
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  minHeight: 2.5,
                ),

              // Premium Offline Screen
              if (_isOffline)
                _buildOfflineScreen(),
            ],
          ),
        ),
      ),
    );
  }

  // Modern UI for Offline State
  Widget _buildOfflineScreen() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1E293B),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
              ],
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: Color(0xFF818CF8),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "Connection Lost",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "It looks like you're offline. Check your Wi-Fi or cellular network.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 36),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Connectivity().checkConnectivity();
              if (!result.contains(ConnectivityResult.none)) {
                setState(() => _isOffline = false);
                webViewController?.reload();
              }
            },
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text(
              "Try Again",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}