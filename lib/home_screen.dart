import 'dart:async'; // Thêm import này
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Thêm import này
import 'js_bridge_util.dart';
import 'menu_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  WebViewController? _webViewController;
  JsBridgeUtil? _jsBridgeUtil;

  // Biến trạng thái cho việc tải và lỗi
  bool _isLoadingPage =
      true; // Đổi tên từ _isLoading để rõ ràng hơn là tải trang
  bool _isError = false;
  String _errorMessage = 'Đã xảy ra lỗi. Vui lòng thử lại.';

  String _currentUrl = '';
  bool _isLoggedIn = false;
  int _currentNavIndex = 0;

  // Các URL mặc định
  // final List<String> _defaultUrls = [
  //   'http://113.160.48.99:8791',
  //   'http://113.160.48.99:8798'
  // ]; // Bạn có thể giữ lại nếu cần dùng

  // URL trang đăng nhập
  final String _loginUrl = 'http://113.160.48.99:8791/Account/Login';

  // Connectivity
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isConnected = true; // Giả định ban đầu là có kết nối

  @override
  void initState() {
    super.initState();
    _currentUrl = MenuConfig.homeUrl; // Gán _currentUrl ban đầu
    _urlController.text = _currentUrl;

    // Kiểm tra kết nối mạng ban đầu và lắng nghe thay đổi
    _checkInitialConnectivity();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);

    _loadUrl(_currentUrl); // Tải URL ban đầu
  }

  Future<void> _checkInitialConnectivity() async {
    List<ConnectivityResult> connectivityResult =
        await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResult, isInitialCheck: true);
  }

  void _updateConnectionStatus(List<ConnectivityResult> result,
      {bool isInitialCheck = false}) {
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
          // Nếu có kết nối trở lại và đang ở trạng thái lỗi, thử tải lại
          if (_isError) {
            // Không tự động tải lại ở đây nữa, để người dùng nhấn "Thử lại"
            // _retryLoading();
            // Chỉ cần cập nhật lại thông báo nếu trước đó là lỗi mạng
            setState(() {
              _isError = false; // Reset lỗi để cho phép thử lại
            });
          }
        }
      });
    } else if (isInitialCheck && !_isConnected) {
      // Trường hợp ban đầu vào app đã không có mạng
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
    _connectivitySubscription?.cancel(); // Hủy subscription
    super.dispose();
  }

  void _loadUrl(String url, {bool isRetry = false}) {
    if (url.isEmpty) return;

    // Thêm http:// nếu URL không bắt đầu bằng http:// hoặc https://
    String effectiveUrl = url;
    if (!effectiveUrl.startsWith('http://') &&
        !effectiveUrl.startsWith('https://')) {
      effectiveUrl = 'http://$effectiveUrl';
    }

    // Chỉ cập nhật _currentUrl nếu không phải là retry cùng URL,
    // hoặc nếu là retry nhưng _currentUrl trống (trường hợp lỗi ban đầu)
    if (!isRetry || _currentUrl.isEmpty) {
      _currentUrl = effectiveUrl;
    }
    _urlController.text = _currentUrl;

    setState(() {
      _isLoadingPage = true;
      _isError = false; // Reset trạng thái lỗi mỗi khi tải URL mới
    });

    // Nếu chưa có kết nối mạng, hiển thị lỗi ngay
    if (!_isConnected) {
      setState(() {
        _isLoadingPage = false;
        _isError = true;
        _errorMessage =
            "Không có kết nối mạng. Vui lòng kiểm tra lại đường truyền.";
      });
      return;
    }

    // Khởi tạo WebViewController mới mỗi lần load URL
    // Điều này đảm bảo trạng thái WebView được làm mới hoàn toàn
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoadingPage = true;
              _isError = false; // Quan trọng: reset lỗi khi trang bắt đầu tải
            });
          },
          onPageFinished: (String url) async {
            // Thiết lập JavaScript Bridge
            if (_webViewController != null) {
              _jsBridgeUtil = JsBridgeUtil(_webViewController!);
              await _jsBridgeUtil!.setupJavaScriptHandlers();
            }

            // Kiểm tra trạng thái đăng nhập
            final isLoggedIn = await _jsBridgeUtil?.checkLoginStatus() ?? false;

            setState(() {
              _isLoadingPage = false;
              // _isError giữ nguyên, không thay đổi ở đây trừ khi có lỗi thực sự
              _isLoggedIn = isLoggedIn;
            });

            // Cập nhật index của bottom navigation bar dựa trên URL hiện tại
            _updateCurrentNavIndex(url);
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoadingPage = false;
              _isError = true;
              // Phân biệt lỗi do mất kết nối mạng hay lỗi khác từ web
              if (error.errorCode == -2 /* NET::ERR_INTERNET_DISCONNECTED */ ||
                      error.errorCode == -6 /* NET::ERR_NAME_NOT_RESOLVED */ ||
                      error.description
                          .toLowerCase()
                          .contains('net::err_internet_disconnected') ||
                      error.description
                          .toLowerCase()
                          .contains('net::err_name_not_resolved') ||
                      error.description.toLowerCase().contains('no internet') ||
                      error.errorType ==
                          WebResourceErrorType
                              .hostLookup || // Thêm các type lỗi mạng
                      error.errorType == WebResourceErrorType.connect ||
                      !_isConnected // Kiểm tra lại biến _isConnected
                  ) {
                _errorMessage =
                    "Không thể kết nối tới máy chủ hoặc không có kết nối mạng. Vui lòng thử lại.";
              } else {
                _errorMessage =
                    "Không thể tải trang. Lỗi: ${error.description}";
              }
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            // Giữ nguyên logic của bạn
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
          Uri.parse(_currentUrl)); // Luôn dùng _currentUrl đã được cập nhật

    // Cần setState sau khi gán _webViewController để UI rebuild với WebView mới (nếu có)
    // Tuy nhiên, các setState trong onPageStarted/Finished/Error đã đủ để cập nhật UI
    // setState(() {}); // Có thể không cần thiết ở đây nữa
  }

  void _retryLoading() {
    // Nếu vẫn không có mạng, không thử lại, chỉ cập nhật thông báo nếu cần
    if (!_isConnected) {
      setState(() {
        _isLoadingPage = false; // Đảm bảo không hiển thị loading
        _isError = true;
        _errorMessage = "Vẫn mất kết nối mạng. Vui lòng kiểm tra đường truyền.";
      });
      return;
    }
    // Nếu có mạng, tiến hành tải lại URL hiện tại
    if (_currentUrl.isNotEmpty) {
      _loadUrl(_currentUrl, isRetry: true);
    } else {
      // Trường hợp không có _currentUrl (ví dụ: lỗi ngay khi mở app)
      // thì thử tải lại URL mặc định ban đầu (MenuConfig.homeUrl)
      _loadUrl(MenuConfig.homeUrl, isRetry: true);
    }
  }

  void _updateCurrentNavIndex(String url) {
    for (int i = 0; i < MenuConfig.bottomNavItems.length; i++) {
      if (url.contains(MenuConfig.bottomNavItems[i].url)) {
        setState(() {
          _currentNavIndex = i;
        });
        return;
      }
    }
  }

  void _onBottomNavTap(int index) {
    if (index != _currentNavIndex) {
      // Reset lỗi khi chuyển tab, vì sẽ load URL mới
      setState(() {
        _isError = false;
      });
      _loadUrl(MenuConfig.bottomNavItems[index].url);
      // _currentNavIndex sẽ được cập nhật trong onPageFinished -> _updateCurrentNavIndex
      // Tuy nhiên, để UI phản hồi ngay lập tức, có thể cập nhật ở đây:
      // setState(() {
      //  _currentNavIndex = index;
      // });
    }
  }

  void _onNavigate(String url) {
    // Reset lỗi khi điều hướng, vì sẽ load URL mới
    setState(() {
      _isError = false;
    });
    _loadUrl(url);
  }

  void _onLoginRequired() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yêu cầu đăng nhập'),
        content: const Text('Bạn cần đăng nhập để sử dụng tính năng này.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Reset lỗi trước khi tải trang đăng nhập
              setState(() {
                _isError = false;
              });
              _loadUrl(_loginUrl);
            },
            child: const Text('Đăng nhập'),
          ),
        ],
      ),
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
            onPressed: _retryLoading, // Sử dụng _retryLoading cho nút refresh
          ),
        ],
      ),
      drawer: AppDrawer(
        onNavigate: _onNavigate,
        isLoggedIn: _isLoggedIn,
        onLoginRequired: _onLoginRequired,
      ),
      body: Column(
        // Giữ nguyên cấu trúc Column của bạn
        children: [
          // Padding( ... TextField ... ) // Giữ nguyên nếu bạn muốn kích hoạt lại thanh URL
          Expanded(
            child: Stack(
              children: [
                // WebViewWidget
                if (_webViewController != null &&
                    !_isError) // Chỉ hiển thị WebView nếu controller tồn tại và không có lỗi
                  WebViewWidget(controller: _webViewController!),

                // Màn hình chờ tải trang
                if (_isLoadingPage)
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text("Đang tải trang..."),
                      ],
                    ),
                  ),

                // Màn hình lỗi (bao gồm cả mất kết nối)
                // Hiển thị khi có lỗi (_isError = true) VÀ không đang tải (_isLoadingPage = false)
                if (_isError && !_isLoadingPage)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.symmetric(horizontal: 30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 5,
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            _isConnected
                                ? Icons.error_outline
                                : Icons.signal_wifi_off_outlined,
                            color: Colors.red,
                            size: 50,
                          ),
                          const SizedBox(height: 15),
                          Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _retryLoading,
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Placeholder ban đầu nếu chưa có gì để hiển thị và không lỗi/loading
                // (Ví dụ: lần đầu mở app và chưa load gì, hoặc khi webview bị ẩn do lỗi nhưng chưa có thông báo lỗi cụ thể)
                if (_webViewController == null && !_isLoadingPage && !_isError)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.web_outlined,
                            size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Không có nội dung để hiển thị.',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () =>
                              _loadUrl(MenuConfig.homeUrl), // Tải lại trang chủ
                          child: const Text('Tải trang chủ'),
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
