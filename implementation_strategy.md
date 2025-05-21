# Chiến lược triển khai: Native vs WebView/JS Bridge

## Tổng quan về chiến lược

Dựa trên yêu cầu của người dùng và phân tích chức năng, chúng ta sẽ sử dụng WebView kết hợp với JavaScript Bridge làm phương pháp chính để triển khai các chức năng. Tuy nhiên, một số thành phần UI có thể được triển khai bằng native Flutter để cải thiện trải nghiệm người dùng.

## Phân tích chi tiết cho từng chức năng

### 1. Chức năng đăng nhập

#### Phương pháp triển khai: Kết hợp Native UI và WebView/JS Bridge

| Thành phần | Phương pháp | Lý do |
|------------|-------------|-------|
| Màn hình chọn phương thức đăng nhập | Native Flutter | Cải thiện UX, dễ dàng tùy chỉnh giao diện |
| Form đăng nhập thông thường | WebView + JS Bridge | Tận dụng xác thực hiện có của web |
| Đăng nhập VneID | WebView + JS Bridge | Cần tích hợp với hệ thống xác thực của VneID |
| Lưu trữ thông tin đăng nhập | Native Flutter | Bảo mật thông tin đăng nhập tốt hơn |

#### Các hàm JS Bridge cần thiết:
- `autoFillLoginForm(username, password)`
- `submitLoginForm()`
- `checkLoginStatus()`
- `initiateVneIDLogin()`

### 2. Chức năng thay đổi/đăng ký thông tin tài khoản

#### Phương pháp triển khai: Chủ yếu WebView/JS Bridge

| Thành phần | Phương pháp | Lý do |
|------------|-------------|-------|
| Hiển thị thông tin tài khoản | WebView + JS Bridge | Tận dụng giao diện hiện có |
| Form cập nhật thông tin | WebView + JS Bridge | Đảm bảo tương thích với validation của web |
| Tải lên tệp/hình ảnh | WebView + JS Bridge | Tận dụng xử lý tệp của web |
| Thông báo kết quả | Native Flutter | Cải thiện UX với thông báo rõ ràng |

#### Các hàm JS Bridge cần thiết:
- `getUserProfile()`
- `updateUserProfile(profileDataJson)`
- `uploadFile(fileInputId)`

### 3. Chức năng nộp đảng phí (03 giao diện)

#### Phương pháp triển khai: Kết hợp Native UI và WebView/JS Bridge

| Thành phần | Phương pháp | Lý do |
|------------|-------------|-------|
| Danh sách đảng phí | Native Flutter | Cải thiện UX với giao diện tối ưu cho mobile |
| Chi tiết đảng phí | Native Flutter | Hiển thị thông tin rõ ràng, dễ đọc |
| Form thanh toán | WebView + JS Bridge | Tận dụng hệ thống thanh toán hiện có |
| Xác nhận thanh toán | WebView + JS Bridge | Đảm bảo tính bảo mật của giao dịch |
| Biên lai/hóa đơn | Native Flutter | Hiển thị và lưu trữ biên lai tốt hơn |

#### Các hàm JS Bridge cần thiết:
- `getPartyFeeList()`
- `selectPartyFee(feeId)`
- `fillPaymentInfo(paymentInfoJson)`
- `confirmPayment()`
- `getReceiptInfo()`

### 4. Chức năng lập phiếu nhận xét

#### Phương pháp triển khai: Chủ yếu WebView/JS Bridge

| Thành phần | Phương pháp | Lý do |
|------------|-------------|-------|
| Danh sách phiếu nhận xét | Native Flutter | Cải thiện UX với giao diện tối ưu cho mobile |
| Form tạo/cập nhật phiếu | WebView + JS Bridge | Tận dụng validation và xử lý form hiện có |
| Xem chi tiết phiếu | WebView + JS Bridge | Đảm bảo hiển thị đúng định dạng |
| Thông báo kết quả | Native Flutter | Cải thiện UX với thông báo rõ ràng |

#### Các hàm JS Bridge cần thiết:
- `getReviewList()`
- `createNewReview()`
- `fillReviewForm(reviewDataJson)`
- `submitReviewForm()`
- `getReviewDetails(reviewId)`

### 5. Chức năng báo cáo thống kê

#### Phương pháp triển khai: Chủ yếu WebView/JS Bridge

| Thành phần | Phương pháp | Lý do |
|------------|-------------|-------|
| Danh sách báo cáo | Native Flutter | Cải thiện UX với giao diện tối ưu cho mobile |
| Bộ lọc báo cáo | Native Flutter | Giao diện lọc tối ưu cho mobile |
| Hiển thị báo cáo | WebView + JS Bridge | Tận dụng các biểu đồ và bảng dữ liệu hiện có |
| Xuất báo cáo | WebView + JS Bridge | Tận dụng chức năng xuất báo cáo hiện có |

#### Các hàm JS Bridge cần thiết:
- `getReportList()`
- `viewReport(reportId)`
- `applyReportFilters(filtersJson)`
- `exportReport(format)`
- `getReportData()`

## Chiến lược triển khai tổng thể

1. **Giai đoạn 1: Thiết lập cơ sở hạ tầng**
   - Cập nhật ứng dụng Flutter WebView hiện có
   - Thiết lập JavaScript Bridge cơ bản
   - Tạo các lớp tiện ích để quản lý tương tác JS Bridge

2. **Giai đoạn 2: Triển khai đăng nhập**
   - Tạo màn hình chọn phương thức đăng nhập native
   - Triển khai JS Bridge cho đăng nhập thông thường
   - Triển khai JS Bridge cho đăng nhập VneID
   - Xử lý lưu trữ thông tin đăng nhập

3. **Giai đoạn 3: Triển khai nộp đảng phí**
   - Tạo giao diện native cho danh sách đảng phí
   - Triển khai JS Bridge cho thanh toán
   - Xử lý biên lai và thông báo kết quả

4. **Giai đoạn 4: Triển khai lập phiếu nhận xét**
   - Tạo giao diện native cho danh sách phiếu
   - Triển khai JS Bridge cho tạo và gửi phiếu

5. **Giai đoạn 5: Triển khai thay đổi thông tin tài khoản**
   - Triển khai JS Bridge cho xem và cập nhật thông tin

6. **Giai đoạn 6: Triển khai báo cáo thống kê**
   - Tạo giao diện native cho danh sách báo cáo
   - Triển khai JS Bridge cho xem và xuất báo cáo

## Ưu tiên triển khai

1. Đăng nhập (bao gồm VneID)
2. Nộp đảng phí
3. Lập phiếu nhận xét
4. Thay đổi/đăng ký thông tin tài khoản
5. Báo cáo thống kê

## Kết luận

Chiến lược này tận dụng ưu điểm của cả WebView/JS Bridge và native UI để cung cấp trải nghiệm người dùng tốt nhất có thể trong khi vẫn tận dụng được hệ thống web hiện có. Các thành phần hiển thị và tương tác chính sẽ được triển khai bằng native Flutter để cải thiện UX, trong khi các chức năng xử lý dữ liệu và tương tác với backend sẽ được thực hiện thông qua WebView và JavaScript Bridge.
