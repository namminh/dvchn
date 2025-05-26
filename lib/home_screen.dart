import 'dart:async';
import 'dart:convert'; // Thêm import này nếu bạn dùng jsonDecode cho JavaScriptChannel

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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

  StreamSubscription<InternetConnectionStatus>? _connectivitySubscription;
  bool _isConnected = true;

  final List<String> _externalDomains = [
    'sso.dancuquocgia.gov.vn',
    'xacthuc.dichvucong.gov.vn',
    // Thêm các domain SSO hoặc trang thanh toán bên ngoài khác nếu có
  ];

  bool _isExternalUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return _externalDomains.contains(uri.host);
    } catch (_) {
      return false; // Nếu URL không hợp lệ, coi như không phải external
    }
  }

  @override
  void initState() {
    super.initState();
    _currentUrl = MenuConfig.homeUrl;
    _urlController.text = _currentUrl;

    _checkInitialConnectivity();
    final checker = InternetConnectionChecker.createInstance();
    _connectivitySubscription = checker.onStatusChange.listen(
      (status) {
        _updateConnectionStatus(status == InternetConnectionStatus.connected);
      },
    );

    _loadUrl(_currentUrl);
  }

  Future<void> _checkInitialConnectivity() async {
    final checker = InternetConnectionChecker.createInstance();
    bool isConnected = await checker.hasConnection;
    _updateConnectionStatus(isConnected, isInitialCheck: true);
  }

  void _updateConnectionStatus(bool isConnected,
      {bool isInitialCheck = false}) {
    if (!mounted) return;

    bool currentlyConnected = !result.contains(ConnectivityResult.none);

    if (_isConnected != currentlyConnected) {
      setState(() {
        _isConnected = isConnected;
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
    // CHƯA THỰC HIỆN: Đây là nơi bạn sẽ thêm các JavaScriptChannel nếu sửa JsBridgeUtil
    // Ví dụ:
    // _webViewController?.addJavaScriptChannel(
    //   'loginResultHandler',
    //   onMessageReceived: (JavaScriptMessage message) {
    //     print('loginResultHandler received: ${message.message}');
    //     try {
    //       final data = jsonDecode(message.message);
    //       // Xử lý data...
    //     } catch (e) {
    //       print('Error decoding message from loginResultHandler: $e');
    //     }
    //   },
    // );
    // ... thêm các channels khác ...
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

    // KHỞI TẠO WEBVIEWCONTROLLER VÀ NAVIGATIONDELEGATE
    final tempController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String navUrl) {
            print('WebView Delegate: Page started loading: $navUrl');
            if (mounted) {
              setState(() {
                _isLoadingPage = true;
                _isError = false;
              });
            }
          },
          onPageFinished: (String finishedUrl) async {
            print('WebView Delegate: Page finished loading: $finishedUrl');
            if (!mounted) return;

            bool isExternal = _isExternalUrl(finishedUrl);
            bool isPublicFunc = _isPublicFunctionUrl(finishedUrl);

            if (!isExternal && _webViewController != null) {
              // Chỉ thiết lập JS bridge và kiểm tra đăng nhập cho domain của bạn
              // Khởi tạo JsBridgeUtil với controller hiện tại (đã được gán cho _webViewController)
              _jsBridgeUtil = JsBridgeUtil(_webViewController!);
              await _jsBridgeUtil!
                  .setupJavaScriptHandlers(); // JS này vẫn cần sửa cho webview_flutter

              final isLoggedIn = await _jsBridgeUtil!
                  .checkLoginStatus(); // Hàm JS này có thể lỗi trên trang ngoài
              if (mounted) {
                setState(() {
                  _isLoadingPage = false;
                  _isLoggedIn = isLoggedIn;
                });
              }
            } else {
              // Nếu là domain ngoài (ví dụ: SSO) hoặc controller null, chỉ dừng loading
              setState(() {
                _isLoadingPage = false;
              });
            }
            _updateCurrentNavIndex(finishedUrl);
          },
          onWebResourceError: (WebResourceError error) {
            print(
                'WebView Delegate: WebResourceError: ${error.description}, URL: ${error.url}, ErrorCode: ${error.errorCode}, Type: ${error.errorType}, isForMainFrame: ${error.isForMainFrame}');
            // ... (Phần code xử lý lỗi onWebResourceError của bạn giữ nguyên) ...
            // (Phần này khá dài trong code gốc của bạn, hãy đảm bảo nó vẫn ở đây)
            if (!mounted) return;

            // Nếu lỗi không phải cho frame chính và đang ở trang ngoài, có thể bỏ qua việc hiển thị lỗi toàn màn hình
            if (error.isForMainFrame == false &&
                error.url != null &&
                _isExternalUrl(error.url!)) {
              print(
                  'Ignoring non-main frame error on external domain: ${error.url}');
              // Có thể hiển thị SnackBar thay vì lỗi toàn màn hình
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('đang tải')),
              );
              // Không set _isLoadingPage = false hoặc _isError = true ở đây nếu không muốn thay đổi UI chính
              return; // Thoát sớm để không xử lý như lỗi nghiêm trọng
            }

            setState(() {
              _isLoadingPage = false;
              _isError = true;

              if (!_isConnected) {
                _errorMessage =
                    "Mất kết nối mạng. Vui lòng kiểm tra lại đường truyền.";
              } else if (error.isForMainFrame == true &&
                  (error.url == _currentUrl ||
                      _isExternalUrl(error.url ?? _currentUrl))) {
                // Lỗi tải trang chính (SSO hoặc trang hiện tại)
                _errorMessage = "Không thể tải trang: ${error.description}";
              } else if (error.errorCode == -2 ||
                  error.errorCode == -6 ||
                  error.description
                      .toLowerCase()
                      .contains('net::err_internet_disconnected') ||
                  error.description
                      .toLowerCase()
                      .contains('net::err_name_not_resolved') ||
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
          onNavigationRequest: (NavigationRequest request) {
            print('WebView: Navigation request to: ${request.url}');
            // Ví dụ: Xử lý các link đặc biệt (tel:, mailto:, custom schemes)
            // if (request.url.startsWith('tel:')) {
            //   // launchUrl(Uri.parse(request.url));
            //   return NavigationDecision.prevent;
            // }
            return NavigationDecision.navigate;
          },
          // ====================================================================

          onUrlChange: (UrlChange change) {
            if (change.url != null) {
              print('WebView: URL changed to: ${change.url}');
              if (mounted) {
                // Cập nhật _currentUrl nếu URL thực sự thay đổi do điều hướng trong WebView
                // Điều này quan trọng cho nút "Thử lại" và logic khác dựa trên URL hiện tại
                // Tuy nhiên, cẩn thận để không gây vòng lặp setState nếu onUrlChange và onPageFinished/Started cùng kích hoạt
                if (_currentUrl != change.url) {
                  // setState(() {
                  //   _currentUrl = change.url!;
                  //   _urlController.text = _currentUrl;
                  // });
                }
              }
            }
          },
        ),
      );

    // Gán controller và thiết lập JavaScript Channels (nếu có)
    _webViewController = tempController;
    _setupJavaScriptChannels(); // Gọi hàm thiết lập channels (hiện đang trống)

    // Tải request
    _webViewController!.loadRequest(Uri.parse(_currentUrl));

    if (mounted) {
      setState(() {}); // Rebuild để WebViewWidget sử dụng controller mới
    }
  }

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
      } catch (_) {
        continue;
      }
      Uri currentLoadedUri;
      try {
        currentLoadedUri = Uri.parse(url);
      } catch (_) {
        continue;
      }

      // So sánh host và path (hoặc chỉ path nếu itemUri không có host)
      bool hostMatch =
          (itemUri.hasAuthority && itemUri.host == currentLoadedUri.host) ||
              !itemUri.hasAuthority;
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
          // _currentNavIndex = index; // Cập nhật ngay lập tức hoặc chờ onPageFinished
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 12.0),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 12.0),
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
            onPressed: (_isLoadingPage || (!_isConnected && _isError))
                ? null
                : _retryLoading,
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
                        Text("Đang tải trang...",
                            style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                if (_isError && !_isLoadingPage)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 30),
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
                            !_isConnected
                                ? Icons.signal_wifi_off_rounded
                                : Icons.error_outline_rounded,
                            color: Colors.redAccent,
                            size: 60,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 17,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color),
                          ),
                          const SizedBox(height: 25),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh_rounded),
                            onPressed: (_isConnected ||
                                    (_errorMessage
                                            .contains("Không thể tải trang") &&
                                        !_errorMessage
                                            .toLowerCase()
                                            .contains("mất kết nối")))
                                ? _retryLoading
                                : null,
                            label: const Text('Thử lại'),
                            style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                textStyle: const TextStyle(fontSize: 16)),
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
