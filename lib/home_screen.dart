import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Để kiểm tra Platform

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Import platform specific controller (nếu bạn muốn dùng setOnShowFileChooser)
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// Các plugin cho download/upload (CẦN THÊM VÀO PUBSPEC.YAML)
import 'package:flutter_downloader/flutter_downloader.dart'; // Ví dụ cho download
// import 'package:file_picker/file_picker.dart'; // Ví dụ cho upload tùy chỉnh
// import 'package:url_launcher/url_launcher.dart'; // Cách khác cho download

// Đảm bảo các tệp này tồn tại và đúng đường dẫn
import 'js_bridge_util.dart';
import 'menu_widgets.dart';

// CẦN KHAI BÁO Ở TOP-LEVEL HOẶC STATIC METHOD cho flutter_downloader
@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  print(
      'Background Isolate Callback: task ($id) is in status ($status) and process ($progress)');
  // Bạn có thể gửi thông tin này về Main Isolate bằng SendPort nếu cần cập nhật UI
  // final SendPort? send = IsolateNameServer.lookupPortByName('downloader_send_port');
  // send?.send([id, status, progress]);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  WebViewController? _webViewController;
  JsBridgeUtil? _jsBridgeUtil;

  bool _isLoadingPage = true;
  bool _isError = false;
  String _errorMessage = 'Đã xảy ra lỗi. Vui lòng thử lại.';

  String _currentUrl = '';
  bool _isLoggedIn = false;
  int _currentNavIndex = 0;

  final String _loginUrl = 'http://113.160.48.99:8791/Account/Login';

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isConnected = true;

  final List<String> _externalDomains = [
    'sso.dancuquocgia.gov.vn',
    'xacthuc.dichvucong.gov.vn',
  ];

  final List<String> _publicFunctionPathKeywords = [
    '/thu-tuc',
    '/ho-so',
    '/van-ban',
    '/lien-he',
    '/huong-dan',
    // '/trang-chu', // Thêm path của trang chủ nếu nó public và không cần check login
  ];

  // ReceivePort? _port; // Dùng với IsolateNameServer cho flutter_downloader

  @override
  void initState() {
    super.initState();
    _currentUrl = MenuConfig.homeUrl;
    _urlController.text = _currentUrl;

    _checkInitialConnectivity();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);

    _initializeDownloaderAndPermissions(); // Khởi tạo downloader và xin quyền

    _loadUrl(_currentUrl);
  }

  Future<void> _initializeDownloaderAndPermissions() async {
    // --- Flutter Downloader Initialization ---
    // Bỏ comment và cấu hình nếu bạn dùng flutter_downloader
    // WidgetsFlutterBinding.ensureInitialized(); // Đảm bảo đã gọi ở main()
    // try {
    //   await FlutterDownloader.initialize(
    //     debug: true, // Set to false in release
    //     ignoreSsl: true,
    //   );
    //   print('FlutterDownloader initialized.');
    //
    //   // Đăng ký port để nhận callback từ isolate (nếu cần)
    //   _port = ReceivePort();
    //   IsolateNameServer.registerPortWithName(_port!.sendPort, 'downloader_send_port');
    //   _port!.listen((dynamic data) {
    //     String id = data[0];
    //     DownloadTaskStatus status = DownloadTaskStatus(data[1]); // Chuyển đổi int sang enum
    //     int progress = data[2];
    //     print('Main Isolate: Download task ($id) is in status ($status) and process ($progress)');
    //     // Cập nhật UI ở đây nếu cần
    //   });
    //
    //   FlutterDownloader.registerCallback(downloadCallback);
    // } catch (e) {
    //   print('Failed to initialize FlutterDownloader: $e');
    // }

    // --- Permission Request ---
    await _request notwendigePermissions();
  }

  Future<void> _requestnotwendigePermissions() async {
    // Quyền lưu trữ cho download (và upload trên một số bản Android cũ)
    var storageStatus = await Permission.storage.status;
    if (!storageStatus.isGranted) {
      storageStatus = await Permission.storage.request();
    }
    if(!storageStatus.isGranted) {
        print("Storage permission not granted");
    }


    // Quyền truy cập media cho Android 13+ (thay thế storage cho media files)
    if (Platform.isAndroid) {
        // final androidInfo = await DeviceInfoPlugin().androidInfo;
        // if (androidInfo.version.sdkInt >= 33) { // Android 13 (Tiramisu)
            var photosStatus = await Permission.photos.status;
            if(!photosStatus.isGranted) await Permission.photos.request();

            var videosStatus = await Permission.videos.status;
            if(!videosStatus.isGranted) await Permission.videos.request();

            // var audioStatus = await Permission.audio.status;
            // if(!audioStatus.isGranted) await Permission.audio.request();
        // }
    }


    // Quyền camera (nếu trang web có chức năng chụp ảnh để upload)
    // var cameraStatus = await Permission.camera.status;
    // if (!cameraStatus.isGranted) {
    //   await Permission.camera.request();
    // }
  }


  bool _isExternalUrl(String url) {
    if (url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return _externalDomains.contains(uri.host);
    } catch (_) {
      return false;
    }
  }

  bool _isPublicFunctionUrl(String url) {
    if (url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      if (MenuConfig.homeUrl.isNotEmpty) {
        try {
          final homeUri = Uri.parse(MenuConfig.homeUrl);
          if (uri.host == homeUri.host && uri.path == homeUri.path) {
            print('URL is considered a public function URL (Home Page): $url');
            return true;
          }
        } catch(_){}
      }
      for (var keyword in _publicFunctionPathKeywords) {
        if (uri.path.toLowerCase().contains(keyword.toLowerCase())) {
          print('URL is considered a public function URL: $url (matches keyword: $keyword)');
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error parsing URL in _isPublicFunctionUrl: $url, Error: $e');
      return false;
    }
  }

  Future<void> _checkInitialConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResult, isInitialCheck: true);
  }

  void _updateConnectionStatus(List<ConnectivityResult> result,
      {bool isInitialCheck = false}) {
    if (!mounted) return;
    bool currentlyConnected = !result.contains(ConnectivityResult.none);
    if (_isConnected != currentlyConnected) {
      setState(() {
        _isConnected = currentlyConnected;
        if (!_isConnected) {
          _isError = true;
          _isLoadingPage = false;
          _errorMessage =
              "Mất kết nối mạng. Vui lòng kiểm tra lại đường truyền và thử lại.";
        } else {
          if (_isError && _errorMessage.contains("Mất kết nối mạng")) {
            _isError = false;
          }
        }
      });
    } else if (isInitialCheck && !_isConnected) {
      setState(() {
        _isError = true;
        _isLoadingPage = false;
        _errorMessage =
            "Không có kết nối mạng. Vui lòng kiểm tra lại đường truyền.";
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _connectivitySubscription?.cancel();
    // if (_port != null) { // Dùng với IsolateNameServer cho flutter_downloader
    //   IsolateNameServer.removePortNameMapping('downloader_send_port');
    // }
    super.dispose();
  }

  void _setupJavaScriptChannels() {
    // NƠI THÊM JAVASCRIPT CHANNELS ĐỂ JS_BRIDGE_UTIL HOẠT ĐỘNG ĐÚNG
    // Ví dụ:
    /*
    if (_webViewController == null) return;
    _webViewController!.addJavaScriptChannel(
      'loginResultHandler',
      onMessageReceived: (JavaScriptMessage message) {
        print('loginResultHandler received: ${message.message}');
        // Xử lý message...
      },
    );
    */
  }

  Future<void> _startDownload(String url) async {
    // --- CẦN CẤU HÌNH flutter_downloader ĐẦY ĐỦ ---
    // Ví dụ đơn giản, thực tế cần kiểm tra quyền, lấy đường dẫn lưu file,...
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Yêu cầu tải xuống: $url (Cần triển khai chi tiết)')),
    );

    // Nếu dùng flutter_downloader:
    final status = await Permission.storage.status;
    if (!status.isGranted) {
        final result = await Permission.storage.request();
        if (result != PermissionStatus.granted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cần quyền lưu trữ để tải file.')));
            return;
        }
    }

    String? localPath;
    if (Platform.isAndroid) {
        localPath = (await getExternalStoragePublicDirectory(ExternalStoragePublicDirectory.downloads))?.path;
    } else if (Platform.isIOS) {
        localPath = (await getApplicationDocumentsDirectory()).path;
    }

    if (localPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể xác định thư mục lưu file.')));
        return;
    }
    final String fileName = url.substring(url.lastIndexOf('/') + 1).split('?').first;


    try {
        final taskId = await FlutterDownloader.enqueue(
            url: url,
            savedDir: localPath,
            fileName: fileName,
            showNotification: true,
            openFileFromNotification: true,
            saveInPublicStorage: true,
        );
        print('Download task enqueued with ID: $taskId');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đang tải: $fileName')));
    } catch (e) {
        print('Error enqueuing download: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi bắt đầu tải: $e')));
    }


    // Hoặc dùng url_launcher để mở trình duyệt ngoài (đơn giản hơn)
    // if (await canLaunchUrl(Uri.parse(url))) {
    //   await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    // } else {
    //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể mở link tải: $url')));
    // }
  }


  void _loadUrl(String url, {bool isRetry = false}) {
    if (url.isEmpty) return;

    String effectiveUrl = url;
    if (!effectiveUrl.startsWith('http://') &&
        !effectiveUrl.startsWith('https://')) {
      effectiveUrl = 'http://$effectiveUrl';
    }

    if (!isRetry || _currentUrl.isEmpty || _currentUrl != effectiveUrl) {
      _currentUrl = effectiveUrl;
    }
    _urlController.text = _currentUrl;

    if (!mounted) return;
    setState(() {
      _isLoadingPage = true;
      _isError = false;
    });

    if (!_isConnected) {
      if (!mounted) return;
      setState(() {
        _isLoadingPage = false;
        _isError = true;
        _errorMessage =
            "Không có kết nối mạng. Vui lòng kiểm tra lại đường truyền.";
      });
      return;
    }

    final tempController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String navUrl) {
            print('WebView: Page started loading: $navUrl');
            if (mounted) {
              setState(() {
                _isLoadingPage = true;
                _isError = false;
              });
            }
          },
          onPageFinished: (String finishedUrl) async {
            print('WebView: Page finished loading: $finishedUrl');
            if (!mounted) return;

            bool isExternal = _isExternalUrl(finishedUrl);
            bool isPublicFunc = _isPublicFunctionUrl(finishedUrl);

            if (!isExternal && !isPublicFunc && _webViewController != null) {
              print('WebView: Running login check for: $finishedUrl');
              _jsBridgeUtil = JsBridgeUtil(_webViewController!);
              await _jsBridgeUtil!.setupJavaScriptHandlers();

              final isLoggedIn = await _jsBridgeUtil!.checkLoginStatus();
              if (mounted) {
                setState(() {
                  _isLoadingPage = false;
                  _isLoggedIn = isLoggedIn;
                });
              }
            } else {
              print('WebView: Skipping login check for: $finishedUrl (External: $isExternal, PublicFunction: $isPublicFunc)');
              setState(() {
                _isLoadingPage = false;
              });
            }
            _updateCurrentNavIndex(finishedUrl);
          },
          onWebResourceError: (WebResourceError error) {
            print(
                'WebView: WebResourceError: ${error.description}, URL: ${error.url}, ErrorCode: ${error.errorCode}, Type: ${error.errorType}, isForMainFrame: ${error.isForMainFrame}');
            if (!mounted) return;

            if (error.isForMainFrame == false && error.url != null && (_isExternalUrl(error.url!) || _isPublicFunctionUrl(error.url!)) ) {
              print('Ignoring non-main frame error on external/public domain: ${error.url}');
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Lỗi tải tài nguyên phụ: ${error.description}')),
               );
              // Nếu không phải lỗi nghiêm trọng, không cập nhật UI làm ẩn WebView
              // setState(() { _isLoadingPage = false; }); // Chỉ dừng loading nếu đang loading
              return;
            }

            setState(() {
              _isLoadingPage = false;
              _isError = true;

              if (!_isConnected) {
                _errorMessage =
                    "Mất kết nối mạng. Vui lòng kiểm tra lại đường truyền.";
              } else if (error.isForMainFrame == true && (error.url == _currentUrl || _isExternalUrl(error.url ?? _currentUrl) || _isPublicFunctionUrl(error.url ?? _currentUrl))) {
                 _errorMessage = "Không thể tải trang: ${error.description}";
              }
              else if (error.errorCode == -2 ||
                  error.errorCode == -6 ||
                  error.description.toLowerCase().contains('net::err_internet_disconnected') ||
                  error.description.toLowerCase().contains('net::err_name_not_resolved') ||
                  error.description.toLowerCase().contains('no internet') ||
                  error.errorType == WebResourceErrorType.hostLookup ||
                  error.errorType == WebResourceErrorType.connect ||
                  error.errorType == WebResourceErrorType.timeout) {
                _errorMessage =
                    "Không thể kết nối tới máy chủ hoặc không có kết nối mạng. Vui lòng thử lại.";
              } else {
                _errorMessage =
                    "Đã xảy ra lỗi khi tải trang: ${error.description}";
              }
            });
          },
          onNavigationRequest: (NavigationRequest request) async {
            print('WebView: Navigation request to: ${request.url}');
            String url = request.url.toLowerCase();
            bool isDownloadLink = url.endsWith('.pdf') || url.endsWith('.zip') || url.endsWith('.doc') ||
                                  url.endsWith('.docx') || url.endsWith('.xls') || url.endsWith('.xlsx') ||
                                  url.endsWith('.ppt') || url.endsWith('.pptx') || url.endsWith('.txt') ||
                                  url.endsWith('.apk'); // Thêm các đuôi file khác nếu cần

            if (isDownloadLink) {
              print('WebView: Detected download link: ${request.url}');
              await _startDownload(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) {
            if (change.url != null) {
              print('WebView: URL changed to: ${change.url}');
            }
          },
        ),
      );

    _webViewController = tempController;
    _setupJavaScriptChannels(); // Thiết lập JS Channels (hiện đang trống)

    // Cấu hình cho phép upload file trên Android (setOnShowFileChooser)
    if (Platform.isAndroid) {
      final androidController = _webViewController!.platformSpecificImplementation<AndroidWebViewController>();
      if (androidController != null) {
        // Để WebView tự xử lý upload, không cần gọi setOnShowFileChooser.
        // Nếu bạn muốn tùy chỉnh bằng file_picker, hãy bỏ comment và triển khai:
        // await androidController.setOnShowFileChooser(_onShowFileChooserForAndroid);
      }
    }

    _webViewController!.loadRequest(Uri.parse(_currentUrl));

    if (mounted) {
        setState(() {});
    }
  }

  // Hàm callback cho setOnShowFileChooser (Android) - VÍ DỤ
  // Future<List<String>> _onShowFileChooserForAndroid(FileChooserParams params) async {
  //   print('Android onShowFileChooser: mode=${params.mode}, acceptTypes=${params.acceptTypes}');
  //   // Sử dụng file_picker để chọn file
  //   // final result = await FilePicker.platform.pickFiles(
  //   //   allowMultiple: params.mode == FileChooserMode.openMultiple,
  //   //   type: FileType.any, // Hoặc dựa vào params.acceptTypes để lọc
  //   //   // allowedExtensions: params.acceptTypes.isNotEmpty ? params.acceptTypes : null,
  //   // );
  //   // if (result != null && result.files.isNotEmpty) {
  //   //   return result.paths.where((path) => path != null).map((path) => Uri.file(path!).toString()).toList();
  //   // }
  //   return []; // Trả về danh sách rỗng nếu hủy hoặc không chọn được
  // }


  void _retryLoading() {
    if (!_isConnected) {
      if (mounted) {
        setState(() {
          _isLoadingPage = false;
          _isError = true;
          _errorMessage =
              "Vẫn mất kết nối mạng. Vui lòng kiểm tra đường truyền.";
        });
      }
      return;
    }
    if (_currentUrl.isNotEmpty) {
      _loadUrl(_currentUrl, isRetry: true);
    } else {
      _loadUrl(MenuConfig.homeUrl, isRetry: true);
    }
  }

  void _updateCurrentNavIndex(String url) {
    if (!mounted) return;
    for (int i = 0; i < MenuConfig.bottomNavItems.length; i++) {
      Uri itemUri;
      try {
        itemUri = Uri.parse(MenuConfig.bottomNavItems[i].url);
      } catch (_) { continue; }
      Uri currentLoadedUri;
      try {
        currentLoadedUri = Uri.parse(url);
      } catch (_) { continue; }
      bool hostMatch = (itemUri.hasAuthority && itemUri.host == currentLoadedUri.host) || !itemUri.hasAuthority;
      bool pathMatch = currentLoadedUri.path.startsWith(itemUri.path);
      if (hostMatch && pathMatch) {
        if (_currentNavIndex != i) {
          setState(() {
            _currentNavIndex = i;
          });
        }
        return;
      }
    }
  }


  void _onBottomNavTap(int index) {
    if (index != _currentNavIndex) {
      if (mounted) {
        setState(() {
          _isError = false;
          _currentNavIndex = index; // Cập nhật UI ngay
        });
      }
      _loadUrl(MenuConfig.bottomNavItems[index].url);
    }
  }

  void _onNavigate(String url) {
    if (mounted) {
      setState(() {
        _isError = false;
      });
    }
    _loadUrl(url);
  }

  void _onLoginRequired() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0.0),
          contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
          actionsPadding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
          icon: Icon(
            Icons.login_rounded,
            color: Theme.of(dialogContext).colorScheme.primary,
            size: 48.0,
          ),
          title: Center(
            child: Text(
              'Yêu Cầu Đăng Nhập',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20.0,
                color: Theme.of(dialogContext).colorScheme.onSurface,
              ),
            ),
          ),
          content: Text(
            'Bạn cần đăng nhập để tiếp tục sử dụng tính năng này. Vui lòng đăng nhập.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16.0,
              color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'Hủy Bỏ',
                style: TextStyle(
                  fontSize: 16.0,
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_pin_circle_outlined, size: 20),
              label: const Text(
                'Đăng Nhập',
                style: TextStyle(fontSize: 16.0),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.primary,
                foregroundColor: Theme.of(dialogContext).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                elevation: 2.0,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (mounted) {
                  setState(() {
                    _isError = false;
                  });
                }
                _loadUrl(_loginUrl);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dịch vụ công Thành ủy Hà Nội'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: (_isLoadingPage || (!_isConnected && _isError)) ? null : _retryLoading,
          ),
        ],
      ),
      drawer: AppDrawer(
        onNavigate: _onNavigate,
        isLoggedIn: _isLoggedIn,
        onLoginRequired: _onLoginRequired,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_webViewController != null)
                  WebViewWidget(controller: _webViewController!),

                if (_isLoadingPage)
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text("Đang tải trang...", style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),

                if (_isError && !_isLoadingPage)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            !_isConnected ? Icons.signal_wifi_off_rounded : Icons.error_outline_rounded,
                            color: Colors.redAccent,
                            size: 60,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 17, color: Theme.of(context).textTheme.bodyLarge?.color),
                          ),
                          const SizedBox(height: 25),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh_rounded),
                            onPressed: (_isConnected || (_errorMessage.contains("Không thể tải trang") && !_errorMessage.toLowerCase().contains("mất kết nối"))) ? _retryLoading : null,
                            label: const Text('Thử lại'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              textStyle: const TextStyle(fontSize: 16)
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_webViewController == null && !_isLoadingPage && !_isError)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.web_stories_outlined,
                            size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Sẵn sàng duyệt web.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => _loadUrl(MenuConfig.homeUrl),
                          child: const Text('Bắt đầu với trang chủ'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: _onBottomNavTap,
        isLoggedIn: _isLoggedIn,
        onLoginRequired: _onLoginRequired,
      ),
    );
  }
}