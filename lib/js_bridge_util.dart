import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Tiện ích để quản lý JavaScript Bridge giữa Flutter và WebView
class JsBridgeUtil {
  final WebViewController controller;

  JsBridgeUtil(this.controller);

  /// Thiết lập các JavaScript handlers
  Future<void> setupJavaScriptHandlers() async {
    // Đăng ký các handlers từ JavaScript đến Flutter
    await _injectBaseJavaScript();
  }

  /// Chèn các hàm JavaScript cơ bản vào WebView
  Future<void> _injectBaseJavaScript() async {
    const String baseScript = '''
    // Hàm tiện ích để gọi từ JavaScript về Flutter
    window.flutterBridge = {
      // Thông báo kết quả đăng nhập
      notifyLoginResult: function(success, message) {
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('loginResultHandler', success, message);
        }
      },
      
      // Gửi thông tin phiên đăng nhập
      sendSessionInfo: function(token, expiry) {
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('sessionInfoHandler', token, expiry);
        }
      },
      
      // Thông báo kết quả cập nhật thông tin tài khoản
      notifyProfileUpdateResult: function(success, message) {
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('profileUpdateResultHandler', success, message);
        }
      },
      
      // Thông báo kết quả thanh toán
      notifyPaymentResult: function(success, transactionId, message) {
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('paymentResultHandler', success, transactionId, message);
        }
      },
      
      // Gửi thông tin biên lai
      sendReceiptInfo: function(receiptUrl, receiptId) {
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('receiptInfoHandler', receiptUrl, receiptId);
        }
      },
      
      // Thông báo kết quả gửi phiếu nhận xét
      notifyReviewSubmitResult: function(success, reviewId, message) {
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('reviewSubmitResultHandler', success, reviewId, message);
        }
      },
      
      // Gửi dữ liệu báo cáo
      sendReportData: function(reportData) {
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('reportDataHandler', reportData);
        }
      }
    };
    
    // Hàm kiểm tra trạng thái đăng nhập
    function checkLoginStatus() {
      try {
        // Phương pháp 1: Kiểm tra URL - sau khi đăng nhập sẽ chuyển hướng đến trang chủ
        if (window.location.href.includes('/Home')) {
          return true;
        }
        
        // Phương pháp 2: Kiểm tra sự hiện diện của liên kết thông tin tài khoản
        const accountLink = document.querySelector('a[href*="Account"]') || 
                           document.querySelector('a:contains("Thông tin tài khoản")');
        if (accountLink !== null) {
          return true;
        }
        
        // Phương pháp 3: Kiểm tra tên người dùng hiển thị
        const userElements = document.querySelectorAll('*');
        for (let i = 0; i < userElements.length; i++) {
          if (userElements[i].textContent && 
              (userElements[i].textContent.includes('DVCHN') || 
               userElements[i].textContent.includes('Thông tin tài khoản'))) {
            return true;
          }
        }
        
        // Nếu không tìm thấy bất kỳ dấu hiệu nào của việc đăng nhập
        return false;
      } catch (e) {
        console.error('Error in checkLoginStatus:', e);
        return false;
      }
    }
    
    // Hàm tiện ích cho đăng nhập
    function autoFillLoginForm(username, password) {
      try {
        const usernameInput = document.querySelector('input[name="username"]') || 
                             document.querySelector('input[type="text"]');
        const passwordInput = document.querySelector('input[name="password"]') || 
                             document.querySelector('input[type="password"]');
        
        if (usernameInput) usernameInput.value = username;
        if (passwordInput) passwordInput.value = password;
        return true;
      } catch (e) {
        console.error('Error in autoFillLoginForm:', e);
        return false;
      }
    }
    
    function submitLoginForm() {
      try {
        const submitButton = document.querySelector('button[type="submit"]') || 
                            document.querySelector('input[type="submit"]') ||
                            document.querySelector('button:contains("ĐĂNG NHẬP")');
        
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
    
    function initiateVneIDLogin() {
      try {
        // Tìm và nhấp vào nút đăng nhập VneID
        const vneidButton = document.querySelector('a[href*="vneid"]') || 
                           document.querySelector('a:contains("Tài khoản định danh điện tử")');
        
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
    
    // Đăng ký các hàm vào window để có thể gọi từ Flutter
    window.autoFillLoginForm = autoFillLoginForm;
    window.submitLoginForm = submitLoginForm;
    window.checkLoginStatus = checkLoginStatus;
    window.initiateVneIDLogin = initiateVneIDLogin;
    
    console.log('JavaScript Bridge has been initialized');
    ''';

    await controller.runJavaScript(baseScript);
  }

  /// Chèn các hàm JavaScript cho chức năng nộp đảng phí
  Future<void> injectPartyFeeJavaScript() async {
    const String partyFeeScript = '''
    // Lấy danh sách đảng phí cần nộp
    function getPartyFeeList() {
      try {
        const feeItems = [];
        // Lấy các mục đảng phí từ bảng hoặc danh sách
        const feeElements = document.querySelectorAll('.party-fee-item');
        feeElements.forEach(el => {
          feeItems.push({
            id: el.getAttribute('data-id'),
            name: el.querySelector('.fee-name')?.textContent,
            amount: el.querySelector('.fee-amount')?.textContent,
            dueDate: el.querySelector('.fee-due-date')?.textContent,
            status: el.querySelector('.fee-status')?.textContent
          });
        });
        return JSON.stringify(feeItems);
      } catch (e) {
        console.error('Error in getPartyFeeList:', e);
        return '[]';
      }
    }
    
    // Chọn đảng phí để thanh toán
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
    
    // Điền thông tin thanh toán
    function fillPaymentInfo(paymentInfoJson) {
      try {
        const paymentInfo = JSON.parse(paymentInfoJson);
        // Điền thông tin vào form thanh toán
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
    
    // Xác nhận thanh toán
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
    
    // Đăng ký các hàm vào window để có thể gọi từ Flutter
    window.getPartyFeeList = getPartyFeeList;
    window.selectPartyFee = selectPartyFee;
    window.fillPaymentInfo = fillPaymentInfo;
    window.confirmPayment = confirmPayment;
    
    console.log('Party Fee JavaScript functions have been initialized');
    ''';

    await controller.runJavaScript(partyFeeScript);
  }

