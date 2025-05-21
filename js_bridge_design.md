# Thiết kế JavaScript Bridge cho ứng dụng Flutter WebView

## Tổng quan về JavaScript Bridge

JavaScript Bridge là cơ chế cho phép giao tiếp hai chiều giữa mã JavaScript chạy trong WebView và mã Dart/Flutter chạy trong ứng dụng. Điều này cho phép:

1. Flutter gọi các hàm JavaScript để tương tác với trang web
2. JavaScript gửi dữ liệu và sự kiện về cho Flutter
3. Chia sẻ dữ liệu giữa WebView và ứng dụng native

## Thiết kế JavaScript Bridge cho từng chức năng

### 1. Chức năng đăng nhập

#### Từ Flutter đến JavaScript:
```javascript
// Tự động điền thông tin đăng nhập
function autoFillLoginForm(username, password) {
  document.querySelector('input[name="username"]').value = username;
  document.querySelector('input[name="password"]').value = password;
  return true;
}

// Tự động nhấn nút đăng nhập
function submitLoginForm() {
  document.querySelector('button[type="submit"]').click();
  return true;
}

// Kiểm tra trạng thái đăng nhập
function checkLoginStatus() {
  // Kiểm tra các phần tử DOM hoặc cookie để xác định trạng thái đăng nhập
  const isLoggedIn = document.querySelector('.user-profile') !== null;
  return isLoggedIn;
}

// Xử lý đăng nhập VneID
function initiateVneIDLogin() {
  // Tìm và nhấp vào nút đăng nhập VneID
  document.querySelector('a[href*="vneid"]').click();
  return true;
}
```

#### Từ JavaScript đến Flutter:
```javascript
// Thông báo kết quả đăng nhập
function notifyLoginResult(success, message) {
  window.flutter_inappwebview.callHandler('loginResultHandler', success, message);
}

// Gửi thông tin phiên đăng nhập
function sendSessionInfo(token, expiry) {
  window.flutter_inappwebview.callHandler('sessionInfoHandler', token, expiry);
}
```

### 2. Chức năng thay đổi/đăng ký thông tin tài khoản

#### Từ Flutter đến JavaScript:
```javascript
// Lấy thông tin tài khoản hiện tại
function getUserProfile() {
  const profileData = {};
  // Lấy các trường thông tin từ form hoặc trang hiển thị
  const formElements = document.querySelectorAll('#profile-form input, #profile-form select');
  formElements.forEach(el => {
    profileData[el.name] = el.value;
  });
  return JSON.stringify(profileData);
}

// Cập nhật thông tin tài khoản
function updateUserProfile(profileDataJson) {
  const profileData = JSON.parse(profileDataJson);
  // Điền thông tin vào form
  Object.keys(profileData).forEach(key => {
    const el = document.querySelector(`#profile-form [name="${key}"]`);
    if (el) el.value = profileData[key];
  });
  // Gửi form
  document.querySelector('#profile-form button[type="submit"]').click();
  return true;
}
```

#### Từ JavaScript đến Flutter:
```javascript
// Thông báo kết quả cập nhật
function notifyProfileUpdateResult(success, message) {
  window.flutter_inappwebview.callHandler('profileUpdateResultHandler', success, message);
}
```

### 3. Chức năng nộp đảng phí

#### Từ Flutter đến JavaScript:
```javascript
// Lấy danh sách đảng phí cần nộp
function getPartyFeeList() {
  const feeItems = [];
  // Lấy các mục đảng phí từ bảng hoặc danh sách
  const feeElements = document.querySelectorAll('.party-fee-item');
  feeElements.forEach(el => {
    feeItems.push({
      id: el.getAttribute('data-id'),
      name: el.querySelector('.fee-name').textContent,
      amount: el.querySelector('.fee-amount').textContent,
      dueDate: el.querySelector('.fee-due-date').textContent,
      status: el.querySelector('.fee-status').textContent
    });
  });
  return JSON.stringify(feeItems);
}

// Chọn đảng phí để thanh toán
function selectPartyFee(feeId) {
  document.querySelector(`.party-fee-item[data-id="${feeId}"] .select-button`).click();
  return true;
}

// Điền thông tin thanh toán
function fillPaymentInfo(paymentInfoJson) {
  const paymentInfo = JSON.parse(paymentInfoJson);
  // Điền thông tin vào form thanh toán
  Object.keys(paymentInfo).forEach(key => {
    const el = document.querySelector(`#payment-form [name="${key}"]`);
    if (el) el.value = paymentInfo[key];
  });
  return true;
}

// Xác nhận thanh toán
function confirmPayment() {
  document.querySelector('#payment-form button[type="submit"]').click();
  return true;
}
```

#### Từ JavaScript đến Flutter:
```javascript
// Thông báo kết quả thanh toán
function notifyPaymentResult(success, transactionId, message) {
  window.flutter_inappwebview.callHandler('paymentResultHandler', success, transactionId, message);
}

// Gửi thông tin biên lai
function sendReceiptInfo(receiptUrl, receiptId) {
  window.flutter_inappwebview.callHandler('receiptInfoHandler', receiptUrl, receiptId);
}
```

### 4. Chức năng lập phiếu nhận xét

#### Từ Flutter đến JavaScript:
```javascript
// Lấy danh sách phiếu nhận xét
function getReviewList() {
  const reviews = [];
  // Lấy các phiếu nhận xét từ bảng hoặc danh sách
  const reviewElements = document.querySelectorAll('.review-item');
  reviewElements.forEach(el => {
    reviews.push({
      id: el.getAttribute('data-id'),
      title: el.querySelector('.review-title').textContent,
      date: el.querySelector('.review-date').textContent,
      status: el.querySelector('.review-status').textContent
    });
  });
  return JSON.stringify(reviews);
}

