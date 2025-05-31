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
  // static const String loginUrl = 'http://113.160.48.99:8791/Account/Login'; // Replaced by Config.login_URL
  static const String downloadChannelId = 'download_channel_id';
  static const String downloadChannelName = 'Downloads';
  static const String downloadChannelDescription =
      'Channel for download notifications';
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  WebViewController? _webViewController;

  bool _isLoadingPage = true;
  bool _isError = false;
  String _errorMessage = 'Đã xảy ra lỗi. Vui lòng thử lại.';
  String _currentUrl = '';
  bool _isLoggedIn = false;
  int _currentNavIndex = 0;
  bool _isConnected = true;
  StreamSubscription<InternetConnectionStatus>? _connectivitySubscription;

  // **[MODIFIED]** State variable to control AppBar and BottomNavBar visibility
  bool _showBars = true;

  final List<String> _externalDomains = [
    'sso.dancuquocgia.gov.vn',
    'xacthuc.dichvucong.gov.vn',
  ];

  // Initialize _menuItemUris from Config.bottomNavItems
  late final List<Uri?> _menuItemUris;

  /// Safely updates state if the widget is mounted.
  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  /// Shows a SnackBar if the widget is mounted.
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  /// Formats error messages for user-friendly display.
  String _formatErrorMessage(dynamic error, {String? url}) {
    if (error is SocketException) {
      return _HomeScreenConstants.noNetworkError;
    } else if (error is HttpException) {
      return "Lỗi máy chủ: ${error.message}";
    } else {
      return "Lỗi: ${error.toString()}${url != null ? ' khi truy cập $url' : ''}";
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
    _currentUrl = AppConfig.baseUrl; // Use Config for home URL
    _urlController.text = _currentUrl;

    // Initialize _menuItemUris from Config
    _menuItemUris = MenuData.bottomNavItems.map((item) {
      try {
        return Uri.parse(item.url);
      } catch (_) {
        return null;
      }
    }).toList();

    // Initialize WebViewController
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // **[ADDED]** JavaScriptChannel to listen for messages from the webview
      ..addJavaScriptChannel(
        'Chrome',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'hideBars' && _showBars) {
            _safeSetState(() {
              _showBars = false;
            });
          } else if (message.message == 'showBars' && !_showBars) {
            _safeSetState(() {
              _showBars = true;
            });
          }
        },
      )
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String navUrl) {
            print('WebView Delegate: Page started loading: $navUrl');
            _safeSetState(() {
              _isLoadingPage = true;
              _isError = false;
            });
          },
          onPageFinished: (String finishedUrl) async {
            print('WebView Delegate: Page finished loading: $finishedUrl');

            // **[MODIFIED]** Reset bars to be visible on every new page load
            if (!_showBars) {
              _safeSetState(() => _showBars = true);
            }

            bool isExternal = _isExternalUrl(finishedUrl);
            if (!isExternal) {
              try {
                // **[MODIFIED]** Added JavaScript to handle scroll events for showing/hiding bars
                await _webViewController?.runJavaScript('''
                  try {
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
                    
                    // Logic to show/hide native bars on scroll
                    let lastScrollTop = window.pageYOffset || document.documentElement.scrollTop;
                    window.addEventListener('scroll', function() {
                        let scrollTop = window.pageYOffset || document.documentElement.scrollTop;
                        if (scrollTop > lastScrollTop && scrollTop > 80) { // Scrolling down past a threshold
                            window.Chrome.postMessage('hideBars');
                        } else if (scrollTop < lastScrollTop) { // Scrolling up
                            window.Chrome.postMessage('showBars');
                        }
                        lastScrollTop = scrollTop <= 0 ? 0 : scrollTop;
                    }, false);

                  } catch (e) {
                    console.error('Error in onPageFinished JS: ' + e.toString());
                  }
                ''');
                // Simplified login check, actual login state might need more robust handling
                // For example, checking cookies or specific elements if possible and reliable
                if (finishedUrl
                        .toLowerCase()
                        .contains(AppConfig.loginUrl.toLowerCase()) ||
                    finishedUrl.toLowerCase().startsWith(
                        AppConfig.authenticationUrl.toLowerCase())) {
                  _safeSetState(() => _isLoggedIn = false);
                } else if (finishedUrl
                        .toLowerCase()
                        .startsWith(AppConfig.baseUrl.toLowerCase()) &&
                    !finishedUrl.toLowerCase().contains("returnurl")) {
                  // A more robust check might be needed here
                  // This is a heuristic: if on home and not a redirect from login, assume logged in
                  // Or, your web app could expose a JS variable like `window.isUserLoggedIn`
                  _safeSetState(() => _isLoggedIn = true);
                }
              } catch (e) {
                print("Error during onPageFinished JS execution: $e");
                // Potentially set _isLoggedIn to false or handle based on error
              }
            }
            _safeSetState(() {
              _isLoadingPage = false;
            });
            _updateCurrentNavIndex(finishedUrl);
          },
          onWebResourceError: (WebResourceError error) {
            print(
                'WebView Delegate: WebResourceError: ${error.description}, URL: ${error.url}, Code: ${error.errorCode}, Type: ${error.errorType}, MainFrame: ${error.isForMainFrame}');
            if (error.isForMainFrame == false &&
                error.url != null &&
                _isExternalUrl(error.url!)) {
              print(
                  'Ignoring non-main frame error on external domain: ${error.url}');
              return;
            }
            if (error.isForMainFrame == true || error.url == _currentUrl) {
              _safeSetState(() {
                _isLoadingPage = false;
                _isError = true;
                _errorMessage = !_isConnected
                    ? _HomeScreenConstants.noNetworkError
                    : (error.errorCode == -2 ||
                            error.errorType ==
                                WebResourceErrorType.hostLookup ||
                            error.errorType == WebResourceErrorType.connect ||
                            error.errorType == WebResourceErrorType.timeout)
                        ? "Không thể kết nối tới máy chủ hoặc không có kết nối mạng. ${error.description}"
                        : "Lỗi tải trang: ${error.description} (Mã: ${error.errorCode})";
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) async {
            print('WebView Delegate: Navigating to: ${request.url}');
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
            final lowercasedUrl = request.url.toLowerCase();
            bool hasFileExtension =
                fileExtensions.any((ext) => lowercasedUrl.endsWith(ext));
            bool isApiDownloadLink =
                request.url.contains('/api/QuanLyHDSDApi/Download/');

            if (hasFileExtension || isApiDownloadLink) {
              String suggestedFileName;
              List<String> pathSegments = Uri.parse(request.url).pathSegments;
              if (isApiDownloadLink) {
                int downloadKeywordIndex = pathSegments
                    .indexWhere((s) => s.toLowerCase() == 'download');
                suggestedFileName = downloadKeywordIndex != -1 &&
                        downloadKeywordIndex + 1 < pathSegments.length &&
                        pathSegments[downloadKeywordIndex + 1].isNotEmpty
                    ? pathSegments[downloadKeywordIndex + 1]
                    : pathSegments.isNotEmpty
                        ? pathSegments.last
                        : 'downloaded_item';
              } else {
                suggestedFileName = pathSegments.isNotEmpty
                    ? pathSegments.last
                    : 'downloaded_file';
              }
              if (suggestedFileName.isEmpty ||
                  Uri.tryParse(suggestedFileName)?.hasAuthority == true) {
                suggestedFileName =
                    'downloaded_file_generic_${DateTime.now().millisecondsSinceEpoch}';
              }
              print(
                  'Intercepting download for ${request.url}. Suggested filename: $suggestedFileName.');
              await _downloadFile(request.url, suggestedFileName);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) {
            if (change.url != null) {
              print('WebView Delegate: URL changed to: ${change.url}');
              _urlController.text = change.url!;
              _updateCurrentNavIndex(change.url!);

              // Update login status based on URL (example)
              if (change.url!
                      .toLowerCase()
                      .startsWith(AppConfig.baseUrl.toLowerCase()) &&
                  !change.url!.toLowerCase().contains(
                      "returnurl") && // Assuming "returnurl" means it's part of login redirect
                  !change.url!
                      .toLowerCase()
                      .startsWith(AppConfig.loginUrl.toLowerCase())) {
                _safeSetState(() => _isLoggedIn = true);
              } else if (change.url!
                  .toLowerCase()
                  .startsWith(AppConfig.loginUrl.toLowerCase())) {
                _safeSetState(() => _isLoggedIn = false);
              }
            }
          },
        ),
      );

    if (Platform.isAndroid) {
      final androidController =
          _webViewController!.platform as AndroidWebViewController;
      try {
        androidController.setOnShowFileSelector(_androidFilePicker);
        print("setOnShowFileSelector đã được thiết lập cho Android.");
      } catch (e) {
        _showSnackBar('Không thể khởi tạo trình chọn file: $e');
      }
    }

    _initializeNotifications();
    _checkInitialConnectivity();
    final checker = InternetConnectionChecker.createInstance();
    _connectivitySubscription = checker.onStatusChange.listen(
      (status) =>
          _updateConnectionStatus(status == InternetConnectionStatus.connected),
    );
    // _requestPermissions();
    _loadUrl(_currentUrl);
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
    await flutterLocalNotificationsPlugin.initialize(
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
    await flutterLocalNotificationsPlugin.show(
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
          'Ứng dụng cần một số quyền để hoạt động đầy đủ. Do bạn đã từ chối ${permissionType ?? 'một quyền'} và có thể đã chọn "không hỏi lại".'),
      const SizedBox(height: 10),
      const Text(
          'Vui lòng vào cài đặt của ứng dụng để cấp quyền theo cách thủ công.'),
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
              style: TextStyle(fontWeight: FontWeight.bold)));
      contentWidgets.insert(1, const SizedBox(height: 8));
    } else if (permissionType == "camera") {
      contentWidgets.insert(
          0,
          const Text(
              'Cụ thể là quyền sử dụng camera để bạn có thể chụp ảnh/quay video đính kèm.',
              style: TextStyle(fontWeight: FontWeight.bold)));
      contentWidgets.insert(1, const SizedBox(height: 8));
    }

    await showDialog<void>(
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
                    borderRadius: BorderRadius.circular(8.0)),
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

  // Future<void> _requestPermissions() async {
  //   print("HomeScreen: Bắt đầu yêu cầu các quyền ban đầu...");
  //   final permissions = Platform.isAndroid
  //       ? [Permission.storage, Permission.camera, Permission.notification]
  //       : [Permission.camera, Permission.photos]; // Added Photos for iOS

  //   for (var permission in permissions) {
  //     String friendlyName = _getPermissionTypeString(permission);
  //     await _requestPermission(
  //       permission,
  //       friendlyName,
  //       'Ứng dụng cần quyền truy cập $friendlyName để hoạt động đầy đủ.',
  //     );
  //   }
  // }

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
          _errorMessage = _HomeScreenConstants.noNetworkError;
        } else if (_isError &&
            (_errorMessage == _HomeScreenConstants.noNetworkError ||
                _errorMessage.contains("Mất kết nối mạng"))) {
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
        _errorMessage = _HomeScreenConstants.noNetworkError;
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  String _extractFileNameFromDisposition(String? disposition, String fallback) {
    if (disposition == null) return fallback;

    String? fileName;
    final starMatch =
        RegExp(r'filename\*=UTF-8\' '\'([^\;\r\n]+)', caseSensitive: false)
            .firstMatch(disposition);
    if (starMatch != null && starMatch.group(1) != null) {
      try {
        fileName = Uri.decodeComponent(starMatch.group(1)!);
      } catch (_) {}
    }
    if (fileName == null) {
      final plainMatch = RegExp(r'filename="([^"]+)"', caseSensitive: false)
          .firstMatch(disposition);
      if (plainMatch != null && plainMatch.group(1) != null) {
        fileName = plainMatch.group(1);
      }
    }
    if (fileName == null) {
      final nonQuotedMatch = RegExp(r'filename=([^;]+)', caseSensitive: false)
          .firstMatch(disposition);
      if (nonQuotedMatch != null && nonQuotedMatch.group(1) != null) {
        fileName = nonQuotedMatch.group(1)!.trim().replaceAll('"', '');
      }
    }
    fileName = fileName?.replaceAll(RegExp(r'[^\w\s\.\-]'), '_') ?? fallback;
    return fileName.isEmpty || fileName.split('').every((char) => char == '_')
        ? fallback
        : fileName;
  }

  Future<void> _downloadFile(String url, String suggestedFileName) async {
    print(
        '_downloadFile: Starting download for URL: $url, Suggested Filename: $suggestedFileName');
    try {
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
        _showSnackBar('Đã tải xuống: $finalFileName');
        await _showDownloadNotification(finalFileName, filePath);
      } else {
        _showSnackBar(
            'Lỗi tải xuống: ${response.statusCode}. Không thể tải tệp.');
      }
    } catch (e, s) {
      print('_downloadFile: Exception: $e\nStack: $s');
      _showSnackBar(_formatErrorMessage(e, url: url));
    }
  }

