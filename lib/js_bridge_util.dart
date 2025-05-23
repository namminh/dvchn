import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

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
        if (window.flutter_inappwebview) { // Cần sửa cho webview_flutter
          window.flutter_inappwebview.callHandler('loginResultHandler', success, message);
        } else {
          console.warn('flutter_inappwebview not available for loginResultHandler');
        }
      },
      
      // Gửi thông tin phiên đăng nhập
      sendSessionInfo: function(token, expiry) {
        if (window.flutter_inappwebview) { // Cần sửa cho webview_flutter
          window.flutter_inappwebview.callHandler('sessionInfoHandler', token, expiry);
        } else {
          console.warn('flutter_inappwebview not available for sessionInfoHandler');
        }
      },
      
      // Thông báo kết quả cập nhật thông tin tài khoản
      notifyProfileUpdateResult: function(success, message) {
        if (window.flutter_inappwebview) { // Cần sửa cho webview_flutter
          window.flutter_inappwebview.callHandler('profileUpdateResultHandler', success, message);
        } else {
          console.warn('flutter_inappwebview not available for profileUpdateResultHandler');
        }
      },
      
      // Thông báo kết quả thanh toán
      notifyPaymentResult: function(success, transactionId, message) {
        if (window.flutter_inappwebview) { // Cần sửa cho webview_flutter
          window.flutter_inappwebview.callHandler('paymentResultHandler', success, transactionId, message);
        } else {
          console.warn('flutter_inappwebview not available for paymentResultHandler');
        }
      },
      
      // Gửi thông tin biên lai
      sendReceiptInfo: function(receiptUrl, receiptId) {
        if (window.flutter_inappwebview) { // Cần sửa cho webview_flutter
          window.flutter_inappwebview.callHandler('receiptInfoHandler', receiptUrl, receiptId);
        } else {
          console.warn('flutter_inappwebview not available for receiptInfoHandler');
        }
      },
      
      // Thông báo kết quả gửi phiếu nhận xét
      notifyReviewSubmitResult: function(success, reviewId, message) {
        if (window.flutter_inappwebview) { // Cần sửa cho webview_flutter
          window.flutter_inappwebview.callHandler('reviewSubmitResultHandler', success, reviewId, message);
        } else {
          console.warn('flutter_inappwebview not available for reviewSubmitResultHandler');
        }
      },
      
      // Gửi dữ liệu báo cáo
      sendReportData: function(reportData) {
        if (window.flutter_inappwebview) { // Cần sửa cho webview_flutter
          window.flutter_inappwebview.callHandler('reportDataHandler', reportData);
        } else {
          console.warn('flutter_inappwebview not available for reportDataHandler');
        }
      }
    };
    
    // Hàm kiểm tra trạng thái đăng nhập
    function checkLoginStatus() {
      try {
        // Không nên chạy hàm này trên các domain ngoài (như SSO)
        // Nếu đang ở domain của bạn, bạn có thể thêm các kiểm tra phức tạp hơn
        // Ví dụ: kiểm tra cookie, localStorage, hoặc một element đặc trưng
        
        // Phương pháp 1: Kiểm tra URL - sau khi đăng nhập sẽ chuyển hướng đến trang chủ
        // Điều này có thể không đáng tin cậy nếu URL trang chủ có thể truy cập mà không cần đăng nhập
        if (window.location.pathname.toLowerCase().includes('/home') || window.location.pathname === '/') {
           // Thêm kiểm tra khác để chắc chắn đã đăng nhập, ví dụ: sự tồn tại của nút logout
           const logoutButton = document.querySelector('a[href*="logout"], button[onclick*="logout"]');
           if (logoutButton) return true;
        }
        
        // Phương pháp 2: Kiểm tra sự hiện diện của thông tin người dùng hoặc liên kết tài khoản
        // Cần làm cho các selector này mạnh mẽ hơn và tránh lỗi
        let accountElement = document.querySelector('a[href*="Account/Manage"], a[href*="Profile"]');
        if (accountElement) return true;

        // Tìm kiếm text nhạy cảm với trường hợp chữ và tránh lỗi nếu không tìm thấy
        const userElements = document.querySelectorAll('body *'); // Tìm trong toàn bộ body
        for (let i = 0; i < userElements.length; i++) {
          if (userElements[i] && userElements[i].textContent) {
            const textContent = userElements[i].textContent.trim();
            // Các từ khóa nhạy cảm cho biết đã đăng nhập
            if (textContent.includes('Thông tin tài khoản') || textContent.includes('Xin chào') || textContent.includes('Đăng xuất')) {
               // Kiểm tra thêm để đảm bảo đây không phải là link "Đăng nhập"
               if (userElements[i].tagName !== 'A' || !userElements[i].href || !userElements[i].href.toLowerCase().includes('login')) {
                 return true;
               }
            }
          }
        }
        
        // Mặc định là chưa đăng nhập nếu không tìm thấy dấu hiệu nào
        return false;
      } catch (e) {
        console.error('Error in checkLoginStatus:', e.toString());
        return false; // Trả về false nếu có lỗi
      }
    }
    
    // Hàm tiện ích cho đăng nhập
    function autoFillLoginForm(username, password) {
      try {
        let usernameInput = document.querySelector('input[name="username"], input[name="UserName"], input#username, input#UserName');
        let passwordInput = document.querySelector('input[name="password"], input[name="Password"], input#password, input#Password');
        
        // Thử các selector phổ biến khác nếu không tìm thấy
        if (!usernameInput) {
          const inputs = document.querySelectorAll('input[type="text"], input[type="email"]');
          for (let i = 0; i < inputs.length; i++) {
            if (inputs[i].offsetParent !== null) { // Check if visible
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
        
        return !!(usernameInput && passwordInput); // Trả về true nếu cả hai trường được tìm thấy
      } catch (e) {
        console.error('Error in autoFillLoginForm:', e.toString());
        return false;
      }
    }
    
    function submitLoginForm() {
      try {
        let submitButton = document.querySelector('button[type="submit"], input[type="submit"]');
        if (!submitButton) {
            const buttons = document.querySelectorAll('button');
            for(let i = 0; i < buttons.length; i++) {
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
        console.error('Error in submitLoginForm:', e.toString());
        return false;
      }
    }
    
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
        console.error('Error in initiateVneIDLogin:', e.toString());
        return false;
      }
    }
    
    // Đăng ký các hàm vào window để có thể gọi từ Flutter
    window.autoFillLoginForm = autoFillLoginForm;
    window.submitLoginForm = submitLoginForm;
    window.checkLoginStatus = checkLoginStatus;
    window.initiateVneIDLogin = initiateVneIDLogin;
    
    console.log('JavaScript Bridge (base functions) has been initialized');
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
        // LƯU Ý: Các selector '.party-fee-item', '.fee-name' v.v. cần khớp với cấu trúc HTML thực tế của trang web
        const feeElements = document.querySelectorAll('.party-fee-item'); // Ví dụ selector
        feeElements.forEach(el => {
          feeItems.push({
            id: el.getAttribute('data-id'), // Ví dụ lấy id
            name: el.querySelector('.fee-name')?.textContent.trim(),
            amount: el.querySelector('.fee-amount')?.textContent.trim(),
            dueDate: el.querySelector('.fee-due-date')?.textContent.trim(),
            status: el.querySelector('.fee-status')?.textContent.trim()
          });
        });
        return JSON.stringify(feeItems);
      } catch (e) {
        console.error('Error in getPartyFeeList:', e.toString());
        return '[]'; // Trả về mảng rỗng dạng chuỗi nếu lỗi
      }
    }
    
    // Chọn đảng phí để thanh toán
    function selectPartyFee(feeId) {
      try {
        // LƯU Ý: Selector cần khớp với HTML
        const feeElement = document.querySelector(`.party-fee-item[data-id="\${feeId}"]`);
        if (feeElement) {
          const selectButton = feeElement.querySelector('.select-button'); // Ví dụ
          if (selectButton) {
            selectButton.click();
            return true;
          }
        }
        return false;
      } catch (e) {
        console.error('Error in selectPartyFee:', e.toString());
        return false;
      }
    }
    
    // Điền thông tin thanh toán
    function fillPaymentInfo(paymentInfoJson) {
      try {
        const paymentInfo = JSON.parse(paymentInfoJson);
        // LƯU Ý: Selector cần khớp với HTML của form thanh toán
        Object.keys(paymentInfo).forEach(key => {
          const el = document.querySelector(`#payment-form [name="\${key}"]`); // Ví dụ
          if (el) el.value = paymentInfo[key];
        });
        return true;
      } catch (e) {
        console.error('Error in fillPaymentInfo:', e.toString());
        return false;
      }
    }
    
    // Xác nhận thanh toán
    function confirmPayment() {
      try {
        // LƯU Ý: Selector cần khớp với HTML
        const confirmButton = document.querySelector('#payment-form button[type="submit"]'); // Ví dụ
        if (confirmButton) {
          confirmButton.click();
          return true;
        }
        return false;
      } catch (e) {
        console.error('Error in confirmPayment:', e.toString());
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
        // LƯU Ý: Các selector cần khớp với HTML thực tế
        const reviewElements = document.querySelectorAll('.review-item'); // Ví dụ
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
        console.error('Error in getReviewList:', e.toString());
        return '[]';
      }
    }
    
    // Tạo phiếu nhận xét mới
    function createNewReview() {
      try {
        // LƯU Ý: Selector cần khớp với HTML
        const createButton = document.querySelector('.create-review-button'); // Ví dụ
        if (createButton) {
          createButton.click();
          return true;
        }
        return false;
      } catch (e) {
        console.error('Error in createNewReview:', e.toString());
        return false;
      }
    }
    
    // Điền thông tin phiếu nhận xét
    function fillReviewForm(reviewDataJson) {
      try {
        const reviewData = JSON.parse(reviewDataJson);
        // LƯU Ý: Selector cần khớp với HTML của form
        Object.keys(reviewData).forEach(key => {
          const el = document.querySelector(`#review-form [name="\${key}"]`); // Ví dụ
          if (el) {
            if (el.tagName === 'TEXTAREA') {
              el.textContent = reviewData[key]; // Hoặc el.value tùy thuộc vào cách trang web xử lý textarea
            } else {
              el.value = reviewData[key];
            }
          }
        });
        return true;
      } catch (e) {
        console.error('Error in fillReviewForm:', e.toString());
        return false;
      }
    }
    
    // Gửi phiếu nhận xét
    function submitReviewForm() {
      try {
        // LƯU Ý: Selector cần khớp với HTML
        const submitButton = document.querySelector('#review-form button[type="submit"]'); // Ví dụ
        if (submitButton) {
          submitButton.click();
          return true;
        }
        return false;
      } catch (e) {
        console.error('Error in submitReviewForm:', e.toString());
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
    try {
      final result = await controller.runJavaScriptReturningResult(
          'autoFillLoginForm("$username", "$password")');
      return result.toString() == 'true';
    } catch (e) {
      print('Dart: Error calling autoFillLoginForm: $e');
      return false;
    }
  }

  /// Gọi hàm JavaScript để gửi form đăng nhập
  Future<bool> submitLogin() async {
    try {
      final result =
          await controller.runJavaScriptReturningResult('submitLoginForm()');
      return result.toString() == 'true';
    } catch (e) {
      print('Dart: Error calling submitLoginForm: $e');
      return false;
    }
  }

  /// Gọi hàm JavaScript để kiểm tra trạng thái đăng nhập
  Future<bool> checkLoginStatus() async {
    // Chỉ nên gọi hàm này trên domain của bạn, không phải trang SSO
    // Thêm kiểm tra domain ở đây hoặc ở HomeScreen trước khi gọi
    try {
      final result =
          await controller.runJavaScriptReturningResult('checkLoginStatus()');
      print('Dart: checkLoginStatus JS result: $result');
      return result.toString() == 'true';
    } catch (e) {
      print('Dart: Error calling checkLoginStatus: $e');
      return false;
    }
  }

  /// Gọi hàm JavaScript để bắt đầu đăng nhập qua VneID
  Future<bool> initiateVneIDLogin() async {
    try {
      final result =
          await controller.runJavaScriptReturningResult('initiateVneIDLogin()');
      return result.toString() == 'true';
    } catch (e) {
      print('Dart: Error calling initiateVneIDLogin: $e');
      return false;
    }
  }

  /// Gọi hàm JavaScript để lấy danh sách đảng phí
  Future<String> getPartyFeeList() async {
    try {
      await injectPartyFeeJavaScript(); // Đảm bảo inject script trước khi gọi
      final result =
          await controller.runJavaScriptReturningResult('getPartyFeeList()');
      // Chuyển đổi từ Object (trên iOS) hoặc String (trên Android) về String
      return result is String ? result : result.toString();
    } catch (e) {
      print('Dart: Error calling getPartyFeeList: $e');
      return '[]';
    }
  }

  /// Gọi hàm JavaScript để chọn đảng phí thanh toán
  Future<bool> selectPartyFee(String feeId) async {
    try {
      final result = await controller
          .runJavaScriptReturningResult('selectPartyFee("$feeId")');
      return result.toString() == 'true';
    } catch (e) {
      print('Dart: Error calling selectPartyFee: $e');
      return false;
    }
  }

  /// Gọi hàm JavaScript để điền thông tin thanh toán
  Future<bool> fillPaymentInfo(Map<String, dynamic> paymentInfo) async {
    try {
      // JSON encoding an toàn hơn
      final paymentInfoJson = json.encode(paymentInfo);
      final result = await controller.runJavaScriptReturningResult(
          'fillPaymentInfo(\'$paymentInfoJson\')');
      return result.toString() == 'true';
    } catch (e) {
      print('Dart: Error calling fillPaymentInfo: $e');
      return false;
    }
  }

  /// Gọi hàm JavaScript để xác nhận thanh toán
  Future<bool> confirmPayment() async {
    try {
      final result =
          await controller.runJavaScriptReturningResult('confirmPayment()');
      return result.toString() == 'true';
    } catch (e) {
      print('Dart: Error calling confirmPayment: $e');
      return false;
    }
  }

  /// Gọi hàm JavaScript để lấy danh sách phiếu nhận xét
  Future<String> getReviewList() async {
    try {
      await injectReviewJavaScript(); // Đảm bảo inject script trước khi gọi
      final result =
          await controller.runJavaScriptReturningResult('getReviewList()');
      return result is String ? result : result.toString();
    } catch (e) {
      print('Dart: Error calling getReviewList: $e');
      return '[]';
    }
  }

  /// Gọi hàm JavaScript để tạo phiếu nhận xét mới
  Future<bool> createNewReview() async {
    try {
      final result =
          await controller.runJavaScriptReturningResult('createNewReview()');
      return result.toString() == 'true';
    } catch (e) {
      print('Dart: Error calling createNewReview: $e');
      return false;
    }
  }

  /// Gọi hàm JavaScript để điền thông tin phiếu nhận xét
  Future<bool> fillReviewForm(Map<String, dynamic> reviewData) async {
    try {
      final reviewDataJson = json.encode(reviewData); // Sử dụng json.encode
      final result = await controller
          .runJavaScriptReturningResult('fillReviewForm(\'$reviewDataJson\')');
      return result.toString() == 'true';
    } catch (e) {
      print('Dart: Error calling fillReviewForm: $e');
      return false;
    }
  }

  /// Gọi hàm JavaScript để gửi phiếu nhận xét
  Future<bool> submitReviewForm() async {
    try {
      final result =
          await controller.runJavaScriptReturningResult('submitReviewForm()');
      return result.toString() == 'true';
    } catch (e) {
      print('Dart: Error calling submitReviewForm: $e');
      return false;
    }
  }

  // Hàm _mapToJsonString không còn cần thiết nếu dùng json.encode
  // String _mapToJsonString(Map<String, dynamic> map) {
  //   return map
  //       .toString()
  //       .replaceAll('{', '{')
  //       .replaceAll('}', '}')
  //       .replaceAll(', ', ',')
  //       .replaceAll(': ', ':');
  // }
}