  /// Chèn các hàm JavaScript cho chức năng lập phiếu nhận xét
  Future<void> injectReviewJavaScript() async {
    const String reviewScript = '''
    // Lấy danh sách phiếu nhận xét
    function getReviewList() {
      try {
        const reviews = [];
        // Lấy các phiếu nhận xét từ bảng hoặc danh sách
        const reviewElements = document.querySelectorAll('.review-item');
        reviewElements.forEach(el => {
          reviews.push({
            id: el.getAttribute('data-id'),
            title: el.querySelector('.review-title')?.textContent,
            date: el.querySelector('.review-date')?.textContent,
            status: el.querySelector('.review-status')?.textContent
          });
        });
        return JSON.stringify(reviews);
      } catch (e) {
        console.error('Error in getReviewList:', e);
        return '[]';
      }
    }
    
    // Tạo phiếu nhận xét mới
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
    
    // Điền thông tin phiếu nhận xét
    function fillReviewForm(reviewDataJson) {
      try {
        const reviewData = JSON.parse(reviewDataJson);
        // Điền thông tin vào form
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
    
    // Gửi phiếu nhận xét
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
    
    // Đăng ký các hàm vào window để có thể gọi từ Flutter
    window.getReviewList = getReviewList;
    window.createNewReview = createNewReview;
    window.fillReviewForm = fillReviewForm;
    window.submitReviewForm = submitReviewForm;
    
    console.log('Review JavaScript functions have been initialized');
    ''';

    await controller.runJavaScript(reviewScript);
  }

  /// Gọi hàm JavaScript để tự động điền thông tin đăng nhập
  Future<bool> autoFillLogin(String username, String password) async {
    final result = await controller.runJavaScriptReturningResult(
        'autoFillLoginForm("$username", "$password")');
    return result.toString() == 'true';
  }

  /// Gọi hàm JavaScript để gửi form đăng nhập
  Future<bool> submitLogin() async {
    final result =
        await controller.runJavaScriptReturningResult('submitLoginForm()');
    return result.toString() == 'true';
  }

  /// Gọi hàm JavaScript để kiểm tra trạng thái đăng nhập
  Future<bool> checkLoginStatus() async {
    final result =
        await controller.runJavaScriptReturningResult('checkLoginStatus()');
    return result.toString() == 'true';
  }

  /// Gọi hàm JavaScript để bắt đầu đăng nhập qua VneID
  Future<bool> initiateVneIDLogin() async {
    final result =
        await controller.runJavaScriptReturningResult('initiateVneIDLogin()');
    return result.toString() == 'true';
  }

  /// Gọi hàm JavaScript để lấy danh sách đảng phí
  Future<String> getPartyFeeList() async {
    await injectPartyFeeJavaScript();
    final result =
        await controller.runJavaScriptReturningResult('getPartyFeeList()');
    return result.toString().replaceAll('"', '');
  }

  /// Gọi hàm JavaScript để chọn đảng phí thanh toán
  Future<bool> selectPartyFee(String feeId) async {
    final result = await controller
        .runJavaScriptReturningResult('selectPartyFee("$feeId")');
    return result.toString() == 'true';
  }

  /// Gọi hàm JavaScript để điền thông tin thanh toán
  Future<bool> fillPaymentInfo(Map<String, dynamic> paymentInfo) async {
    final paymentInfoJson = _mapToJsonString(paymentInfo);
    final result = await controller
        .runJavaScriptReturningResult('fillPaymentInfo(\'$paymentInfoJson\')');
    return result.toString() == 'true';
  }

  /// Gọi hàm JavaScript để xác nhận thanh toán
  Future<bool> confirmPayment() async {
    final result =
        await controller.runJavaScriptReturningResult('confirmPayment()');
    return result.toString() == 'true';
  }

  /// Gọi hàm JavaScript để lấy danh sách phiếu nhận xét
  Future<String> getReviewList() async {
    await injectReviewJavaScript();
    final result =
        await controller.runJavaScriptReturningResult('getReviewList()');
    return result.toString().replaceAll('"', '');
  }

  /// Gọi hàm JavaScript để tạo phiếu nhận xét mới
  Future<bool> createNewReview() async {
    final result =
        await controller.runJavaScriptReturningResult('createNewReview()');
    return result.toString() == 'true';
  }

  /// Gọi hàm JavaScript để điền thông tin phiếu nhận xét
  Future<bool> fillReviewForm(Map<String, dynamic> reviewData) async {
    final reviewDataJson = _mapToJsonString(reviewData);
    final result = await controller
        .runJavaScriptReturningResult('fillReviewForm(\'$reviewDataJson\')');
    return result.toString() == 'true';
  }

  /// Gọi hàm JavaScript để gửi phiếu nhận xét
  Future<bool> submitReviewForm() async {
    final result =
        await controller.runJavaScriptReturningResult('submitReviewForm()');
    return result.toString() == 'true';
  }

  /// Chuyển đổi Map thành chuỗi JSON
  String _mapToJsonString(Map<String, dynamic> map) {
    return map
        .toString()
        .replaceAll('{', '{')
        .replaceAll('}', '}')
        .replaceAll(', ', ',')
        .replaceAll(': ', ':');
  }
}