// Dán đoạn code đã được sửa đổi này vào file lib/home_screen.dart,
// thay thế cho hàm _showPermissionExplanationDialog hiện có.

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
                // **[MODIFIED]** Thay đổi Text và hành động của nút
                TextButton(
                  child: const Text('Mở Cài đặt'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false); // Đóng hộp thoại
                    openAppSettings(); // Mở màn hình cài đặt của ứng dụng
                  },
                ),
              ],
            );
          },
        ) ??
        true;
  }

  Future<PermissionStatus> _requestPermission(
    Permission permission,
    String friendlyName,
    String explanation,
  ) async {
    PermissionStatus status = await permission.status;
    if (status.isGranted || (Platform.isIOS && status.isLimited)) return status;

    if (status.isDenied || status.isRestricted) {
      // Handle .isRestricted as well
      bool shouldRequest = await _showPermissionExplanationDialog(
        permissionFriendlyName: friendlyName,
        explanation: explanation,
      );
      if (!shouldRequest) {
        _showSnackBar('Đã hủy yêu cầu quyền $friendlyName.');
        return PermissionStatus
            .denied; // Or status, depending on desired behavior
      }
      status = await permission.request();
    }

    if (status.isPermanentlyDenied) {
      await _showPermissionPermanentlyDeniedDialog(
          permissionType: friendlyName);
    } else if (status.isDenied) {
      _showSnackBar(
          'Quyền $friendlyName bị từ chối. Một số chức năng có thể bị hạn chế.');
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
              leading: const Icon(Icons.photo_library),
              title: const Text('Chọn từ Thư viện/Tệp'),
              onTap: () =>
                  Navigator.pop(sheetContext, null), // Represents file picker
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Chụp ảnh mới'),
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
        _showSnackBar('Quyền camera bị từ chối.');
      }
      return [];
    }
    try {
      final XFile? photo =
          await ImagePicker().pickImage(source: ImageSource.camera);
      return photo != null ? [photo.path] : [];
    } catch (e) {
      print("Error taking photo: $e");
      _showSnackBar('Lỗi khi chụp ảnh: $e');
      return [];
    }
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    final pickerParams = _parseFileSelectorParams(params);

    // Determine the most appropriate permission to request
    Permission permissionToRequest;
    String permissionFriendlyName;

    if (Platform.isAndroid) {
      // Fallback for FileType.any, FileType.custom, or if specific types aren't granularly handled
      permissionToRequest = Permission
          .storage; // Or manageReadExternalStorage for broader access if necessary
    } else if (Platform.isIOS) {
      // On iOS, Permission.photos covers images and videos from the library.
      // For general files, no specific permission is typically needed for the picker itself,
      // but your app might need Files app access entitlement.
      permissionToRequest = Permission.photos; // Primary permission for media
    } else {
      // Fallback for other platforms if any (though webview_flutter_android implies Android focus)
      return []; // Or handle appropriately
    }

    // If Android and still need general storage for FileType.any or custom after specific media checks
    if (Platform.isAndroid &&
        permissionToRequest != Permission.storage &&
        (pickerParams.fileType == FileType.any ||
            pickerParams.fileType == FileType.custom &&
                (pickerParams.allowedExtensions?.isNotEmpty ?? false))) {
      PermissionStatus storageStatus = await _requestPermission(
        Permission.storage,
        _getPermissionTypeString(Permission.storage),
        "Ứng dụng cần quyền truy cập bộ nhớ để chọn một số loại tệp nhất định.",
      );
      if (!storageStatus.isGranted) {
        if (storageStatus.isPermanentlyDenied) {
          await _showPermissionPermanentlyDeniedDialog(
              permissionType: _getPermissionTypeString(Permission.storage));
        } else {
          _showSnackBar(
              'Quyền truy cập bộ nhớ bị từ chối, chọn tệp có thể bị hạn chế.');
        }
        // Decide if to proceed or return [] based on whether storage is critical
      }
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: pickerParams.fileType,
        allowedExtensions: pickerParams.allowedExtensions,
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
      );
      return result?.paths
              .where((path) => path != null)
              .map((path) => path!)
              .toList() ??
          [];
    } catch (e) {
      print("Error picking files: $e");
      _showSnackBar('Lỗi khi chọn tệp: $e');
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
        _errorMessage = _HomeScreenConstants.noNetworkError;
      });
      return;
    }

    _safeSetState(() {
      _isLoadingPage = true;
      _isError = false;
    });

    if (_webViewController == null) {
      print("WebViewController is null. Cannot load URL.");
      _safeSetState(() {
        _isLoadingPage = false;
        _isError = true;
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
        _errorMessage = "Vẫn mất kết nối mạng. Vui lòng kiểm tra đường truyền.";
      });
      _showSnackBar("Không có kết nối mạng để tải lại.");
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
      // If no exact match, try to find the closest one or default to an unselected state if necessary
      // For now, if no match, the index remains, or you could set it to a "none selected" value e.g. -1
      // if current logic is to highlight only exact matches.
      // To be safe, if no item matches, we might want to clear the selection or select home
      // For now, we'll leave it as is, _currentNavIndex will retain its last value if no new match.
    } catch (e) {
      print("Error parsing URL in _updateCurrentNavIndex: $e");
    }
  }

  void _onBottomNavTap(int index) {
    if (index < 0 || index >= MenuData.bottomNavItems.length) return;

    final selectedItem = MenuData.bottomNavItems[index];

    if (selectedItem.requiresLogin && !_isLoggedIn) {
      _onLoginRequired();
      return;
    }

    // Avoid reloading if already on the same page from bottom nav
    // Note: _currentNavIndex might not be perfectly in sync if page changed via other means
    // and _updateCurrentNavIndex didn't find a match.
    // A more robust check is if _currentUrl matches selectedItem.url
    if (_currentUrl == selectedItem.url &&
        _currentNavIndex == index &&
        !_isLoadingPage &&
        !_isError) {
      print("Already on selected tab: ${selectedItem.title}");
      return;
    }

    _safeSetState(() {
      _isError = false;
      // _currentNavIndex = index; // Set immediately for responsiveness, or after load via _updateCurrentNavIndex
    });
    _loadUrl(selectedItem.url);
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

  @override
  Widget build(BuildContext context) {
    // **[MODIFIED]** Using AnimatedSize for smoother transitions
    return Scaffold(
      appBar: _showBars
          ? AppBar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              title: const Text('Dịch vụ công Thành ủy Hà Nội',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
              centerTitle: true,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  tooltip: 'Mở menu',
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Tải lại trang',
                  onPressed: (_isLoadingPage || (!_isConnected && _isError))
                      ? null
                      : _retryLoading,
                ),
                const SizedBox(width: 8),
              ],
              elevation: 1.5,
            )
          : null,
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
                if (_webViewController != null && !_isError)
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
                if (_webViewController == null &&
                    !_isLoadingPage &&
                    !_isError &&
                    _isConnected)
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                            strokeWidth: 2.0,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.grey)),
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
      bottomNavigationBar: _showBars
          ? AppBottomNavBar(
              currentIndex: _currentNavIndex,
              onTap: _onBottomNavTap,
              isLoggedIn: _isLoggedIn,
              onLoginRequired: _onLoginRequired,
            )
          : null,
    );
  }
}
