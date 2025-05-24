import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Utility class to manage JavaScript Bridge between Flutter and WebView
class JsBridgeUtil {
  final WebViewController controller;
  final VoidCallback? onFileUploadRequested; // Callback for file upload

  JsBridgeUtil(this.controller, {this.onFileUploadRequested});

  /// Set up JavaScript handlers and channels
  Future<void> setupJavaScriptHandlers() async {
    // Register JavaScript channels
    controller.addJavaScriptChannel(
      'LoginResultHandler',
      onMessageReceived: (JavaScriptMessage message) {
        try {
          final data = jsonDecode(message.message);
          bool success = data['success'] ?? false;
          String messageText = data['message'] ?? '';
          print('LoginResultHandler: success=$success, message=$messageText');
          // Handle login result (e.g., show SnackBar or update UI)
        } catch (e) {
          print('Error in LoginResultHandler: $e');
        }
      },
    );

    controller.addJavaScriptChannel(
      'SessionInfoHandler',
      onMessageReceived: (JavaScriptMessage message) {
        try {
          final data = jsonDecode(message.message);
          String token = data['token'] ?? '';
          String expiry = data['expiry'] ?? '';
          print('SessionInfoHandler: token=$token, expiry=$expiry');
        } catch (e) {
          print('Error in SessionInfoHandler: $e');
        }
      },
    );

    controller.addJavaScriptChannel(
      'ProfileUpdateResultHandler',
      onMessageReceived: (JavaScriptMessage message) {
        try {
          final data = jsonDecode(message.message);
          bool success = data['success'] ?? false;
          String messageText = data['message'] ?? '';
          print(
              'ProfileUpdateResultHandler: success=$success, message=$messageText');
        } catch (e) {
          print('Error in ProfileUpdateResultHandler: $e');
        }
      },
    );

    controller.addJavaScriptChannel(
      'PaymentResultHandler',
      onMessageReceived: (JavaScriptMessage message) {
        try {
          final data = jsonDecode(message.message);
          bool success = data['success'] ?? false;
          String transactionId = data['transactionId'] ?? '';
          String messageText = data['message'] ?? '';
          print(
              'PaymentResultHandler: success=$success, transactionId=$transactionId, message=$messageText');
        } catch (e) {
          print('Error in PaymentResultHandler: $e');
        }
      },
    );

    controller.addJavaScriptChannel(
      'ReceiptInfoHandler',
      onMessageReceived: (JavaScriptMessage message) {
        try {
          final data = jsonDecode(message.message);
          String receiptUrl = data['receiptUrl'] ?? '';
          String receiptId = data['receiptId'] ?? '';
          print(
              'ReceiptInfoHandler: receiptUrl=$receiptUrl, receiptId=$receiptId');
        } catch (e) {
          print('Error in ReceiptInfoHandler: $e');
        }
      },
    );

    controller.addJavaScriptChannel(
      'ReviewSubmitResultHandler',
      onMessageReceived: (JavaScriptMessage message) {
        try {
          final data = jsonDecode(message.message);
          bool success = data['success'] ?? false;
          String reviewId = data['reviewId'] ?? '';
          String messageText = data['message'] ?? '';
          print(
              'ReviewSubmitResultHandler: success=$success, reviewId=$reviewId, message=$messageText');
        } catch (e) {
          print('Error in ReviewSubmitResultHandler: $e');
        }
      },
    );

    controller.addJavaScriptChannel(
      'ReportDataHandler',
      onMessageReceived: (JavaScriptMessage message) {
        try {
          final data = jsonDecode(message.message);
          print('ReportDataHandler: reportData=$data');
        } catch (e) {
          print('Error in ReportDataHandler: $e');
        }
      },
    );

    // Add FileUploadHandler for file upload requests
    controller.addJavaScriptChannel(
      'FileUploadHandler',
      onMessageReceived: (JavaScriptMessage message) {
        if (message.message == 'upload' && onFileUploadRequested != null) {
          onFileUploadRequested!(); // Trigger file picker in HomeScreen
        }
      },
    );

    // Inject base JavaScript after setting up channels
    await _injectBaseJavaScript();
  }