// Tạo phiếu nhận xét mới
function createNewReview() {
  document.querySelector('.create-review-button').click();
  return true;
}

// Điền thông tin phiếu nhận xét
function fillReviewForm(reviewDataJson) {
  const reviewData = JSON.parse(reviewDataJson);
  // Điền thông tin vào form
  Object.keys(reviewData).forEach(key => {
    const el = document.querySelector(`#review-form [name="${key}"]`);
    if (el) {
      if (el.tagName === 'TEXTAREA') {
        el.textContent = reviewData[key];
      } else {
        el.value = reviewData[key];
      }
    }
  });
  return true;
}

// Gửi phiếu nhận xét
function submitReviewForm() {
  document.querySelector('#review-form button[type="submit"]').click();
  return true;
}
```

#### Từ JavaScript đến Flutter:
```javascript
// Thông báo kết quả gửi phiếu nhận xét
function notifyReviewSubmitResult(success, reviewId, message) {
  window.flutter_inappwebview.callHandler('reviewSubmitResultHandler', success, reviewId, message);
}
```

### 5. Chức năng báo cáo thống kê

#### Từ Flutter đến JavaScript:
```javascript
// Lấy danh sách báo cáo có sẵn
function getReportList() {
  const reports = [];
  // Lấy các báo cáo từ danh sách
  const reportElements = document.querySelectorAll('.report-item');
  reportElements.forEach(el => {
    reports.push({
      id: el.getAttribute('data-id'),
      name: el.querySelector('.report-name').textContent,
      type: el.querySelector('.report-type').textContent
    });
  });
  return JSON.stringify(reports);
}

// Xem báo cáo cụ thể
function viewReport(reportId) {
  document.querySelector(`.report-item[data-id="${reportId}"] .view-button`).click();
  return true;
}

// Áp dụng bộ lọc cho báo cáo
function applyReportFilters(filtersJson) {
  const filters = JSON.parse(filtersJson);
  // Áp dụng các bộ lọc
  Object.keys(filters).forEach(key => {
    const el = document.querySelector(`#report-filters [name="${key}"]`);
    if (el) el.value = filters[key];
  });
  // Nhấn nút áp dụng
  document.querySelector('#report-filters .apply-button').click();
  return true;
}

// Xuất báo cáo
function exportReport(format) {
  document.querySelector(`.export-${format}-button`).click();
  return true;
}
```

#### Từ JavaScript đến Flutter:
```javascript
// Gửi dữ liệu báo cáo
function sendReportData(reportData) {
  window.flutter_inappwebview.callHandler('reportDataHandler', reportData);
}

// Thông báo kết quả xuất báo cáo
function notifyExportResult(success, fileUrl, message) {
  window.flutter_inappwebview.callHandler('exportResultHandler', success, fileUrl, message);
}
```

## Triển khai JavaScript Bridge trong Flutter

```dart
// Thiết lập JavaScript Bridge
void setupJavaScriptBridge(InAppWebViewController controller) {
  // Đăng ký các handler từ JavaScript đến Flutter
  controller.addJavaScriptHandler(
    handlerName: 'loginResultHandler',
    callback: (args) {
      final success = args[0];
      final message = args[1];
      // Xử lý kết quả đăng nhập
    },
  );
  
  controller.addJavaScriptHandler(
    handlerName: 'sessionInfoHandler',
    callback: (args) {
      final token = args[0];
      final expiry = args[1];
      // Lưu thông tin phiên
    },
  );
  
  // Đăng ký các handler khác...
}

// Gọi JavaScript từ Flutter
Future<void> autoFillLogin(InAppWebViewController controller, String username, String password) async {
  await controller.evaluateJavascript(
    source: 'autoFillLoginForm("$username", "$password")',
  );
}

Future<void> submitLogin(InAppWebViewController controller) async {
  await controller.evaluateJavascript(
    source: 'submitLoginForm()',
  );
}

// Triển khai các hàm gọi JavaScript khác...
```

## Chiến lược triển khai

1. **Bước 1**: Nhúng các script JavaScript vào trang web
   - Sử dụng `controller.evaluateJavascript()` để chèn các hàm JavaScript cần thiết
   - Hoặc sử dụng `controller.injectJavascriptFileFromAsset()` để tải script từ tệp

2. **Bước 2**: Thiết lập các handler trong Flutter
   - Đăng ký các callback để xử lý dữ liệu từ JavaScript

3. **Bước 3**: Tạo các hàm tiện ích trong Flutter
   - Bọc các lệnh gọi JavaScript trong các hàm Dart dễ sử dụng

4. **Bước 4**: Xây dựng giao diện người dùng Flutter
   - Tạo các màn hình và widget tương ứng với từng chức năng
   - Kết nối UI với các hàm JavaScript Bridge

## Lưu ý quan trọng

1. Cần đảm bảo các selector DOM chính xác cho từng trang web
2. Xử lý các trường hợp khi trang web thay đổi cấu trúc
3. Thêm xử lý lỗi và timeout cho các lệnh gọi JavaScript
4. Cân nhắc sử dụng thư viện hỗ trợ như `flutter_inappwebview` để dễ dàng triển khai JavaScript Bridge
5. Kiểm tra kỹ lưỡng trên cả Android và iOS
