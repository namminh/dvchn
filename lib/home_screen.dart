import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'menu_widgets.dart'; // Assuming AppDrawer and AppBottomNavBar are here
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart'; // Thêm package shimmer để tạo hiệu ứng loading đẹp hơn
import './procedures_screen.dart';

/// Helper class for menu item structure.
class BottomNavItem {
  final String label;
  final IconData icon;
  final String url;
  final bool requiresLogin;

  const BottomNavItem({
    required this.label,
    required this.icon,
    required this.url,
    this.requiresLogin = false,
  });
}

/// Constants for repeated strings and configuration.
class _HomeScreenConstants {
  static const String noNetworkError =
      "Không có kết nối mạng. Vui lòng kiểm tra lại đường truyền.";
  static const String serverError =
      "Máy chủ hiện đang bận. Vui lòng thử lại sau vài phút.";
  static const String timeoutError =
      "Yêu cầu mất quá nhiều thời gian. Vui lòng kiểm tra kết nối mạng và thử lại.";
  static const String genericError = "Đã xảy ra lỗi. Vui lòng thử lại sau.";

  static const String downloadChannelId = 'download_channel_id';
  static const String downloadChannelName = 'Downloads';
  static const String downloadChannelDescription =
      'Channel for download notifications';

  // Thêm các hằng số cho kích thước tối thiểu touch target
  static const double minTouchTargetSize = 48.0;
  static const double minTouchTargetSpacing = 8.0;

  // Hằng số cho AppBar
  static const double appBarHeight = 56.0; // Theo Material Design standards

  // Hằng số cho thời gian animation
  static const Duration animationDuration = Duration(milliseconds: 300);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Helper class for file picker parameters.
class _FilePickerParamsParseResult {
  final FileType fileType;
  final List<String>? allowedExtensions;

  _FilePickerParamsParseResult(this.fileType, this.allowedExtensions);
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _urlController = TextEditingController();
  WebViewController? _webViewController;
  bool _isLoadingPage = true;
  bool _isError = false;
  String _errorMessage = _HomeScreenConstants.genericError;
  String _errorType = 'generic'; // Thêm phân loại lỗi để cải thiện UX
  String _currentUrl = '';
  bool _isLoggedIn = false;
  int _currentNavIndex = 0;
  bool _isConnected = true;
  StreamSubscription? _connectivitySubscription;
  bool _showBars = true;
  double _loadingProgress = 0.0; // Thêm biến theo dõi tiến trình tải
  final List<String> _externalDomains = [
    'sso.dancuquocgia.gov.vn',
    'xacthuc.dichvucong.gov.vn',
  ];
  Widget? _currentScreen; // Current custom screen (if any)
  bool _isShowingCustomScreen = false; // Flag to track if showing custom screen

  // Initialize _menuItemUris from MenuData.bottomNavItems
  late final List<Uri?> _menuItemUris;

  // Thêm controller cho animation loading
  late AnimationController _loadingAnimationController;

  /// Safely updates state if the widget is mounted.
  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  /// Shows a SnackBar if the widget is mounted.
  void _showSnackBar(String message,
      {IconData? icon, Duration duration = const Duration(seconds: 3)}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          duration: duration,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }

  /// Formats error messages for user-friendly display.
  String _formatErrorMessage(dynamic error, {String? url}) {
    if (error is SocketException) {
      _errorType = 'network';
      return _HomeScreenConstants.noNetworkError;
    } else if (error is HttpException) {
      _errorType = 'server';
      return "Lỗi máy chủ: ${error.message}";
    } else if (error is TimeoutException) {
      _errorType = 'timeout';
      return _HomeScreenConstants.timeoutError;
    } else {
      _errorType = 'generic';
      return "${_HomeScreenConstants.genericError} ${url != null ? ' khi truy cập $url' : ''}";
    }
  }

  /// Checks if a URL belongs to an external domain.
  bool _isExternalUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return _externalDomains.contains(uri.host);
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentScreen = null;
    _isShowingCustomScreen = false;
    // Khởi tạo controller cho animation loading
    _loadingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _currentUrl = AppConfig.baseUrl; // Use Config for home URL
    _urlController.text = _currentUrl;

    // Initialize _menuItemUris from MenuData
    _menuItemUris = MenuData.bottomNavItems.map((item) {
      try {
        return Uri.parse(item.url);
      } catch (_) {
        return null;
      }
    }).toList();

