import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'js_bridge_util.dart';
// Import các màn hình chức năng
import 'party_fee_screen.dart';
import 'review_form_screen.dart';

class LoginScreen extends StatefulWidget {
  final String initialUrl;

  const LoginScreen({
    Key? key,
    required this.initialUrl,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late WebViewController _webViewController;
  late JsBridgeUtil _jsBridgeUtil;
  bool _isLoading = true;
  bool _isLoggedIn = false; // Sẽ dùng để điều khiển AppBar và menu
  String _currentWebViewUrl = ''; // Lưu URL hiện tại của WebView

  @override
  void initState() {
    super.initState();
    _currentWebViewUrl = widget.initialUrl; // Khởi tạo
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _currentWebViewUrl = url; // Cập nhật URL khi trang bắt đầu tải
            });
          },
          onPageFinished: (String url) async {
            if (!mounted) return;
            _jsBridgeUtil = JsBridgeUtil(_webViewController);
            await _jsBridgeUtil.setupJavaScriptHandlers();

            final isLoggedInOnWeb = await _jsBridgeUtil.checkLoginStatus();
            if (!mounted) return;

            setState(() {
              _isLoading = false;
              _isLoggedIn = isLoggedInOnWeb;
              _currentWebViewUrl = url; // URL cuối cùng sau khi tải xong
            });

            if (isLoggedInOnWeb) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đăng nhập thành công')),
              );
              // Không pop màn hình nữa
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi tải trang: ${error.description}')),
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  // Các phương thức điều hướng và xử lý menu (tương tự HomeScreen)
  void _navigateToPartyFee() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PartyFeeScreen(
          initialUrl: _currentWebViewUrl, // Truyền URL hiện tại của LoginScreen
        ),
      ),
    );
  }

  void _navigateToReviewForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewFormScreen(
          initialUrl: _currentWebViewUrl, // Truyền URL hiện tại của LoginScreen
        ),
      ),
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'party_fee':
        _navigateToPartyFee();
        break;
      case 'review_form':
        _navigateToReviewForm();
        break;
      case 'account_info':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chức năng Thông tin tài khoản')),
        );
        // TODO: Điều hướng đến trang thông tin tài khoản thực tế nếu có
        break;
      case 'statistics_report':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chức năng Báo cáo thống kê')),
        );
        // TODO: Điều hướng đến trang báo cáo thực tế nếu có
        break;
      case 'logout':
        _logout();
        break;
    }
  }

  Future<void> _logout() async {
    // TODO: Nếu có cơ chế logout phía webview (ví dụ: gọi một hàm JS để xóa session/cookie web),
    // bạn nên gọi nó ở đây thông qua _jsBridgeUtil.
    // Ví dụ: await _jsBridgeUtil?.logoutFromWeb();

    if (!mounted) return;
    setState(() {
      _isLoggedIn = false;
    });
    // Tải lại trang đăng nhập ban đầu hoặc một trang mặc định cho người chưa đăng nhập
    _webViewController.loadRequest(Uri.parse(widget.initialUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã đăng xuất')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: Text(_isLoggedIn ? 'Trang chủ' : 'Đăng nhập'), // Tiêu đề có thể thay đổi
        title: Text(_isLoggedIn &&
                Uri.parse(_currentWebViewUrl)
                    .path
                    .toLowerCase()
                    .contains('home')
            ? 'Hệ Thống Thông tin Đảng Viên'
            : 'Đăng nhập'),
        backgroundColor: _isLoggedIn
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.inversePrimary,
        actions: <Widget>[
          // Nút tài khoản (nếu cần, tương tự HomeScreen)

          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _webViewController.reload();
            },
            tooltip: 'Tải lại trang',
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