  /// Inject base JavaScript functions into WebView
  Future<void> _injectBaseJavaScript() async {
    const String baseScript = '''
    // Utility object for JavaScript to Flutter communication
    window.flutterBridge = {
      notifyLoginResult: function(success, message) {
        if (window.LoginResultHandler) {
          window.LoginResultHandler.postMessage(JSON.stringify({success: success, message: message}));
        } else {
          console.warn('LoginResultHandler not available');
        }
      },
      sendSessionInfo: function(token, expiry) {
        if (window.SessionInfoHandler) {
          window.SessionInfoHandler.postMessage(JSON.stringify({token: token, expiry: expiry}));
        } else {
          console.warn('SessionInfoHandler not available');
        }
      },
      notifyProfileUpdateResult: function(success, message) {
        if (window.ProfileUpdateResultHandler) {
          window.ProfileUpdateResultHandler.postMessage(JSON.stringify({success: success, message: message}));
        } else {
          console.warn('ProfileUpdateResultHandler not available');
        }
      },
      notifyPaymentResult: function(success, transactionId, message) {
        if (window.PaymentResultHandler) {
          window.PaymentResultHandler.postMessage(JSON.stringify({success: success, transactionId: transactionId, message: message}));
        } else {
          console.warn('PaymentResultHandler not available');
        }
      },
      sendReceiptInfo: function(receiptUrl, receiptId) {
        if (window.ReceiptInfoHandler) {
          window.ReceiptInfoHandler.postMessage(JSON.stringify({receiptUrl: receiptUrl, receiptId: receiptId}));
        } else {
          console.warn('ReceiptInfoHandler not available');
        }
      },
      notifyReviewSubmitResult: function(success, reviewId, message) {
        if (window.ReviewSubmitResultHandler) {
          window.ReviewSubmitResultHandler.postMessage(JSON.stringify({success: success, reviewId: reviewId, message: message}));
        } else {
          console.warn('ReviewSubmitResultHandler not available');
        }
      },
      sendReportData: function(reportData) {
        if (window.ReportDataHandler) {
          window.ReportDataHandler.postMessage(JSON.stringify(reportData));
        } else {
          console.warn('ReportDataHandler not available');
        }
      },
      requestFileUpload: function() {
        if (window.FileUploadHandler) {
          window.FileUploadHandler.postMessage('upload');
        } else {
          console.warn('FileUploadHandler not available');
        }
      }
    };

    // Check login status
    function checkLoginStatus() {
      try {
        if (window.location.pathname.toLowerCase().includes('/home') || window.location.pathname === '/') {
          const logoutButton = document.querySelector('a[href*="logout"], button[onclick*="logout"]');
          if (logoutButton) return true;
        }
        let accountElement = document.querySelector('a[href*="Account/Manage"], a[href*="Profile"]');
        if (accountElement) return true;
        const userElements = document.querySelectorAll('body *');
        for (let i = 0; i < userElements.length; i++) {
          if (userElements[i] && userElements[i].textContent) {
            const textContent = userElements[i].textContent.trim();
            if (textContent.includes('Thông tin tài khoản') || textContent.includes('Xin chào') || textContent.includes('Đăng xuất')) {
              if (userElements[i].tagName !== 'A' || !userElements[i].href || !userElements[i].href.toLowerCase().includes('login')) {
                return true;
              }
            }
          }
        }
        return false;
      } catch (e) {
        console.error('Error in checkLoginStatus:', e);
        return false;
      }
    }

    // Auto-fill login form
    function autoFillLoginForm(username, password) {
      try {
        let usernameInput = document.querySelector('input[name="username"], input[name="UserName"], input#username, input#UserName');
        let passwordInput = document.querySelector('input[name="password"], input[name="Password"], input#password, input#Password');
        if (!usernameInput) {
          const inputs = document.querySelectorAll('input[type="text"], input[type="email"]');
          for (let i = 0; i < inputs.length; i++) {
            if (inputs[i].offsetParent !== null) {
              usernameInput = inputs[i];
              break;
            }
          }
        }
        if (!passwordInput) {
          const passInputs = document.querySelectorAll('input[type="password"]');
          for (let i = 0; i < passInputs.length; i++) {
            if (passInputs[i].offsetParent !== null) {
              passwordInput = passInputs[i];
              break;
            }
          }
        }
        if (usernameInput) usernameInput.value = username;
        if (passwordInput) passwordInput.value = password;
        return !!(usernameInput && passwordInput);
      } catch (e) {
        console.error('Error in autoFillLoginForm:', e);
        return false;
      }
    }

    // Submit login form
    function submitLoginForm() {
      try {
        let submitButton = document.querySelector('button[type="submit"], input[type="submit"]');
        if (!submitButton) {
          const buttons = document.querySelectorAll('button');
          for (let i = 0; i < buttons.length; i++) {
            if (buttons[i].textContent && buttons[i].textContent.toLowerCase().includes('đăng nhập')) {
              submitButton = buttons[i];
              break;
            }
          }
        }
        if (submitButton) {
          submitButton.click();
          return true;
        }
        return false;
      } catch (e) {
        console.error('Error in submitLoginForm:', e);
        return false;
      }
    }

    // Initiate VneID login
    function initiateVneIDLogin() {
      try {
        let vneidButton = null;
        const links = document.querySelectorAll('a');
        for (let i = 0; i < links.length; i++) {
          if (links[i].href && links[i].href.toLowerCase().includes('vneid') || 
              (links[i].textContent && links[i].textContent.toLowerCase().includes('tài khoản định danh điện tử'))) {
            vneidButton = links[i];
            break;
          }
        }
        if (vneidButton) {
          vneidButton.click();
          return true;
        }
        return false;
      } catch (e) {
        console.error('Error in initiateVneIDLogin:', e);
        return false;
      }
    }

    // Inject file input click handler
    document.addEventListener('DOMContentLoaded', function() {
      document.querySelectorAll('input[type="file"]').forEach(input => {
        input.addEventListener('click', () => {
          window.flutterBridge.requestFileUpload();
        });
      });
    });

    // Handle file selection from Flutter
    window.onFileSelected = function(base64Data, fileName) {
      try {
        const byteString = atob(base64Data);
        const byteArray = new Uint8Array(byteString.length);
        for (let i = 0; i < byteString.length; i++) {
          byteArray[i] = byteString.charCodeAt(i);
        }
        const blob = new Blob([byteArray]);
        const fileInput = document.querySelector('input[type="file"]');
        if (fileInput) {
          const file = new File([blob], fileName);
          const dataTransfer = new DataTransfer();
          dataTransfer.items.add(file);
          fileInput.files = dataTransfer.files;
          fileInput.dispatchEvent(new Event('change', { bubbles: true }));
        }
      } catch (e) {
        console.error('Error in onFileSelected:', e);
      }
    };

    // Register functions to window
    window.autoFillLoginForm = autoFillLoginForm;
    window.submitLoginForm = submitLoginForm;
    window.checkLoginStatus = checkLoginStatus;
    window.initiateVneIDLogin = initiateVneIDLogin;

    console.log('JavaScript Bridge (base functions) has been initialized');
    ''';

    try {
      await controller.runJavaScript(baseScript);
    } catch (e) {
      print('Error injecting base JavaScript: $e');
    }
  }