    // Initialize WebViewController with enhanced settings
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Listen for messages from the webview
      ..addJavaScriptChannel(
        'NativeApp', // Renamed from 'Chrome' to be more descriptive
        onMessageReceived: (JavaScriptMessage message) {
          _handleJsMessage(message.message);
        },
      )
      // Set background color
      ..setBackgroundColor(const Color(0x00000000))
      // Configure navigation delegate with enhanced error handling and accessibility
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Track loading progress
            _safeSetState(() {
              _loadingProgress = progress / 100;
            });
          },
          onPageStarted: (String navUrl) {
            print('WebView Delegate: Page started loading: $navUrl');
            _safeSetState(() {
              _isLoadingPage = true;
              _isError = false;
              _loadingProgress = 0.0;
            });
          },
          onPageFinished: (String finishedUrl) async {
            print('WebView Delegate: Page finished loading: $finishedUrl');

            // Reset bars to be visible on every new page load
            if (!_showBars) {
              _safeSetState(() => _showBars = true);
            }

            bool isExternal = _isExternalUrl(finishedUrl);
            if (!isExternal) {
              try {
                // Inject improved JavaScript for better accessibility and UI
                await _injectAccessibilityAndUiEnhancements();

                // Update login status based on URL
                _updateLoginStatus(finishedUrl);
              } catch (e) {
                print("Error during onPageFinished JS execution: $e");
              }
            }

            _safeSetState(() {
              _isLoadingPage = false;
              _loadingProgress = 1.0;
            });

            _updateCurrentNavIndex(finishedUrl);
          },
          onWebResourceError: (WebResourceError error) {
            print(
                'WebView Delegate: WebResourceError: ${error.description}, URL: ${error.url}, Code: ${error.errorCode}, Type: ${error.errorType}, MainFrame: ${error.isForMainFrame}');

            // Ignore non-main frame errors on external domains
            if (error.isForMainFrame == false &&
                error.url != null &&
                _isExternalUrl(error.url!)) {
              print(
                  'Ignoring non-main frame error on external domain: ${error.url}');
              return;
            }

            if (error.isForMainFrame == true || error.url == _currentUrl) {
              _handleWebViewError(error);
            }
          },
          onNavigationRequest: (NavigationRequest request) async {
            print('WebView Delegate: Navigating to: ${request.url}');

            // Check if this is a file download request
            if (_isFileDownloadRequest(request.url)) {
              print('Intercepting download for ${request.url}');
              await _handleFileDownload(request.url);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) {
            if (change.url != null) {
              print('WebView Delegate: URL changed to: ${change.url}');
              _urlController.text = change.url!;
              _updateCurrentNavIndex(change.url!);
              _updateLoginStatus(change.url!);
            }
          },
        ),
      );

    // Configure Android WebView controller
    if (Platform.isAndroid) {
      final androidController =
          _webViewController!.platform as AndroidWebViewController;
      try {
        androidController.setOnShowFileSelector(_androidFilePicker);
        print("setOnShowFileSelector đã được thiết lập cho Android.");
      } catch (e) {
        _showSnackBar(
          'Không thể khởi tạo trình chọn file',
          icon: Icons.error_outline,
        );
      }
    }

    _initializeNotifications();
    _checkInitialConnectivity();

    final checker = InternetConnectionChecker.createInstance();
    _connectivitySubscription = checker.onStatusChange.listen(
      (status) =>
          _updateConnectionStatus(status == InternetConnectionStatus.connected),
    );

    _loadUrl(_currentUrl);
  }

  // **[ADDED]** Method to switch to custom screen
  void _switchToScreen(Widget screen) {
    _safeSetState(() {
      _currentScreen = screen;
      _isShowingCustomScreen = true;
    });
  }

  // **[ADDED]** Method to switch back to WebView
  void _switchToWebView(String url) {
    _safeSetState(() {
      _currentScreen = null;
      _isShowingCustomScreen = false;
    });
    _loadUrl(url);
  }

  // **[MODIFIED]** Updated _onBottomNavTap method
  void _onBottomNavTap(int index) {
    if (index < 0 || index >= MenuData.bottomNavItems.length) return;
    final selectedItem = MenuData.bottomNavItems[index];

    // **[ADDED]** Special handling for "Thủ tục" tab (index 1)
    if (index == 1 && selectedItem.title == 'Thủ tục') {
      print("Switching to ProceduresScreen for tab: ${selectedItem.title}");

      // Create ProceduresScreen with proper callbacks
      final proceduresScreen = ProceduresScreen(
        onNavigateToUrl: (String url) {
          print("ProceduresScreen: Navigating to URL: $url");
          _switchToWebView(url);
        },
        isLoggedIn: _isLoggedIn,
        onLoginRequired: _onLoginRequired,
      );

      _switchToScreen(proceduresScreen);

      // Update nav index for visual feedback
      _safeSetState(() {
        _currentNavIndex = index;
      });

      return;
    }

    // **[EXISTING]** Handle login requirement for other tabs
    if (selectedItem.requiresLogin && !_isLoggedIn) {
      _onLoginRequired();
      return;
    }

    // **[MODIFIED]** For other tabs, switch back to WebView if currently showing custom screen
    if (_isShowingCustomScreen) {
      _switchToWebView(selectedItem.url);
    } else {
      // **[EXISTING]** Avoid reloading if already on the same page
      if (_currentUrl == selectedItem.url &&
          _currentNavIndex == index &&
          !_isLoadingPage &&
          !_isError) {
        print("Already on selected tab: ${selectedItem.title}");
        return;
      }

      _safeSetState(() {
        _isError = false;
      });
      _loadUrl(selectedItem.url);
    }
  }

  /// Kiểm tra xem URL có phải là request tải file hay không
  bool _isFileDownloadRequest(String url) {
    const fileExtensions = [
      '.pdf',
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
      '.doc',
      '.docx',
      '.xls',
      '.xlsx',
      '.ppt',
      '.pptx',
      '.txt',
      '.csv',
      '.rtf',
      '.odt',
      '.ods',
      '.odp',
      '.zip',
      '.rar',
      '.7z',
      '.tar',
      '.gz',
    ];

    final lowercasedUrl = url.toLowerCase();
    bool hasFileExtension =
        fileExtensions.any((ext) => lowercasedUrl.endsWith(ext));
    bool isApiDownloadLink = url.contains('File');

    return hasFileExtension || isApiDownloadLink;
  }

  /// Xử lý tải file từ URL
  Future<void> _handleFileDownload(String url) async {
    String suggestedFileName;
    List<String> pathSegments = Uri.parse(url).pathSegments;

    // Determine suggested file name based on URL structure
    if (url.contains('File') && pathSegments.isNotEmpty) {
      int downloadKeywordIndex =
          pathSegments.indexWhere((s) => s.toLowerCase() == 'File');
      suggestedFileName = downloadKeywordIndex != -1 &&
              downloadKeywordIndex + 1 < pathSegments.length &&
              pathSegments[downloadKeywordIndex + 1].isNotEmpty
          ? pathSegments[downloadKeywordIndex + 1]
          : pathSegments.isNotEmpty
              ? pathSegments.last
              : 'downloaded_item';
    } else {
      suggestedFileName =
          pathSegments.isNotEmpty ? pathSegments.last : 'downloaded_file';
    }

    // Validate filename
    if (suggestedFileName.isEmpty ||
        Uri.tryParse(suggestedFileName)?.hasAuthority == true) {
      suggestedFileName =
          'downloaded_file_${DateTime.now().millisecondsSinceEpoch}';
    }

    await _downloadFile(url, suggestedFileName);
  }

  /// Xử lý tin nhắn từ JavaScript
  void _handleJsMessage(String message) {
    if (message == 'hideBars' && _showBars) {
      _safeSetState(() {
        _showBars = false;
      });
    } else if (message == 'showBars' && !_showBars) {
      _safeSetState(() {
        _showBars = true;
      });
    } else if (message.startsWith('error:')) {
      // Handle error messages from JavaScript
      String errorDetails = message.substring(6);
      _showSnackBar(
        'Lỗi JavaScript: $errorDetails',
        icon: Icons.code,
        duration: const Duration(seconds: 5),
      );
    } else if (message.startsWith('log:')) {
      // Log message from JavaScript (for debugging)
      print('JS Log: ${message.substring(4)}');
    }
  }

  /// Xử lý lỗi WebView
  void _handleWebViewError(WebResourceError error) {
    _safeSetState(() {
      _isLoadingPage = false;
      _isError = true;

      // Determine error type and set appropriate message
      if (!_isConnected) {
        _errorType = 'network';
        _errorMessage = _HomeScreenConstants.noNetworkError;
      } else if (error.errorCode == -2 ||
          error.errorType == WebResourceErrorType.hostLookup ||
          error.errorType == WebResourceErrorType.connect) {
        _errorType = 'network';
        _errorMessage =
            "Không thể kết nối tới máy chủ. Vui lòng kiểm tra kết nối mạng.";
      } else if (error.errorType == WebResourceErrorType.timeout) {
        _errorType = 'timeout';
        _errorMessage = _HomeScreenConstants.timeoutError;
      } else if (error.errorCode >= 500 && error.errorCode < 600) {
        _errorType = 'server';
        _errorMessage = _HomeScreenConstants.serverError;
      } else {
        _errorType = 'generic';
        _errorMessage = "Không thể tải trang. Vui lòng thử lại sau.";
      }
    });
  }

  /// Inject JavaScript to enhance accessibility and UI
  Future<void> _injectAccessibilityAndUiEnhancements() async {
    await _webViewController?.runJavaScript('''
    try {
      // Improve accessibility by adding missing attributes
      function enhanceAccessibility() {
        // Add alt text to images that don't have it
        document.querySelectorAll('img:not([alt])').forEach(function(img) {
          img.alt = img.src.split('/').pop() || 'Image';
        });
        
        // Add aria-labels to buttons without text
        document.querySelectorAll('button:not([aria-label])').forEach(function(btn) {
          if (!btn.textContent.trim()) {
            // Try to use title, or nearby text, or icon name
            btn.setAttribute('aria-label', btn.title || btn.getAttribute('title') || 'Button');
          }
        });
        
        // Make sure all form inputs have labels
        document.querySelectorAll('input, select, textarea').forEach(function(input) {
          if (!input.getAttribute('aria-label') && !input.getAttribute('aria-labelledby')) {
            let id = input.id;
            if (id) {
              let label = document.querySelector('label[for="' + id + '"]');
              if (!label) {
                input.setAttribute('aria-label', input.placeholder || input.name || 'Input field');
              }
            } else {
              input.setAttribute('aria-label', input.placeholder || input.name || 'Input field');
            }
          }
        });
        
        // Ensure proper focus indicators
        document.querySelectorAll('a, button, [role="button"], input, select, textarea').forEach(function(el) {
          if (getComputedStyle(el).outline === 'none' && getComputedStyle(el).outlineStyle === 'none') {
            el.addEventListener('focus', function() {
              this.style.outline = '2px solid #4285f4';
              this.style.outlineOffset = '2px';
            });
            el.addEventListener('blur', function() {
              this.style.outline = '';
              this.style.outlineOffset = '';
            });
          }
        });
      }
      
      // Hide website headers and footers for better mobile experience
      function hideHeadersAndFooters() {
        var headerSelectors = ['header', '#header', '.header', '#topnav', '.topnav', '#main-header', '.main-header', 'app-header', 'mat-toolbar[role="heading"]', 'div[role="banner"]', 'nav'];
        headerSelectors.forEach(function(selector) {
          var elements = document.querySelectorAll(selector);
          elements.forEach(function(el) {
            if (el.offsetHeight < window.innerHeight * 0.3 && el.offsetWidth >= window.innerWidth * 0.5) {
              el.style.display = 'none';
            }
          });
        });
        
        var footerSelectors = ['footer', '#footer', '.footer', '#main-footer', '.main-footer', 'app-footer', 'div[role="contentinfo"]'];
        footerSelectors.forEach(function(selector) {
          var elements = document.querySelectorAll(selector);
          elements.forEach(function(el) { el.style.display = 'none'; });
        });
        
        document.body.style.paddingTop = '0px';
        document.body.style.paddingBottom = '0px';
        document.body.style.marginTop = '0px';
        document.body.style.marginBottom = '0px';
      }
      
      // Setup scroll handler to show/hide native bars
      function setupScrollHandler() {
        let lastScrollTop = window.pageYOffset || document.documentElement.scrollTop;
        let scrollTimeout;
        
        window.addEventListener('scroll', function() {
          // Clear the timeout if it's already set
          clearTimeout(scrollTimeout);
          
          let scrollTop = window.pageYOffset || document.documentElement.scrollTop;
          if (scrollTop > lastScrollTop && scrollTop > 60) { // Scrolling down past a threshold
            window.NativeApp.postMessage('hideBars');
          } else if (scrollTop < lastScrollTop) { // Scrolling up
            window.NativeApp.postMessage('showBars');
          }
          
          lastScrollTop = scrollTop <= 0 ? 0 : scrollTop;
          
          // Set a timeout to show bars when scrolling stops
          scrollTimeout = setTimeout(function() {
            window.NativeApp.postMessage('showBars');
          }, 3000);
        }, { passive: true });
      }
      
      // Optimize touch targets for better mobile accessibility
      function optimizeTouchTargets() {
        const minSize = ${_HomeScreenConstants.minTouchTargetSize};
        
        document.querySelectorAll('a, button, [role="button"], input[type="submit"], input[type="button"], input[type="checkbox"], input[type="radio"]').forEach(function(el) {
          const rect = el.getBoundingClientRect();
          
          // If element is too small, increase its size
          if (rect.width < minSize || rect.height < minSize) {
            // For inline elements, convert to inline-block
            if (getComputedStyle(el).display === 'inline') {
              el.style.display = 'inline-block';
            }
            
            // Set minimum dimensions
            if (rect.width < minSize) {
              el.style.minWidth = minSize + 'px';
            }
            
            if (rect.height < minSize) {
              el.style.minHeight = minSize + 'px';
            }
            
            // Add padding if needed
            if (rect.width < minSize || rect.height < minSize) {
              const currentPadding = getComputedStyle(el).padding;
              if (currentPadding === '0px' || currentPadding === '') {
                el.style.padding = '12px';
              }
            }
          }
        });
      }
      
      // Run all enhancements
      enhanceAccessibility();
      hideHeadersAndFooters();
      setupScrollHandler();
      optimizeTouchTargets();
      
      // Monitor for dynamic content changes
      const observer = new MutationObserver(function(mutations) {
        enhanceAccessibility();
        optimizeTouchTargets();
      });
      
      // Start observing the document for changes
      observer.observe(document.body, { 
        childList: true, 
        subtree: true 
      });
      
      window.NativeApp.postMessage('log:Accessibility enhancements applied');
    } catch (e) {
      window.NativeApp.postMessage('error:' + e.toString());
    }
    ''');
  }

  /// Update login status based on URL
  void _updateLoginStatus(String url) {
    final lowerUrl = url.toLowerCase();

    if (lowerUrl.startsWith(AppConfig.baseUrl.toLowerCase()) &&
        !lowerUrl.contains("returnurl") &&
        !lowerUrl.startsWith(AppConfig.loginUrl.toLowerCase())) {
      _safeSetState(() => _isLoggedIn = true);
    } else if (lowerUrl.startsWith(AppConfig.loginUrl.toLowerCase()) ||
        lowerUrl.startsWith(AppConfig.authenticationUrl.toLowerCase())) {
      _safeSetState(() => _isLoggedIn = false);
    }
  }

  Future<void> _initializeNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await FlutterLocalNotificationsPlugin().initialize(
      settings,
      onDidReceiveNotificationResponse: (response) async {
        if (response.payload != null && response.payload!.isNotEmpty) {
          OpenFile.open(response.payload);
        }
      },
    );
  }

  Future<void> _showDownloadNotification(
      String fileName, String filePath) async {
    const androidDetails = AndroidNotificationDetails(
      _HomeScreenConstants.downloadChannelId,
      _HomeScreenConstants.downloadChannelName,
      channelDescription: _HomeScreenConstants.downloadChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const platformDetails =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await FlutterLocalNotificationsPlugin().show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'Tải xuống hoàn tất',
      fileName,
      platformDetails,
      payload: filePath,
    );
  }

  Future<void> _showPermissionPermanentlyDeniedDialog(
      {String? permissionType}) async {
    String titleText = 'Quyền Bị Từ Chối Vĩnh Viễn';
    List<Widget> contentWidgets = [
      Text(
        'Ứng dụng cần một số quyền để hoạt động đầy đủ. Do bạn đã từ chối ${permissionType ?? 'một quyền'} và có thể đã chọn "không hỏi lại".',
      ),
      const SizedBox(height: 10),
      const Text(
        'Vui lòng vào cài đặt của ứng dụng để cấp quyền theo cách thủ công.',
      ),
    ];

    if (permissionType == "bộ nhớ/ảnh" ||
        permissionType == _getPermissionTypeString(Permission.storage) ||
        permissionType == _getPermissionTypeString(Permission.photos) ||
        permissionType == _getPermissionTypeString(Permission.videos) ||
        permissionType == _getPermissionTypeString(Permission.audio)) {
      contentWidgets.insert(
        0,
        const Text(
          'Cụ thể là quyền truy cập bộ nhớ/media để có thể tải, lưu trữ và chọn file.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      contentWidgets.insert(1, const SizedBox(height: 8));
    } else if (permissionType == "camera") {
      contentWidgets.insert(
        0,
        const Text(
          'Cụ thể là quyền sử dụng camera để bạn có thể chụp ảnh/quay video đính kèm.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      contentWidgets.insert(1, const SizedBox(height: 8));
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.orange[700]),
              const SizedBox(width: 10),
              Text(titleText),
            ],
          ),
          content:
              SingleChildScrollView(child: ListBody(children: contentWidgets)),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
              child: const Text('Hủy Bỏ'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Mở Cài Đặt'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }

  String _getPermissionTypeString(Permission permission) {
    if (permission == Permission.camera) return "camera";
    if (permission == Permission.photos) {
      return Platform.isIOS ? "ảnh và video" : "ảnh (Android 13+)";
    }
    if (permission == Permission.videos) return "video (Android 13+)";
    if (permission == Permission.audio) return "âm thanh (Android 13+)";
    if (permission == Permission.storage) return "bộ nhớ/tệp (Android cũ)";
    if (permission == Permission.notification) return "thông báo (Android 13+)";
    return permission.toString().split('.').last;
  }

  Future<void> _checkInitialConnectivity() async {
    final checker = InternetConnectionChecker.createInstance();
    bool isConnected = await checker.hasConnection;
    _updateConnectionStatus(isConnected, isInitialCheck: true);
  }

  void _updateConnectionStatus(bool isConnected,
      {bool isInitialCheck = false}) {
    if (_isConnected != isConnected) {
      _safeSetState(() {
        _isConnected = isConnected;
        if (!_isConnected) {
          _isError = true;
          _isLoadingPage = false;
          _errorType = 'network';
          _errorMessage = _HomeScreenConstants.noNetworkError;
        } else if (_isError &&
            (_errorMessage == _HomeScreenConstants.noNetworkError ||
                _errorMessage.contains("Mất kết nối mạng") ||
                _errorType == 'network')) {
          _isError = false;
          if (_currentUrl.isNotEmpty && _webViewController != null) {
            _retryLoading();
          }
        }
      });
    } else if (isInitialCheck && !_isConnected) {
      _safeSetState(() {
        _isError = true;
        _isLoadingPage = false;
        _errorType = 'network';
        _errorMessage = _HomeScreenConstants.noNetworkError;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _connectivitySubscription?.cancel();
    _loadingAnimationController.dispose();
    super.dispose();
  }

  String _extractFileNameFromDisposition(String? disposition, String fallback) {
    if (disposition == null) return fallback;

    String? fileName;

    // Try UTF-8 encoded format
    final starMatch =
        RegExp(r'filename\*=UTF-8\' '\'([^\;\r\n]+)', caseSensitive: false)
            .firstMatch(disposition);
    if (starMatch != null && starMatch.group(1) != null) {
      try {
        fileName = Uri.decodeComponent(starMatch.group(1)!);
      } catch (_) {}
    }

    // Try quoted format
    if (fileName == null) {
      final plainMatch = RegExp(r'filename="([^"]+)"', caseSensitive: false)
          .firstMatch(disposition);
      if (plainMatch != null && plainMatch.group(1) != null) {
        fileName = plainMatch.group(1);
      }
    }

    // Try unquoted format
    if (fileName == null) {
      final nonQuotedMatch = RegExp(r'filename=([^;]+)', caseSensitive: false)
          .firstMatch(disposition);
      if (nonQuotedMatch != null && nonQuotedMatch.group(1) != null) {
        fileName = nonQuotedMatch.group(1)!.trim().replaceAll('"', '');
      }
    }

    // Sanitize and validate filename
    fileName = fileName?.replaceAll(RegExp(r'[^\w\s\.\-]'), '_') ?? fallback;
    return fileName.isEmpty || fileName.split('').every((char) => char == '_')
        ? fallback
        : fileName;
  }

  Future<void> _downloadFile(String url, String suggestedFileName) async {
    print(
        '_downloadFile: Starting download for URL: $url, Suggested Filename: $suggestedFileName');

    try {
      // Show an initial notification that download is starting
      _showSnackBar(
        'Đang tải xuống: $suggestedFileName',
        icon: Icons.download_outlined,
      );

      final directory = Platform.isAndroid
          ? (await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory())
          : await getApplicationDocumentsDirectory();

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        String finalFileName = _extractFileNameFromDisposition(
          response.headers['content-disposition'],
          suggestedFileName,
        );

        final filePath = '${directory.path}/$finalFileName';
        await File(filePath).writeAsBytes(response.bodyBytes);

        _showSnackBar(
          'Đã tải xuống: $finalFileName',
          icon: Icons.check_circle_outline,
        );

        await _showDownloadNotification(finalFileName, filePath);
      } else {
        _showSnackBar(
          'Lỗi tải xuống: ${response.statusCode}. Không thể tải tệp.',
          icon: Icons.error_outline,
        );
      }
    } catch (e, s) {
      print('_downloadFile: Exception: $e\nStack: $s');
      _showSnackBar(
        _formatErrorMessage(e, url: url),
        icon: Icons.error_outline,
      );
    }
  }

  Future<bool> _showPermissionExplanationDialog({
    required String permissionFriendlyName,
    required String explanation,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text('Yêu cầu quyền truy cập $permissionFriendlyName'),
              content: SingleChildScrollView(child: Text(explanation)),
              actions: [
                TextButton(
                  child: const Text('Hủy bỏ'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                ElevatedButton(
                  child: const Text('Cấp quyền'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<PermissionStatus> _requestPermission(
    Permission permission,
    String friendlyName,
    String explanation,
  ) async {
    PermissionStatus status = await permission.status;

    if (status.isGranted || (Platform.isIOS && status.isLimited)) return status;

    if (status.isDenied || status.isRestricted) {
      bool shouldRequest = await _showPermissionExplanationDialog(
        permissionFriendlyName: friendlyName,
        explanation: explanation,
      );

      if (!shouldRequest) {
        _showSnackBar(
          'Đã hủy yêu cầu quyền $friendlyName.',
          icon: Icons.info_outline,
        );
        return PermissionStatus.denied;
      }

      status = await permission.request();
    }

    if (status.isPermanentlyDenied) {
      await _showPermissionPermanentlyDeniedDialog(
          permissionType: friendlyName);
    } else if (status.isDenied) {
      _showSnackBar(
        'Quyền $friendlyName bị từ chối. Một số chức năng có thể bị hạn chế.',
        icon: Icons.warning_amber_outlined,
      );
    }

    return status;
  }

  _FilePickerParamsParseResult _parseFileSelectorParams(
      FileSelectorParams params) {
    FileType fileTypeForPicker = FileType.any;
    List<String>? allowedExtensionsForPicker;

    if (params.acceptTypes.isNotEmpty && params.acceptTypes.first.isNotEmpty) {
      List<String> types = params.acceptTypes.first
          .split(',')
          .map((e) {
            String processedType = e.trim().toLowerCase();
            if (processedType.startsWith('.')) {
              return processedType.substring(1);
            }

            if (processedType.contains('/')) {
              var parts = processedType.split('/');
              if (parts.length > 1 && parts[1] != '*' && parts[1].isNotEmpty)
                return parts[1];
            }

            return processedType; // Keep original if it's like 'pdf' or 'jpeg' directly
          })
          .where((e) => e.isNotEmpty && !e.contains('*'))
          .toSet() // Use Set to remove duplicates easily
          .toList();

      if (params.acceptTypes
          .any((type) => type.toLowerCase().startsWith("image/"))) {
        fileTypeForPicker = FileType.image;
      } else if (params.acceptTypes
          .any((type) => type.toLowerCase().startsWith("video/"))) {
        fileTypeForPicker = FileType.video;
      } else if (params.acceptTypes
          .any((type) => type.toLowerCase().startsWith("audio/"))) {
        fileTypeForPicker = FileType.audio;
      } else if (types.isNotEmpty) {
        // Filter for valid extensions (alphanumeric, no slashes)
        List<String> validExtensions = types
            .where((t) =>
                RegExp(r'^[a-zA-Z0-9]+$').hasMatch(t) && !t.contains('/'))
            .toList();

        if (validExtensions.isNotEmpty) {
          fileTypeForPicker = FileType.custom;
          allowedExtensionsForPicker = validExtensions;
        }
      }
    }

    print(
        "Parsed File Picker Params: Type: $fileTypeForPicker, Extensions: $allowedExtensionsForPicker from accepts: ${params.acceptTypes}");
    return _FilePickerParamsParseResult(
        fileTypeForPicker, allowedExtensionsForPicker);
  }

  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    final choice = await showModalBottomSheet<ImageSource?>(
      context: context,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, size: 26),
              title: const Text('Chọn từ Thư viện/Tệp'),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              onTap: () =>
                  Navigator.pop(sheetContext, null), // Represents file picker
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, size: 26),
              title: const Text('Chụp ảnh mới'),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (choice == ImageSource.camera) {
      return await _pickFromCamera();
    }

    // If null (meaning "Chọn từ Thư viện/Tệp") or if camera not chosen/available.
    return await _pickFiles(params);
  }

  Future<List<String>> _pickFromCamera() async {
    PermissionStatus status = await _requestPermission(
      Permission.camera,
      "Camera",
      "Ứng dụng cần quyền Camera để chụp ảnh.",
    );

    if (!status.isGranted && !(Platform.isIOS && status.isLimited)) {
      // Check for limited access on iOS
      if (status.isPermanentlyDenied) {
        await _showPermissionPermanentlyDeniedDialog(permissionType: "camera");
      } else {
        _showSnackBar(
          'Quyền camera bị từ chối.',
          icon: Icons.camera_alt_outlined,
        );
      }
      return [];
    }

    try {
      final XFile? photo =
          await ImagePicker().pickImage(source: ImageSource.camera);
      return photo != null ? [photo.path] : [];
    } catch (e) {
      print("Error taking photo: $e");
      _showSnackBar(
        'Lỗi khi chụp ảnh: $e',
        icon: Icons.error_outline,
      );
      return [];
    }
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    final pickerParams = _parseFileSelectorParams(params);

    // Determine the most appropriate permission to request based on file type
    Permission permissionToRequest;
    String permissionFriendlyName;

    if (Platform.isAndroid) {
      if (pickerParams.fileType == FileType.image) {
        permissionToRequest = Permission.photos;
        permissionFriendlyName = _getPermissionTypeString(Permission.photos);
      } else if (pickerParams.fileType == FileType.video) {
        permissionToRequest = Permission.videos;
        permissionFriendlyName = _getPermissionTypeString(Permission.videos);
      } else if (pickerParams.fileType == FileType.audio) {
        permissionToRequest = Permission.audio;
        permissionFriendlyName = _getPermissionTypeString(Permission.audio);
      } else {
        // Fallback for FileType.any or FileType.custom
        permissionToRequest = Permission.storage;
        permissionFriendlyName = _getPermissionTypeString(Permission.storage);
      }
    } else if (Platform.isIOS) {
      // On iOS, Permission.photos covers images and videos from the library
      permissionToRequest = Permission.photos;
      permissionFriendlyName = _getPermissionTypeString(Permission.photos);
    } else {
      // Fallback for other platforms
      return [];
    }

    // Request the determined permission
    PermissionStatus status = await _requestPermission(
      permissionToRequest,
      permissionFriendlyName,
      "Ứng dụng cần quyền truy cập $permissionFriendlyName để chọn tệp.",
    );

    // On Android, if specific media permission is denied but we still need general storage access
    if (Platform.isAndroid &&
        permissionToRequest != Permission.storage &&
        !status.isGranted &&
        (pickerParams.fileType == FileType.any ||
            pickerParams.fileType == FileType.custom)) {
      PermissionStatus storageStatus = await _requestPermission(
        Permission.storage,
        _getPermissionTypeString(Permission.storage),
        "Ứng dụng cần quyền truy cập bộ nhớ để chọn một số loại tệp nhất định.",
      );

      if (!storageStatus.isGranted) {
        if (storageStatus.isPermanentlyDenied) {
          await _showPermissionPermanentlyDeniedDialog(
            permissionType: _getPermissionTypeString(Permission.storage),
          );
        } else {
          _showSnackBar(
            'Quyền truy cập bộ nhớ bị từ chối, chọn tệp có thể bị hạn chế.',
            icon: Icons.warning_amber_outlined,
          );
        }
      }
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: pickerParams.fileType,
        allowedExtensions: pickerParams.allowedExtensions,
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
        withData: false, // Don't load file data in memory
        withReadStream: false, // Don't use read stream
      );

      return result?.paths
              .where((path) => path != null)
              .map((path) => path!)
              .toList() ??
          [];
    } catch (e) {
      print("Error picking files: $e");
      _showSnackBar(
        'Lỗi khi chọn tệp: $e',
        icon: Icons.error_outline,
      );
      return [];
    }
  }

  void _loadUrl(String url, {bool isRetry = false}) {
    if (url.isEmpty) return;

    String effectiveUrl =
        url.startsWith('http://') || url.startsWith('https://')
            ? url
            : 'http://$url'; // Default to http if no scheme

    if (!isRetry || _currentUrl != effectiveUrl) {
      _currentUrl = effectiveUrl;
      _urlController.text = _currentUrl;
    }

    if (!_isConnected) {
      _safeSetState(() {
        _isLoadingPage = false;
        _isError = true;
        _errorType = 'network';
        _errorMessage = _HomeScreenConstants.noNetworkError;
      });
      return;
    }

    _safeSetState(() {
      _isLoadingPage = true;
      _isError = false;
      _loadingProgress = 0.0;
    });

    if (_webViewController == null) {
      print("WebViewController is null. Cannot load URL.");
      _safeSetState(() {
        _isLoadingPage = false;
        _isError = true;
        _errorType = 'generic';
        _errorMessage =
            "Lỗi khởi tạo trình duyệt. Vui lòng thử khởi động lại ứng dụng.";
      });
      return;
    }

    _webViewController!.loadRequest(Uri.parse(_currentUrl));
  }

  void _retryLoading() {
    if (!_isConnected) {
      _safeSetState(() {
        _isLoadingPage = false;
        _isError = true;
        _errorType = 'network';
        _errorMessage = "Vẫn mất kết nối mạng. Vui lòng kiểm tra đường truyền.";
      });
      _showSnackBar(
        "Không có kết nối mạng để tải lại.",
        icon: Icons.wifi_off,
      );
      return;
    }

    if (_currentUrl.isNotEmpty) {
      print("Retrying to load: $_currentUrl");
      _loadUrl(_currentUrl, isRetry: true);
    } else if (AppConfig.baseUrl.isNotEmpty) {
      // Use Config for home URL
      print("No current URL, retrying to load home: ${AppConfig.baseUrl}");
      _loadUrl(AppConfig.baseUrl, isRetry: true);
    } else {
      print("Cannot retry, no valid URL available.");
      _safeSetState(() {
        _isLoadingPage = false;
        _isError = true;
        _errorType = 'generic';
        _errorMessage = "Không có URL để tải lại. Vui lòng kiểm tra cấu hình.";
      });
    }
  }

  void _updateCurrentNavIndex(String url) {
    if (_menuItemUris.isEmpty) return; // Guard against empty list

    try {
      final currentUri = Uri.parse(url);

      for (int i = 0; i < _menuItemUris.length; i++) {
        final itemUri = _menuItemUris[i];
        if (itemUri == null) continue;

        // More robust matching: consider host and path prefix.
        // For exact matches or if itemUri path is a prefix of currentUri path.
        if (itemUri.host == currentUri.host &&
            itemUri.path == currentUri.path) {
          _safeSetState(() => _currentNavIndex = i);
          return;
        }

        // If the item URL is a base for the current URL (e.g. /Account and current is /Account/Details)
        if (itemUri.host == currentUri.host &&
            currentUri.path.startsWith(itemUri.path) &&
            itemUri.path != '/') {
          // Avoid matching base '/' for everything
          _safeSetState(() => _currentNavIndex = i);
          return;
        }
      }
    } catch (e) {
      print("Error parsing URL in _updateCurrentNavIndex: $e");
    }
  }

  void _onNavigate(String url, {bool requiresLogin = false}) {
    if (requiresLogin && !_isLoggedIn) {
      _onLoginRequired();
      return;
    }

    _safeSetState(() {
      _isError = false;
    });

    _loadUrl(url);
  }

  void _onLoginRequired() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          titlePadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0.0),
          contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 24.0),
          actionsPadding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
          icon: Icon(Icons.login_rounded,
              color: Theme.of(dialogContext).colorScheme.primary, size: 48.0),
          title: Center(
            child: Text('Yêu Cầu Đăng Nhập',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20.0,
                    color: Theme.of(dialogContext).colorScheme.onSurface)),
          ),
          content: Text(
              'Bạn cần đăng nhập để tiếp tục sử dụng tính năng này. Vui lòng đăng nhập.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16.0,
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant)),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 12.0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0))),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Hủy Bỏ',
                  style: TextStyle(
                      fontSize: 16.0,
                      color: Theme.of(dialogContext)
                          .colorScheme
                          .onSurfaceVariant)),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_pin_circle_outlined, size: 20),
              label: const Text('Đăng Nhập', style: TextStyle(fontSize: 16.0)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.primary,
                foregroundColor: Theme.of(dialogContext).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 12.0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0)),
                elevation: 2.0,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _safeSetState(() {
                  _isError = false;
                });
                _loadUrl(AppConfig.loginUrl); // Use Config for login URL
              },
            ),
          ],
        );
      },
    );
  }

  // Hiển thị loading skeleton thay vì CircularProgressIndicator đơn giản
  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            height: 56,
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 16),
          ),

          // Content
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 10,
              itemBuilder: (context, index) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Container(
                        height: 20,
                        width: double.infinity,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),

                      // Content
                      Container(
                        height: 16,
                        width: double.infinity,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 16,
                        width: MediaQuery.of(context).size.width * 0.8,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 16,
                        width: MediaQuery.of(context).size.width * 0.6,
                        color: Colors.white,
                      ),

                      if (index % 3 == 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          height: 200,
                          width: double.infinity,
                          color: Colors.white,
                        ),
                      ],

                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Hiển thị thông báo lỗi với hỗ trợ cụ thể hơn
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon tùy theo loại lỗi
            Icon(
              _errorType == 'network'
                  ? Icons.wifi_off_outlined
                  : _errorType == 'server'
                      ? Icons.cloud_off_outlined
                      : _errorType == 'timeout'
                          ? Icons.timer_off_outlined
                          : Icons.error_outline,
              color: _errorType == 'network'
                  ? Colors.orange[700]
                  : _errorType == 'server'
                      ? Colors.red[700]
                      : _errorType == 'timeout'
                          ? Colors.amber[700]
                          : Colors.red[700],
              size: 72,
              semanticLabel: 'Biểu tượng lỗi',
            ),
            const SizedBox(height: 24),

            // Tiêu đề lỗi
            Text(
              _errorType == 'network'
                  ? 'Lỗi kết nối mạng'
                  : _errorType == 'server'
                      ? 'Lỗi máy chủ'
                      : _errorType == 'timeout'
                          ? 'Thời gian yêu cầu đã hết'
                          : 'Lỗi không xác định',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Thông báo lỗi chi tiết
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _errorType == 'network'
                    ? Colors.orange[700]
                    : _errorType == 'server'
                        ? Colors.red[700]
                        : _errorType == 'timeout'
                            ? Colors.amber[700]
                            : Colors.red[700],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // Hiện thị các hành động khác nhau dựa trên loại lỗi
            if (_errorType == 'network') ...[
              // Lỗi mạng
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Thử Lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  minimumSize: const Size(180, 48),
                ),
                onPressed: _retryLoading,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Kiểm tra kết nối mạng'),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () {
                  // Mở trang cài đặt mạng
                  if (Platform.isAndroid) {
                    // Intent để mở cài đặt wifi
                    // Đây chỉ là hướng dẫn, không thực hiện được trực tiếp
                    _showSnackBar(
                      'Vui lòng mở cài đặt Wi-Fi hoặc Dữ liệu di động để kiểm tra kết nối mạng.',
                      icon: Icons.info_outline,
                    );
                  } else if (Platform.isIOS) {
                    _showSnackBar(
                      'Vui lòng mở cài đặt Wi-Fi hoặc Dữ liệu di động để kiểm tra kết nối mạng.',
                      icon: Icons.info_outline,
                    );
                  }
                },
              ),
            ] else if (_errorType == 'server') ...[
              // Lỗi máy chủ
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Thử Lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  minimumSize: const Size(180, 48),
                ),
                onPressed: _retryLoading,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.home_outlined),
                label: const Text('Về Trang Chủ'),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () => _loadUrl(AppConfig.homeUrl),
              ),
            ] else ...[
              // Lỗi khác
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Thử Lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  minimumSize: const Size(180, 48),
                ),
                onPressed: _retryLoading,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.home_outlined),
                label: const Text('Về Trang Chủ'),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () => _loadUrl(AppConfig.homeUrl),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        onNavigate: _onNavigate,
        isLoggedIn: _isLoggedIn,
        onLoginRequired: _onLoginRequired,
        currentUrl: _currentUrl,
      ),
      body: Column(
        children: [
          // **[EXISTING]** AnimatedSize for AppBar
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showBars
                ? AppBar(
                    backgroundColor: Color(0xfffbfbfb),
                    toolbarHeight: 42,
                    shadowColor: Colors.black,
                    title: const Text(''),
                    flexibleSpace: Stack(
                      children: [
                        Center(
                          child: Column(
                            children: [
                              SizedBox(height: 24),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 0),
                                child: Ink.image(
                                  height: 36,
                                  fit: BoxFit.contain,
                                  image: const AssetImage('assets/logoDVC.png'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Tải lại trang',
                        onPressed:
                            (_isLoadingPage || (!_isConnected && _isError))
                                ? null
                                : () {
                                    // **[MODIFIED]** Handle refresh for both WebView and custom screens
                                    if (_isShowingCustomScreen) {
                                      // For custom screens, just rebuild the current screen
                                      if (_currentNavIndex == 1) {
                                        _onBottomNavTap(
                                            1); // Refresh ProceduresScreen
                                      }
                                    } else {
                                      _retryLoading();
                                    }
                                  },
                      ),
                      const SizedBox(width: 8),
                    ],
                    elevation: 1.5,
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // **[MODIFIED]** Show custom screen or WebView based on state
                if (_isShowingCustomScreen && _currentScreen != null)
                  _currentScreen!
                else if (_webViewController != null && !_isError)
                  WebViewWidget(controller: _webViewController!),

                // **[EXISTING]** Loading indicator (only for WebView)
                if (_isLoadingPage && !_isShowingCustomScreen)
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text("Đang tải ...", style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),

                // **[EXISTING]** Error screen (only for WebView)
                if (_isError && !_isLoadingPage && !_isShowingCustomScreen)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red[700], size: 60),
                          const SizedBox(height: 20),
                          Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.red[700],
                                fontSize: 17,
                                fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 25),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử Lại'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12)),
                            onPressed: _retryLoading,
                          ),
                        ],
                      ),
                    ),
                  ),

                // **[EXISTING]** WebView controller initialization
                if (_webViewController == null &&
                    !_isLoadingPage &&
                    !_isError &&
                    _isConnected &&
                    !_isShowingCustomScreen)
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor: AlwaysStoppedAnimation(Colors.grey)),
                        SizedBox(height: 20),
                        Text("Đang khởi tạo...",
                            style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: AnimatedSize(
        duration: _HomeScreenConstants.animationDuration,
        curve: Curves.easeInOut,
        child: _showBars
            ? AppBottomNavBar(
                currentIndex: _currentNavIndex,
                onTap: _onBottomNavTap,
                isLoggedIn: _isLoggedIn,
                onLoginRequired: _onLoginRequired,
              )
            : const SizedBox(width: double.infinity, height: 0),
      ),
    );
  }
}
