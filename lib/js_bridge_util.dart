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
    // Unused channels (LoginResultHandler, SessionInfoHandler, ProfileUpdateResultHandler, PaymentResultHandler, ReceiptInfoHandler, ReviewSubmitResultHandler, ReportDataHandler) have been removed.

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
      // Unused flutterBridge functions (notifyLoginResult, sendSessionInfo, notifyProfileUpdateResult, notifyPaymentResult, sendReceiptInfo, notifyReviewSubmitResult, sendReportData) have been removed.

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
        // Logic for checkLoginStatus remains as it is used by home_screen.dart
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

    // Unused JavaScript functions (autoFillLoginForm, submitLoginForm, initiateVneIDLogin) have been removed.

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
        // Logic for onFileSelected remains as it is used by home_screen.dart
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
    // Unused function registrations (autoFillLoginForm, submitLoginForm, initiateVneIDLogin) have been removed.
    window.checkLoginStatus = checkLoginStatus;

    console.log('JavaScript Bridge (base functions) has been initialized');
    ''';

    try {
      await controller.runJavaScript(baseScript);
    } catch (e) {
      print('Error injecting base JavaScript: $e');
    }
  }

  // Unused Dart methods (injectPartyFeeJavaScript, injectReviewJavaScript) have been removed.

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

  // Unused Dart methods (autoFillLogin, submitLogin) have been removed.

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

  // Unused Dart methods (initiateVneIDLogin, getPartyFeeList, selectPartyFee, fillPaymentInfo, confirmPayment, getReviewList, createNewReview, fillReviewForm, submitReviewForm) have been removed.
}