  /// Inject JavaScript for party fee functions
  Future<void> injectPartyFeeJavaScript() async {
    const String partyFeeScript = '''
    function getPartyFeeList() {
      try {
        const feeItems = [];
        const feeElements = document.querySelectorAll('.party-fee-item');
        feeElements.forEach(el => {
          feeItems.push({
            id: el.getAttribute('data-id'),
            name: el.querySelector('.fee-name')?.textContent.trim(),
            amount: el.querySelector('.fee-amount')?.textContent.trim(),
            dueDate: el.querySelector('.fee-due-date')?.textContent.trim(),
            status: el.querySelector('.fee-status')?.textContent.trim()
          });
        });
        return JSON.stringify(feeItems);
      } catch (e) {
        console.error('Error in getPartyFeeList:', e);
        return '[]';
      }
    }

    function selectPartyFee(feeId) {
      try {
        const feeElement = document.querySelector(`.party-fee-item[data-id="\${feeId}"]`);
        if (feeElement) {
          const selectButton = feeElement.querySelector('.select-button');
          if (selectButton) {
            selectButton.click();
            return true;
          }
        }
        return false;
      } catch (e) {
        console.error('Error in selectPartyFee:', e);
        return false;
      }
    }

    function fillPaymentInfo(paymentInfoJson) {
      try {
        const paymentInfo = JSON.parse(paymentInfoJson);
        Object.keys(paymentInfo).forEach(key => {
          const el = document.querySelector(`#payment-form [name="\${key}"]`);
          if (el) el.value = paymentInfo[key];
        });
        return true;
      } catch (e) {
        console.error('Error in fillPaymentInfo:', e);
        return false;
      }
    }

    function confirmPayment() {
      try {
        const confirmButton = document.querySelector('#payment-form button[type="submit"]');
        if (confirmButton) {
          confirmButton.click();
          return true;
        }
        return false;
      } catch (e) {
        console.error('Error in confirmPayment:', e);
        return false;
      }
    }

    window.getPartyFeeList = getPartyFeeList;
    window.selectPartyFee = selectPartyFee;
    window.fillPaymentInfo = fillPaymentInfo;
    window.confirmPayment = confirmPayment;

    console.log('Party Fee JavaScript functions have been initialized');
    ''';

    try {
      await controller.runJavaScript(partyFeeScript);
    } catch (e) {
      print('Error injecting party fee JavaScript: $e');
    }
  }

