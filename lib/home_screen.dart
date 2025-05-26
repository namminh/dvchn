import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
// Import the local notifications plugin
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'js_bridge_util.dart';
import 'menu_widgets.dart';

// Initialize the plugin instance - often done globally or in main.dart
// For this example, we'll manage it within the HomeScreen's state for simplicity,
// though for a real app, initialize it once.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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
  ];

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
    _currentUrl = MenuConfig.homeUrl;
    _urlController.text = _currentUrl;

    _initializeNotifications(); // Initialize notifications

    _checkInitialConnectivity();
    final checker = InternetConnectionChecker.createInstance();
    _connectivitySubscription = checker.onStatusChange.listen(
      (status) {
        _updateConnectionStatus(status == InternetConnectionStatus.connected);
      },
    );

    _requestPermissions();
    _loadUrl(_currentUrl);
  }

  // Method to initialize notifications
  Future<void> _initializeNotifications() async {
    // Initialization settings for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
            '@mipmap/ic_launcher'); // Ensure you have ic_launcher.png in android/app/src/main/res/mipmap-xxxx folders

    // Initialization settings for iOS
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      // onDidReceiveLocalNotification: onDidReceiveLocalNotification, // Optional: handle when app is in foreground
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      // onDidReceiveNotificationResponse: onDidReceiveNotificationResponse, // Optional: handle notification tap
    );
  }

  // Method to show a download notification
  Future<void> _showDownloadNotification(
      String fileName, String filePath) async {
    // Android notification details
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'download_channel_id', // Channel ID
      'Downloads', // Channel name
      channelDescription:
          'Channel for download notifications', // Channel description
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
      // You can add an icon here, e.g., an Android-specific icon
      // icon: 'download_icon', // ensure this icon exists in drawable resources
    );

    // iOS notification details
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert:
          true, // Present an alert when the notification is displayed and the application is in the foreground (only from iOS 10 onwards)
      presentBadge:
          true, // Present the badge number when the notification is displayed and the application is in the foreground (only from iOS 10 onwards)
      presentSound:
          true, // Play a sound when the notification is displayed and the application is in the foreground (only from iOS 10 onwards)
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      'Tải xuống hoàn tất', // Notification title
      fileName, // Notification body (file name)
      platformChannelSpecifics,
      payload: filePath, // Optional: pass the file path to handle tap
    );
  }

  Future<void> _showPermissionPermanentlyDeniedDialog() async {
    if (!mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.orange),
              SizedBox(width: 10),
              Text('Quyền Bị Từ Chối'),
            ],
          ),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    'Ứng dụng cần quyền truy cập bộ nhớ để có thể tải và lưu trữ file.'),
                SizedBox(height: 10),
                Text(
                    'Do bạn đã từ chối quyền này trước đó và có thể đã chọn "không hỏi lại", vui lòng vào cài đặt của ứng dụng để cấp quyền theo cách thủ công.'),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
              ),
              child: const Text('Hủy Bỏ'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
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

  Future<bool> hasStoragePermissions() async {
    final permission = await Permission.storage.status;
    return permission == PermissionStatus.granted;
  }

  Future<void> _requestPermissions() async {
    print("HomeScreen: Requesting initial permissions...");
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
        // If you also need to show notifications on Android 13+
        Permission.notification, // Request notification permission
      ].request();

      statuses.forEach((permission, status) {
        print(
            "HomeScreen: Permission: ${permission.toString()} Status: ${status.toString()}");
      });

      PermissionStatus? storageStatus = statuses[Permission.storage];
      if (storageStatus == PermissionStatus.permanentlyDenied) {
        print(
            "HomeScreen: Storage (or related media) permission is permanently denied.");
        await _showPermissionPermanentlyDeniedDialog();
      } else if (storageStatus == PermissionStatus.denied) {
        print(
            "HomeScreen: Storage (or related media) permission was denied (not permanently).");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Quyền truy cập bộ nhớ/media bị từ chối. Chức năng tải lên file có thể không hoạt động.')),
          );
        }
      } else if (storageStatus == PermissionStatus.granted) {
        print("HomeScreen: Storage (or relevant media) permission granted.");
      }

      // Handle notification permission
      PermissionStatus? notificationStatus = statuses[Permission.notification];
      if (notificationStatus == PermissionStatus.denied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quyền hiển thị thông báo bị từ chối.')),
        );
      } else if (notificationStatus == PermissionStatus.permanentlyDenied &&
          mounted) {
        // Optionally, guide user to settings for notifications
        print("HomeScreen: Notification permission permanently denied.");
      }
    } else if (Platform.isIOS) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.photos
      ].request(); // Notification permission is usually handled by the plugin on first notification display or during init for iOS
      statuses.forEach((permission, status) {
        print(
            "HomeScreen: Permission: ${permission.toString()} Status: ${status.toString()}");
      });
      if (statuses[Permission.photos] == PermissionStatus.permanentlyDenied) {
        await _showPermissionPermanentlyDeniedDialog();
      } else if (statuses[Permission.photos] == PermissionStatus.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Quyền truy cập thư viện ảnh bị từ chối.')),
          );
        }
      }
    }
  }

  Future<void> _checkInitialConnectivity() async {
    final checker = InternetConnectionChecker.createInstance();
    bool isConnected = await checker.hasConnection;
    _updateConnectionStatus(isConnected, isInitialCheck: true);
  }

  void _updateConnectionStatus(bool isConnected,
      {bool isInitialCheck = false}) {
    if (!mounted) return;

    if (_isConnected != isConnected) {
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
    super.dispose();
  }

  void _setupJavaScriptChannels() {
    if (_webViewController != null) {
      _jsBridgeUtil = JsBridgeUtil(
        _webViewController!,
        onFileUploadRequested: _openFilePicker,
      );
      _jsBridgeUtil!.setupJavaScriptHandlers();
    }
  }

  Future<void> _downloadFile(String url, String suggestedFileName) async {
    print(
        '_downloadFile: Starting download for URL: $url, Suggested Filename: $suggestedFileName');

    try {
      print('_downloadFile: Requesting storage permission before download...');

      PermissionStatus storageStatus =
          await Permission.manageExternalStorage.request();
      print(
          '_downloadFile: Storage permission status before download: $storageStatus');

      if (storageStatus.isGranted) {
        print('_downloadFile: Storage permission granted for download.');
        final directory = await getExternalStorageDirectory();

        if (directory == null) {
          print('_downloadFile: ERROR - Could not get storage directory.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không thể truy cập bộ nhớ ngoài.')),
            );
          }
          return;
        }
        print('_downloadFile: Storage directory: ${directory.path}');

        print('_downloadFile: Making HTTP GET request to $url');
        final response = await http.get(Uri.parse(url));
        print(
            '_downloadFile: HTTP response status code: ${response.statusCode}');

        if (response.statusCode == 200) {
          String finalFileName = suggestedFileName;
          final disposition = response.headers['content-disposition'];
          if (disposition != null) {
            String? extractedName;
            final starMatch = RegExp(r'filename\*=UTF-8\' '\'([^\;\r\n]+)',
                    caseSensitive: false)
                .firstMatch(disposition);
            if (starMatch != null && starMatch.group(1) != null) {
              try {
                extractedName = Uri.decodeComponent(starMatch.group(1)!);
              } catch (e) {/* ... */}
            }
            if (extractedName == null || extractedName.isEmpty) {
              final plainMatch =
                  RegExp(r'filename="([^"]+)"', caseSensitive: false)
                      .firstMatch(disposition);
              if (plainMatch != null && plainMatch.group(1) != null) {
                extractedName = plainMatch.group(1);
              }
            }
            if (extractedName == null || extractedName.isEmpty) {
              final nonQuotedMatch =
                  RegExp(r'filename=([^;]+)', caseSensitive: false)
                      .firstMatch(disposition);
              if (nonQuotedMatch != null && nonQuotedMatch.group(1) != null) {
                extractedName = nonQuotedMatch.group(1)!.trim();
                if (extractedName.startsWith('"') &&
                    extractedName.endsWith('"') &&
                    extractedName.length > 1) {
                  extractedName =
                      extractedName.substring(1, extractedName.length - 1);
                }
              }
            }
            if (extractedName != null && extractedName.isNotEmpty) {
              finalFileName = extractedName;
            }
          }
          finalFileName = finalFileName.replaceAll(RegExp(r'[^\w\s\.\-]'), '_');
          if (finalFileName.isEmpty ||
              finalFileName.split('').every((char) => char == '_')) {
            finalFileName = "downloaded_unnamed_file";
          }

          final filePath = '${directory.path}/$finalFileName';
          print('_downloadFile: Attempting to write file to: $filePath');
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          print('_downloadFile: File written successfully to $filePath');

          if (mounted) {
            // Keep the SnackBar for in-app feedback and "Open" action
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã tải xuống: $finalFileName'),
                action: SnackBarAction(
                    label: 'Mở', onPressed: () => OpenFile.open(filePath)),
              ),
            );
            // Show system notification
            _showDownloadNotification(finalFileName, filePath); // MODIFIED HERE
          }
        } else {
          print(
              '_downloadFile: ERROR - HTTP request failed. Status: ${response.statusCode}.');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Không thể tải file: Server phản hồi ${response.statusCode}')),
            );
          }
        }
      } else if (storageStatus.isPermanentlyDenied) {
        print(
            '_downloadFile: ERROR - Storage permission permanently denied when attempting download.');
        await _showPermissionPermanentlyDeniedDialog();
      } else {
        print(
            '_downloadFile: ERROR - Storage permission not granted for download. Status: $storageStatus');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Cần quyền bộ nhớ để tải file. Trạng thái: $storageStatus')),
          );
        }
      }
    } catch (e, s) {
      print('Lỗi tải xuống file (Exception): $e');
      print('Stack trace: $s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải xuống file: $e')),
        );
      }
    }
  }

  Future<void> _openFilePicker() async {
    print('_openFilePicker: Received request to open file picker.');
    try {
      bool permissionsGranted = false;
      if (Platform.isAndroid) {
        PermissionStatus storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          print(
              '_openFilePicker: Storage permission was ${storageStatus.name}. Requesting again...');
          storageStatus = await Permission.storage.request();
        }
        if (storageStatus.isGranted) {
          permissionsGranted = true;
        } else {
          print(
              '_openFilePicker: Storage permission denied after explicit request. Status: ${storageStatus.name}');
          if (storageStatus.isPermanentlyDenied && mounted) {
            await _showPermissionPermanentlyDeniedDialog();
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('Không có quyền truy cập bộ nhớ để chọn file.')),
            );
          }
        }
      } else if (Platform.isIOS) {
        permissionsGranted = true;
      } else {
        permissionsGranted = true;
      }

      if (!permissionsGranted) {
        print('_openFilePicker: Permissions not adequate to proceed.');
        return;
      }

      print(
          '_openFilePicker: Permissions appear adequate. Launching FilePicker...');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        print('_openFilePicker: File selected: $fileName, Path: ${file.path}');

        if (!await file.exists()) {
          print(
              '_openFilePicker: ERROR - Selected file does not exist at path: ${file.path}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Lỗi: File đã chọn không tồn tại hoặc không thể truy cập.')),
            );
          }
          return;
        }

        print('_openFilePicker: Reading file as bytes...');
        final bytes = await file.readAsBytes();
        print('_openFilePicker: Encoding file to base64...');
        final base64Data = base64Encode(bytes);
        print(
            '_openFilePicker: File ready, ${bytes.lengthInBytes} bytes. Sending to web via JsBridgeUtil...');

        await _jsBridgeUtil?.sendFileToWeb(base64Data, fileName);
        print('_openFilePicker: Attempted to send file to web.');
        if (mounted) {
          // SnackBar for upload confirmation is commented out in original code, keeping it that way.
        }
      } else {
        print('_openFilePicker: No file selected or result/path was null.');
        if (mounted) {
          if (result == null) {
            print('_openFilePicker: User cancelled file picking.');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Lỗi khi lấy thông tin file đã chọn.')),
            );
          }
        }
      }
    } catch (e, stacktrace) {
      print('_openFilePicker: An error occurred: $e');
      print('_openFilePicker: Stacktrace: $stacktrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Đã xảy ra lỗi khi chọn file: ${e.toString()}')),
        );
      }
    }
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

            if (!isExternal && _webViewController != null) {
              _jsBridgeUtil = JsBridgeUtil(
                _webViewController!,
                onFileUploadRequested: _openFilePicker,
              );
              await _jsBridgeUtil!.setupJavaScriptHandlers();
              final isLoggedIn = await _jsBridgeUtil!.checkLoginStatus();
              if (mounted) {
                setState(() {
                  _isLoadingPage = false;
                  _isLoggedIn = isLoggedIn;
                });
              }
            } else {
              setState(() {
                _isLoadingPage = false;
              });
            }
            _updateCurrentNavIndex(finishedUrl);
          },
          onWebResourceError: (WebResourceError error) {
            print(
                'WebView Delegate: WebResourceError: ${error.description}, URL: ${error.url}, ErrorCode: ${error.errorCode}, Type: ${error.errorType}, isForMainFrame: ${error.isForMainFrame}');
            if (!mounted) return;

            if (error.isForMainFrame == false &&
                error.url != null &&
                _isExternalUrl(error.url!)) {
              print(
                  'Ignoring non-main frame error on external domain: ${error.url}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Lỗi tải tài nguyên phụ')),
              );
              return;
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
                _errorMessage = "Không thể tải trang: ${error.description}";
              } else if (error.errorCode == -2 ||
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
            print(
                'WebView Delegate: onNavigationRequest received for URL: ${request.url}');

            final String lowercasedUrl = request.url.toLowerCase();
            bool hasFileExtension = lowercasedUrl.endsWith('.pdf') ||
                lowercasedUrl.endsWith('.jpg') || // Common image format
                lowercasedUrl.endsWith('.jpeg') || // Common image format
                lowercasedUrl.endsWith('.png') || // Common image format
                lowercasedUrl.endsWith('.gif') || // Common image format
                lowercasedUrl.endsWith('.bmp') || // Common image format
                lowercasedUrl.endsWith('.doc') || // Microsoft Word (old)
                lowercasedUrl.endsWith('.docx') || // Microsoft Word (new)
                lowercasedUrl.endsWith('.xls') || // Microsoft Excel (old)
                lowercasedUrl.endsWith('.xlsx') || // Microsoft Excel (new)
                lowercasedUrl.endsWith('.ppt') || // Microsoft PowerPoint (old)
                lowercasedUrl.endsWith('.pptx') || // Microsoft PowerPoint (new)
                lowercasedUrl.endsWith('.txt') || // Plain text
                lowercasedUrl.endsWith('.csv') || // Comma-separated values
                lowercasedUrl.endsWith('.rtf') || // Rich Text Format
                lowercasedUrl.endsWith('.odt') || // OpenDocument Text
                lowercasedUrl.endsWith('.ods') || // OpenDocument Spreadsheet
                lowercasedUrl.endsWith('.odp') || // OpenDocument Presentation
                lowercasedUrl.endsWith('.zip') || // ZIP archive
                lowercasedUrl.endsWith('.rar'); // RAR archive

            bool isApiDownloadLink =
                request.url.contains('/api/QuanLyHDSDApi/Download/');

            if (hasFileExtension || isApiDownloadLink) {
              String suggestedFileName;
              List<String> pathSegments = Uri.parse(request.url).pathSegments;

              if (isApiDownloadLink) {
                int downloadKeywordIndex = -1;
                for (int i = 0; i < pathSegments.length; i++) {
                  if (pathSegments[i].toLowerCase() == 'download') {
                    downloadKeywordIndex = i;
                    break;
                  }
                }
                if (downloadKeywordIndex != -1 &&
                    downloadKeywordIndex + 1 < pathSegments.length &&
                    pathSegments[downloadKeywordIndex + 1].isNotEmpty) {
                  suggestedFileName = pathSegments[downloadKeywordIndex + 1];
                } else {
                  suggestedFileName = 'downloaded_item';
                }
              } else {
                suggestedFileName = pathSegments.isNotEmpty
                    ? pathSegments.last
                    : 'downloaded_file';
              }

              if (suggestedFileName.isEmpty) {
                suggestedFileName = 'downloaded_file_generic';
              }

              print(
                  'WebView Delegate: Intercepting navigation to ${request.url} for download. Suggested filename: $suggestedFileName. Calling _downloadFile...');

              await _downloadFile(request.url, suggestedFileName);

              return NavigationDecision.prevent;
            }

            print(
                'WebView Delegate: Allowing WebView to navigate to ${request.url}');
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) {
            if (change.url != null) {
              print('WebView Delegate: URL changed to: ${change.url}');
            }
          },
        ),
      );

    _webViewController = tempController;
    if (_webViewController != null) {
      _setupJavaScriptChannels();
    }
    _webViewController!.loadRequest(Uri.parse(_currentUrl));

    if (mounted) {
      setState(() {});
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
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text(
          'Dịch vụ công Thành ủy Hà Nội',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
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
        shape: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1.0,
          ),
        ),
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
                            onPressed: _isConnected ||
                                    _errorMessage
                                        .contains("Không thể tải trang")
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
