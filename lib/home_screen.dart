import 'dart:async';
// import 'dart:convert'; // Đã loại bỏ vì không sử dụng
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
import 'js_bridge_util.dart';
import 'menu_widgets.dart';
import 'package:image_picker/image_picker.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Helper class cho kết quả phân tích params của file picker
class _FilePickerParamsParseResult {
  final FileType fileType;
  final List<String>? allowedExtensions;

  _FilePickerParamsParseResult(this.fileType, this.allowedExtensions);
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
    _initializeNotifications();
    _checkInitialConnectivity();
    final checker = InternetConnectionChecker.createInstance();
    _connectivitySubscription = checker.onStatusChange.listen(
      (status) {
        _updateConnectionStatus(status == InternetConnectionStatus.connected);
      },
    );
    _requestPermissions(); // Yêu cầu quyền ban đầu
    _loadUrl(_currentUrl);
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings,
        onDidReceiveNotificationResponse:
            (NotificationResponse response) async {
      if (response.payload != null && response.payload!.isNotEmpty) {
        OpenFile.open(response.payload);
      }
    });
  }

  Future<void> _showDownloadNotification(
      String fileName, String filePath) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'download_channel_id',
      'Downloads',
      channelDescription: 'Channel for download notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000), // Unique ID
      'Tải xuống hoàn tất',
      fileName,
      platformChannelSpecifics,
      payload: filePath,
    );
  }

  Future<void> _showPermissionPermanentlyDeniedDialog(
      {String? permissionType}) async {
    if (!mounted) return;
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

    return showDialog<void>(
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
          content: SingleChildScrollView(
            child: ListBody(children: contentWidgets),
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

  Future<void> _requestPermissions() async {
    print("HomeScreen: Bắt đầu yêu cầu các quyền ban đầu...");
    List<Permission> permissionsToRequest = [];

    if (Platform.isAndroid) {
      permissionsToRequest.addAll([
        Permission.camera,
        Permission.notification,
        Permission.photos,
        Permission.videos,
        Permission.audio,
        Permission.storage,
      ]);
    } else if (Platform.isIOS) {
      permissionsToRequest.addAll([
        Permission.photos,
        Permission.camera,
      ]);
    }

    if (permissionsToRequest.isEmpty) {
      print("HomeScreen: Không có quyền nào được định nghĩa để yêu cầu.");
      return;
    }

    Map<Permission, PermissionStatus> statuses =
        await permissionsToRequest.request();

    if (!mounted) return;

    for (Permission permission in statuses.keys) {
      PermissionStatus status = statuses[permission]!;
      String permissionType = _getPermissionTypeString(permission);
      print("HomeScreen: Quyền: $permissionType - Trạng thái: $status");

      if (status.isPermanentlyDenied) {
        await _showPermissionPermanentlyDeniedDialog(
            permissionType: permissionType);
      } else if (status.isDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Quyền $permissionType bị từ chối. Một số chức năng có thể bị hạn chế.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
    print("HomeScreen: Hoàn tất yêu cầu các quyền ban đầu.");
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
            _isError = false; // Xóa lỗi mạng nếu đã kết nối lại
            // Cân nhắc tải lại trang nếu lỗi trước đó là do mạng
            if (_currentUrl.isNotEmpty && _webViewController == null) {
              _retryLoading();
            }
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
    // _webViewController?.clearCache(); // Cân nhắc nếu cần
    super.dispose();
  }

  Future<void> _downloadFile(String url, String suggestedFileName) async {
    print(
        '_downloadFile: Starting download for URL: $url, Suggested Filename: $suggestedFileName');
    try {
      // TODO: Có thể thêm kiểm tra quyền storage ở đây nếu chưa chắc chắn từ _requestPermissions
      // bool hasPermission = await _checkStoragePermission(); if (!hasPermission) return;

      final Directory directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      print('_downloadFile: Storage directory: ${directory.path}');
      final response = await http.get(Uri.parse(url));
      print('_downloadFile: HTTP response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        String finalFileName = suggestedFileName;
        final disposition = response.headers['content-disposition'];
        if (disposition != null) {
          String? extractedName;
          // UTF-8 filename
          final starMatch = RegExp(r'filename\*=UTF-8\' '\'([^\;\r\n]+)',
                  caseSensitive: false)
              .firstMatch(disposition);
          if (starMatch != null && starMatch.group(1) != null) {
            try {
              extractedName = Uri.decodeComponent(starMatch.group(1)!);
            } catch (e) {
              print("Error decoding filename* UTF-8: $e");
            }
          }
          // Quoted filename
          if (extractedName == null || extractedName.isEmpty) {
            final plainMatch =
                RegExp(r'filename="([^"]+)"', caseSensitive: false)
                    .firstMatch(disposition);
            if (plainMatch != null && plainMatch.group(1) != null) {
              extractedName = plainMatch.group(1);
            }
          }
          // Non-quoted filename
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
        // Sanitize filename
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã tải xuống: $finalFileName'),
              action: SnackBarAction(
                  label: 'MỞ', onPressed: () => OpenFile.open(filePath)),
            ),
          );
          await _showDownloadNotification(finalFileName, filePath);
        }
      } else {
        print('_downloadFile: HTTP Error ${response.statusCode} for $url');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Lỗi tải xuống: ${response.statusCode}. Không thể tải tệp.')),
          );
        }
      }
    } catch (e, s) {
      print('_downloadFile: Exception occurred: $e\nStack: $s');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải xuống tệp: $e')),
        );
      }
    }
  }

  Future<bool> _showPermissionExplanationDialog({
    required BuildContext context,
    required String permissionFriendlyName,
    required String explanation,
  }) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: Text('Yêu cầu quyền truy cập $permissionFriendlyName'),
              content: SingleChildScrollView(child: Text(explanation)),
              actions: <Widget>[
                TextButton(
                  child: const Text('Hủy bỏ'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                TextButton(
                  child: const Text('Đồng ý & Tiếp tục'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // Helper để yêu cầu quyền với dialog giải thích
  Future<PermissionStatus> _requestPermissionWithExplanation(
    Permission permission,
    String permissionFriendlyName,
    String explanation,
  ) async {
    if (!mounted)
      return PermissionStatus.denied; // Hoặc trạng thái phù hợp khác

    PermissionStatus status = await permission.status;
    if (status.isGranted || (Platform.isIOS && status.isLimited)) {
      return status;
    }

    // Chỉ hiển thị dialog giải thích nếu quyền chưa được cấp và không bị từ chối vĩnh viễn
    // (vì _showPermissionPermanentlyDeniedDialog sẽ xử lý trường hợp đó sau)
    if (status.isDenied) {
      // Hoặc !status.isPermanentlyDenied
      bool didAcknowledge = await _showPermissionExplanationDialog(
        context: context, // Sử dụng context của _HomeScreenState
        permissionFriendlyName: permissionFriendlyName,
        explanation: explanation,
      );

      if (didAcknowledge) {
        status = await permission.request();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Đã hủy yêu cầu quyền $permissionFriendlyName.')),
          );
        }
        return PermissionStatus.denied; // Người dùng hủy dialog giải thích
      }
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
              if (parts.length > 1 && parts[1] != '*') return parts[1];
            }
            return processedType;
          })
          .where((e) => e.isNotEmpty && !e.contains('*'))
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
      } else if (types.isNotEmpty && fileTypeForPicker == FileType.any) {
        List<String> validExtensions =
            types.where((t) => !t.contains('/') && t.isNotEmpty).toList();
        if (validExtensions.isNotEmpty) {
          fileTypeForPicker = FileType.custom;
          allowedExtensionsForPicker = validExtensions;
        }
      }
    }
    return _FilePickerParamsParseResult(
        fileTypeForPicker, allowedExtensionsForPicker);
  }

  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    print(
      "Android File Chooser: Mode: ${params.mode}, Types: ${params.acceptTypes}, Capture: ${params.isCaptureEnabled}",
    );

    final ImagePicker picker = ImagePicker();
    List<String> selectedPaths = [];

    bool wantsImages =
        params.acceptTypes.any((type) => type.toLowerCase().contains("image"));
    bool wantsVideos =
        params.acceptTypes.any((type) => type.toLowerCase().contains("video"));
    bool genericAccept = params.acceptTypes.isEmpty ||
        params.acceptTypes.any((type) => type == "*/*");

    // Ưu tiên Camera nếu isCaptureEnabled và chấp nhận ảnh
    if (params.isCaptureEnabled &&
        (wantsImages || (genericAccept && !wantsVideos))) {
      print("Capture mode enabled, attempting to take a photo.");
      PermissionStatus cameraStatus = await _requestPermissionWithExplanation(
        Permission.camera,
        "Camera",
        "Ứng dụng cần quyền Camera để bạn chụp ảnh mới. Vui lòng cấp quyền.",
      );

      if (cameraStatus.isGranted) {
        try {
          final XFile? photo =
              await picker.pickImage(source: ImageSource.camera);
          if (photo != null) return [photo.path];
        } catch (e) {
          print("Error taking photo: $e");
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Lỗi khi chụp ảnh: $e')));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Quyền Camera bị từ chối.')));
          if (cameraStatus.isPermanentlyDenied) {
            await _showPermissionPermanentlyDeniedDialog(
                permissionType: "camera");
          }
        }
      }
      return []; // Trả về rỗng nếu chụp ảnh không thành công hoặc bị hủy
    }

    // Hiển thị dialog lựa chọn nguồn (Thư viện/Camera)
    final choice = await showModalBottomSheet<ImageSource?>(
      context: context,
      builder: (BuildContext sheetContext) {
        List<Widget> options = [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Chọn từ Thư viện/Tệp'),
            onTap: () =>
                Navigator.pop(sheetContext, null), // null for gallery/file
          )
        ];
        if (wantsImages || genericAccept) {
          // Chỉ hiện camera nếu phù hợp
          options.add(ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('Chụp ảnh mới'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ));
        }
        return SafeArea(child: Wrap(children: options));
      },
    );

    if (choice == ImageSource.camera) {
      PermissionStatus cameraStatus = await _requestPermissionWithExplanation(
        Permission.camera,
        "Camera",
        "Ứng dụng cần quyền Camera để bạn chụp ảnh mới. Vui lòng cấp quyền.",
      );
      if (cameraStatus.isGranted) {
        try {
          final XFile? photo =
              await picker.pickImage(source: ImageSource.camera);
          if (photo != null) selectedPaths.add(photo.path);
        } catch (e) {
          print("Error taking photo with picker: $e");
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Lỗi khi chụp ảnh: $e')));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Quyền Camera bị từ chối.')));
          if (cameraStatus.isPermanentlyDenied) {
            await _showPermissionPermanentlyDeniedDialog(
                permissionType: "camera");
          }
        }
      }
    } else if (choice == null) {
      // Người dùng chọn "Thư viện/Tệp"
      _FilePickerParamsParseResult pickerParams =
          _parseFileSelectorParams(params);

      Permission permissionNeeded;
      String permissionFriendlyName;

      // Xác định quyền cần thiết dựa trên loại file và phiên bản Android
      if (Platform.isAndroid) {
        if (pickerParams.fileType == FileType.image) {
          permissionNeeded = Permission.photos;
        } else if (pickerParams.fileType == FileType.video) {
          permissionNeeded = Permission.videos;
        } else if (pickerParams.fileType == FileType.audio) {
          permissionNeeded = Permission.audio;
        } else {
          // FileType.any or FileType.custom or FileType.media
          permissionNeeded = Permission
              .storage; // Fallback cho Android cũ hoặc các loại file khác
        }
      } else {
        // iOS
        permissionNeeded = Permission.photos; // Bao gồm cả video
      }
      permissionFriendlyName = _getPermissionTypeString(permissionNeeded);

      PermissionStatus fileAccessStatus =
          await _requestPermissionWithExplanation(
        permissionNeeded,
        permissionFriendlyName,
        "Ứng dụng cần quyền truy cập $permissionFriendlyName để bạn chọn tệp. Vui lòng cấp quyền.",
      );

      // Fallback cho Android nếu quyền media cụ thể (photos, videos, audio) thất bại nhưng storage thì được
      if (Platform.isAndroid &&
          !fileAccessStatus.isGranted &&
          permissionNeeded != Permission.storage) {
        print(
            "Quyền $permissionFriendlyName thất bại, thử fallback với Storage chung.");
        PermissionStatus storageStatus =
            await _requestPermissionWithExplanation(
          Permission.storage,
          _getPermissionTypeString(Permission.storage),
          "Ứng dụng cần quyền truy cập ${_getPermissionTypeString(Permission.storage)} để bạn chọn tệp. Vui lòng cấp quyền.",
        );
        if (storageStatus.isGranted) {
          fileAccessStatus = storageStatus;
          print("Fallback với Storage thành công.");
        } else {
          print("Fallback với Storage cũng thất bại.");
        }
      }

      if (fileAccessStatus.isGranted ||
          (Platform.isIOS && fileAccessStatus.isLimited)) {
        try {
          FilePickerResult? result = await FilePicker.platform.pickFiles(
            type: pickerParams.fileType,
            allowedExtensions: (pickerParams.fileType == FileType.custom &&
                    pickerParams.allowedExtensions != null &&
                    pickerParams.allowedExtensions!.isNotEmpty)
                ? pickerParams.allowedExtensions
                : null,
            allowMultiple: params.mode == FileSelectorMode.openMultiple,
          );
          if (result != null && result.files.isNotEmpty) {
            selectedPaths.addAll(result.paths
                .where((path) => path != null)
                .map((path) => path!));
          }
        } catch (e) {
          print("Error picking files: $e");
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Lỗi khi chọn tệp: $e')));
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('Quyền truy cập $permissionFriendlyName bị từ chối.')));
          if (fileAccessStatus.isPermanentlyDenied) {
            await _showPermissionPermanentlyDeniedDialog(
                permissionType: permissionFriendlyName);
          }
        }
      }
    }
    // else: User dismissed the bottom sheet, do nothing.

    return selectedPaths;
  }

  void _loadUrl(String url, {bool isRetry = false}) {
    if (url.isEmpty) return;
    String effectiveUrl = url;
    if (!effectiveUrl.startsWith('http://') &&
        !effectiveUrl.startsWith('https://')) {
      effectiveUrl =
          'http://$effectiveUrl'; // Hoặc https tùy theo default của bạn
    }

    // Chỉ cập nhật _currentUrl và controller nếu URL thực sự thay đổi hoặc là retry
    if (!isRetry || _currentUrl.isEmpty || _currentUrl != effectiveUrl) {
      _currentUrl = effectiveUrl;
    }
    _urlController.text = _currentUrl; // Luôn cập nhật text field

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
            if (!mounted) return;
            setState(() {
              _isLoadingPage = true; // Đảm bảo loading indicator hiển thị
              _isError = false;
            });
          },
          onPageFinished: (String finishedUrl) async {
            print('WebView Delegate: Page finished loading: $finishedUrl');
            if (!mounted) return;

            bool isExternal = _isExternalUrl(finishedUrl);
            if (!isExternal && _webViewController != null) {
              _jsBridgeUtil = JsBridgeUtil(_webViewController!);
              try {
                final isLoggedIn = await _jsBridgeUtil?.checkLoginStatus() ??
                    false; // Mặc định false nếu có lỗi
                if (mounted) {
                  setState(() {
                    _isLoggedIn = isLoggedIn;
                  });
                }
              } catch (e) {
                print("Error checking login status via JSBridge: $e");
                if (mounted) {
                  setState(() {
                    _isLoggedIn = false; // Hoặc giá trị mặc định an toàn
                  });
                }
              }
            }
            // Luôn set _isLoadingPage = false sau khi page finished, bất kể JS bridge
            if (mounted) {
              setState(() {
                _isLoadingPage = false;
              });
            }
            _updateCurrentNavIndex(finishedUrl);
          },
          onWebResourceError: (WebResourceError error) {
            print(
                'WebView Delegate: WebResourceError: ${error.description}, URL: ${error.url}, Code: ${error.errorCode}, Type: ${error.errorType}, MainFrame: ${error.isForMainFrame}');
            if (!mounted) return;

            // Bỏ qua lỗi tài nguyên phụ trên domain ngoài nếu không phải frame chính
            if (error.isForMainFrame == false &&
                error.url != null &&
                _isExternalUrl(error.url!)) {
              print(
                  'Ignoring non-main frame error on external domain: ${error.url}');
              // Cân nhắc không hiển thị SnackBar cho lỗi tài nguyên phụ trừ khi rất quan trọng
              // ScaffoldMessenger.of(context).showSnackBar(
              //   SnackBar(content: Text('Lỗi tải tài nguyên phụ từ: ${error.url}')),
              // );
              return;
            }

            // Nếu lỗi xảy ra cho frame chính hoặc URL hiện tại
            if (error.isForMainFrame == true || error.url == _currentUrl) {
              setState(() {
                _isLoadingPage = false;
                _isError = true;
                if (!_isConnected) {
                  _errorMessage =
                      "Mất kết nối mạng. Vui lòng kiểm tra lại đường truyền.";
                } else if (error.errorCode ==
                        -2 || // net::ERR_NAME_NOT_RESOLVED
                    error.errorType == WebResourceErrorType.hostLookup ||
                    error.errorType == WebResourceErrorType.connect ||
                    error.errorType == WebResourceErrorType.timeout) {
                  _errorMessage =
                      "Không thể kết nối tới máy chủ hoặc không có kết nối mạng. ${error.description}";
                } else {
                  _errorMessage =
                      "Lỗi tải trang: ${error.description} (Mã: ${error.errorCode})";
                }
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) async {
            print('WebView Delegate: Navigating to: ${request.url}');
            final String lowercasedUrl = request.url.toLowerCase();
            // Danh sách các đuôi file phổ biến hơn
            const List<String> fileExtensions = [
              '.pdf', '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp',
              '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
              '.txt', '.csv', '.rtf', '.odt', '.ods', '.odp',
              '.zip', '.rar', '.7z', '.tar', '.gz',
              // Thêm các định dạng media nếu cần tải trực tiếp thay vì mở trong webview
              // '.mp3', '.mp4', '.mov', '.avi'
            ];

            bool hasFileExtension =
                fileExtensions.any((ext) => lowercasedUrl.endsWith(ext));
            bool isApiDownloadLink =
                request.url.contains('/api/QuanLyHDSDApi/Download/');

            if (hasFileExtension || isApiDownloadLink) {
              String suggestedFileName;
              List<String> pathSegments = Uri.parse(request.url).pathSegments;

              if (isApiDownloadLink) {
                // Tìm 'Download' và lấy segment tiếp theo làm tên file
                int downloadKeywordIndex = pathSegments
                    .indexWhere((s) => s.toLowerCase() == 'download');
                if (downloadKeywordIndex != -1 &&
                    downloadKeywordIndex + 1 < pathSegments.length &&
                    pathSegments[downloadKeywordIndex + 1].isNotEmpty) {
                  suggestedFileName = pathSegments[downloadKeywordIndex + 1];
                } else {
                  suggestedFileName = pathSegments.isNotEmpty
                      ? pathSegments.last
                      : 'downloaded_item';
                }
              } else {
                // Lấy từ segment cuối cùng cho các link file trực tiếp
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
              if (mounted)
                _urlController.text = change.url!; // Cập nhật URL bar
              _updateCurrentNavIndex(change.url!);
            }
          },
        ),
      );

    if (Platform.isAndroid) {
      final androidController =
          tempController.platform as AndroidWebViewController;
      // Bọc trong try-catch nếu có lo ngại về phiên bản webview_flutter_android
      try {
        androidController.setOnShowFileSelector(_androidFilePicker);
        print("setOnShowFileSelector đã được thiết lập cho Android.");
      } catch (e) {
        print("Lỗi khi thiết lập setOnShowFileSelector: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể khởi tạo trình chọn file: $e')),
          );
        }
      }
    }

    _webViewController = tempController; // Gán controller mới
    _webViewController!.loadRequest(Uri.parse(_currentUrl));

    if (mounted) {
      setState(() {}); // Cập nhật UI để hiển thị WebViewWidget
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
        // Hiển thị SnackBar thông báo rõ hơn
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Không có kết nối mạng để tải lại.")),
        );
      }
      return;
    }
    // Chỉ tải lại nếu có URL hợp lệ
    if (_currentUrl.isNotEmpty) {
      print("Retrying to load: $_currentUrl");
      _loadUrl(_currentUrl, isRetry: true);
    } else if (MenuConfig.homeUrl.isNotEmpty) {
      print("No current URL, retrying to load home: ${MenuConfig.homeUrl}");
      _loadUrl(MenuConfig.homeUrl, isRetry: true);
    } else {
      print("Cannot retry, no valid URL available.");
      if (mounted) {
        setState(() {
          _isLoadingPage = false;
          _isError = true;
          _errorMessage =
              "Không có URL để tải lại. Vui lòng kiểm tra cấu hình.";
        });
      }
    }
  }

  void _updateCurrentNavIndex(String url) {
    if (!mounted) return;
    Uri? currentLoadedUri;
    try {
      currentLoadedUri = Uri.parse(url);
    } catch (_) {
      return; // Không thể parse URL hiện tại
    }

    for (int i = 0; i < MenuConfig.bottomNavItems.length; i++) {
      Uri? itemUri;
      try {
        itemUri = Uri.parse(MenuConfig.bottomNavItems[i].url);
      } catch (_) {
        continue; // Bỏ qua nếu URL của item không hợp lệ
      }

      // So sánh host và path để xác định mục active
      // Chỉ so sánh host nếu cả hai đều có (tránh so sánh với "about:blank" hoặc URL tương đối không có host)
      bool hostMatch = (itemUri.host == currentLoadedUri.host);
      // Path nên bắt đầu giống nhau
      bool pathMatch = currentLoadedUri.path.startsWith(itemUri.path);

      if (hostMatch && pathMatch) {
        if (_currentNavIndex != i) {
          setState(() {
            _currentNavIndex = i;
          });
        }
        return; // Tìm thấy mục khớp, thoát vòng lặp
      }
    }
    // Nếu không có mục nào khớp hoàn toàn, có thể reset về một trạng thái mặc định hoặc giữ nguyên
    // setState(() { _currentNavIndex = -1; }); // Ví dụ: không có mục nào active
  }

  void _onBottomNavTap(int index) {
    // Không làm gì nếu tap vào mục đang active hoặc index không hợp lệ
    if (index == _currentNavIndex ||
        index < 0 ||
        index >= MenuConfig.bottomNavItems.length) return;

    if (mounted) {
      setState(() {
        _isError = false; // Reset lỗi khi điều hướng
      });
    }
    _loadUrl(MenuConfig.bottomNavItems[index].url);
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
          actions: <Widget>[
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
                ? null // Disable nếu đang tải hoặc có lỗi mạng nghiêm trọng
                : _retryLoading,
          ),
          const SizedBox(width: 8),
        ],
        elevation: 1.5,
      ),
      drawer: AppDrawer(
        onNavigate: _onNavigate,
        isLoggedIn: _isLoggedIn,
        onLoginRequired: _onLoginRequired,
      ),
      body: Column(
        children: [
          // URL Bar (nếu bạn muốn giữ lại)
          // Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: TextField(
          //     controller: _urlController,
          //     decoration: InputDecoration(
          //       hintText: 'Nhập URL...',
          //       suffixIcon: IconButton(
          //         icon: Icon(Icons.arrow_forward),
          //         onPressed: () => _loadUrl(_urlController.text),
          //       ),
          //     ),
          //     onSubmitted: (url) => _loadUrl(url),
          //   ),
          // ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_webViewController != null &&
                    !_isError) // Chỉ hiển thị webview nếu không có lỗi nghiêm trọng
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
                if (_isError &&
                    !_isLoadingPage) // Hiển thị lỗi nếu có và không đang tải
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
                          )
                        ],
                      ),
                    ),
                  ),
                // Placeholder khi webview chưa sẵn sàng và không có lỗi/loading
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
                        Text("Đang khởi tạo trình duyệt...",
                            style: TextStyle(fontSize: 16, color: Colors.grey)),
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