  /// Inject JavaScript for review functions
  Future<void> injectReviewJavaScript() async {
    const String reviewScript = '''
    function getReviewList() {
      try {
        const reviews = [];
        const reviewElements = document.querySelectorAll('.review-item');
        reviewElements.forEach(el => {
          reviews.push({
            id: el.getAttribute('data-id'),
            title: el.querySelector('.review-title')?.textContent.trim(),
            date: el.querySelector('.review-date')?.textContent.trim(),
            status: el.querySelector('.review-status')?.textContent.trim()
          });
        });
        return JSON.stringify(reviews);
      } catch (e) {
        console.error('Error in getReviewList:', e);
        return '[]';
      }
    }

    function createNewReview() {
      try {
        const createButton = document.querySelector('.create-review-button');
        if (createButton) {
          createButton.click();
          return true;
        }
        return false;
      } catch (e) {
        console.error('Error in createNewReview:', e);
        return false;
      }
    }

    function fillReviewForm(reviewDataJson) {
      try {
        const reviewData = JSON.parse(reviewDataJson);
        Object.keys(reviewData).forEach(key => {
          const el = document.querySelector(`#review-form [name="\${key}"]`);
          if (el) {
            if (el.tagName === 'TEXTAREA') {
              el.textContent = reviewData[key];
            } else {
              el.value = reviewData[key];
            }
          }
        });
        return true;
      } catch (e) {
        console.error('Error in fillReviewForm:', e);
        return false;
      }
    }

    function submitReviewForm() {
      try {
        const submitButton = document.querySelector('#review-form button[type="submit"]');
        if (submitButton) {
          submitButton.click();
          return true;
        }
        return false;
      } catch (e) {
        console.error('Error in submitReviewForm:', e);
        return false;
      }
    }

    window.getReviewList = getReviewList;
    window.createNewReview = createNewReview;
    window.fillReviewForm = fillReviewForm;
    window.submitReviewForm = submitReviewForm;

    console.log('Review JavaScript functions have been initialized');
    ''';

    try {
      await controller.runJavaScript(reviewScript);
    } catch (e) {
      print('Error injecting review JavaScript: $e');
    }
  }

  /// Send file data to WebView
  Future<void> sendFileToWeb(String base64Data, String fileName) async {
    try {
      String jsCode = '''
        window.onFileSelected("$base64Data", "$fileName");
      ''';
      await controller.runJavaScript(jsCode);
    } catch (e) {
      print('Error sending file to web: $e');
    }
  }

