import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
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
  bool _isLoading = false;
  String _currentUrl = '';
  bool _isLoggedIn = false;
  int _currentNavIndex = 0;

  // Các URL mặc định
  final List<String> _defaultUrls = [
    'http://113.160.48.99:8791',
    'http://113.160.48.99:8798'
  ];

  // URL trang đăng nhập
  final String _loginUrl = 'http://113.160.48.99:8791/Account/Login';

  @override
  void initState() {
    super.initState();
    _urlController.text = MenuConfig.homeUrl; // Đặt URL mặc định là trang chủ
    _loadUrl(MenuConfig.homeUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _loadUrl(String url) {
    if (url.isEmpty) return;

    // Thêm http:// nếu URL không bắt đầu bằng http:// hoặc https://
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    setState(() {
      _isLoading = true;
      _currentUrl = url;
      _urlController.text = url;
    });

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) async {
            // Thiết lập JavaScript Bridge
            _jsBridgeUtil = JsBridgeUtil(_webViewController!);
            await _jsBridgeUtil!.setupJavaScriptHandlers();

            // Kiểm tra trạng thái đăng nhập
            final isLoggedIn = await _jsBridgeUtil!.checkLoginStatus();

            setState(() {
              _isLoading = false;
              _isLoggedIn = isLoggedIn;
            });

            // Cập nhật index của bottom navigation bar dựa trên URL hiện tại
            _updateCurrentNavIndex(url);
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi: ${error.description}')),
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    setState(() {});
  }

  // Cập nhật index của bottom navigation bar dựa trên URL hiện tại
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

  // Xử lý khi chọn item trong bottom navigation bar
  void _onBottomNavTap(int index) {
    if (index != _currentNavIndex) {
      _loadUrl(MenuConfig.bottomNavItems[index].url);
      setState(() {
        _currentNavIndex = index;
      });
    }
  }

  // Xử lý khi chọn menu item từ drawer hoặc các chức năng chính
  void _onNavigate(String url) {
    _loadUrl(url);
  }

  // Xử lý khi người dùng cố gắng truy cập tính năng yêu cầu đăng nhập
  void _onLoginRequired() {
    // Hiển thị thông báo yêu cầu đăng nhập
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
          // Hiển thị trạng thái đăng nhập

          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_webViewController != null) {
                _webViewController!.reload();
              }
            },
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
          // Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: Row(
          //     children: [
          //       Expanded(
          //         child: TextField(
          //           controller: _urlController,
          //           decoration: const InputDecoration(
          //             labelText: 'Nhập địa chỉ web',
          //             border: OutlineInputBorder(),
          //             contentPadding:
          //                 EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          //           ),
          //           keyboardType: TextInputType.url,
          //           textInputAction: TextInputAction.go,
          //           onSubmitted: (value) => _loadUrl(value),
          //         ),
          //       ),
          //       const SizedBox(width: 8),
          //       ElevatedButton(
          //         onPressed: () => _loadUrl(_urlController.text),
          //         child: const Text('Truy cập'),
          //       ),
          //     ],
          //   ),
          // ),
          // Hiển thị các chức năng chính khi đang ở trang chủ

          Expanded(
            child: Stack(
              children: [
                if (_webViewController != null)
                  WebViewWidget(controller: _webViewController!),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                if (_webViewController == null && !_isLoading)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.web, size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'Nhập địa chỉ web và nhấn Truy cập',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => _loadUrl(_urlController.text),
                          child: const Text('Bắt đầu'),
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