  /// Auto-fill login form
  Future<bool> autoFillLogin(String username, String password) async {
    try {
      final result = await controller.runJavaScriptReturningResult(
          'autoFillLoginForm("$username", "$password")');
      return result.toString() == 'true';
    } catch (e) {
      print('Error calling autoFillLoginForm: $e');
      return false;
    }
  }

  /// Submit login form
  Future<bool> submitLogin() async {
    try {
      final result =
          await controller.runJavaScriptReturningResult('submitLoginForm()');
      return result.toString() == 'true';
    } catch (e) {
      print('Error calling submitLoginForm: $e');
      return false;
    }
  }

  /// Check login status
  Future<bool> checkLoginStatus() async {
    try {
      final result =
          await controller.runJavaScriptReturningResult('checkLoginStatus()');
      print('checkLoginStatus JS result: $result');
      return result.toString() == 'true';
    } catch (e) {
      print('Error calling checkLoginStatus: $e');
      return false;
    }
  }

  /// Initiate VneID login
  Future<bool> initiateVneIDLogin() async {
    try {
      final result =
          await controller.runJavaScriptReturningResult('initiateVneIDLogin()');
      return result.toString() == 'true';
    } catch (e) {
      print('Error calling initiateVneIDLogin: $e');
      return false;
    }
  }

  /// Get party fee list
  Future<String> getPartyFeeList() async {
    try {
      await injectPartyFeeJavaScript();
      final result =
          await controller.runJavaScriptReturningResult('getPartyFeeList()');
      return result is String ? result : result.toString();
    } catch (e) {
      print('Error calling getPartyFeeList: $e');
      return '[]';
    }
  }

  /// Select party fee
  Future<bool> selectPartyFee(String feeId) async {
    try {
      final result = await controller
          .runJavaScriptReturningResult('selectPartyFee("$feeId")');
      return result.toString() == 'true';
    } catch (e) {
      print('Error calling selectPartyFee: $e');
      return false;
    }
  }

  /// Fill payment info
  Future<bool> fillPaymentInfo(Map<String, dynamic> paymentInfo) async {
    try {
      final paymentInfoJson = json.encode(paymentInfo);
      final result = await controller.runJavaScriptReturningResult(
          'fillPaymentInfo(\'$paymentInfoJson\')');
      return result.toString() == 'true';
    } catch (e) {
      print('Error calling fillPaymentInfo: $e');
      return false;
    }
  }

  /// Confirm payment
  Future<bool> confirmPayment() async {
    try {
      final result =
          await controller.runJavaScriptReturningResult('confirmPayment()');
      return result.toString() == 'true';
    } catch (e) {
      print('Error calling confirmPayment: $e');
      return false;
    }
  }

  /// Get review list
  Future<String> getReviewList() async {
    try {
      await injectReviewJavaScript();
      final result =
          await controller.runJavaScriptReturningResult('getReviewList()');
      return result is String ? result : result.toString();
    } catch (e) {
      print('Error calling getReviewList: $e');
      return '[]';
    }
  }

  /// Create new review
  Future<bool> createNewReview() async {
    try {
      final result =
          await controller.runJavaScriptReturningResult('createNewReview()');
      return result.toString() == 'true';
    } catch (e) {
      print('Error calling createNewReview: $e');
      return false;
    }
  }

  /// Fill review form
  Future<bool> fillReviewForm(Map<String, dynamic> reviewData) async {
    try {
      final reviewDataJson = json.encode(reviewData);
      final result = await controller
          .runJavaScriptReturningResult('fillReviewForm(\'$reviewDataJson\')');
      return result.toString() == 'true';
    } catch (e) {
      print('Error calling fillReviewForm: $e');
      return false;
    }
  }

  /// Submit review form
  Future<bool> submitReviewForm() async {
    try {
      final result =
          await controller.runJavaScriptReturningResult('submitReviewForm()');
      return result.toString() == 'true';
    } catch (e) {
      print('Error calling submitReviewForm: $e');
      return false;
    }
  }
}
