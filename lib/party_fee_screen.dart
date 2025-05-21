import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'js_bridge_util.dart';

class PartyFeeScreen extends StatefulWidget {
  final String initialUrl;
  
  const PartyFeeScreen({
    Key? key, 
    required this.initialUrl,
  }) : super(key: key);

  @override
  State<PartyFeeScreen> createState() => _PartyFeeScreenState();
}

class _PartyFeeScreenState extends State<PartyFeeScreen> {
  late WebViewController _webViewController;
  late JsBridgeUtil _jsBridgeUtil;
  bool _isLoading = true;
  List<Map<String, dynamic>> _feeItems = [];
  Map<String, dynamic>? _selectedFee;
  
  @override
  void initState() {
    super.initState();
    _initWebView();
  }
  
  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) async {
            _jsBridgeUtil = JsBridgeUtil(_webViewController);
            await _jsBridgeUtil.setupJavaScriptHandlers();
            
            // Lấy danh sách đảng phí
            await _loadPartyFeeList();
            
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Lỗi: ${error.description}')),
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }
  
  Future<void> _loadPartyFeeList() async {
    try {
      final feeListJson = await _jsBridgeUtil.getPartyFeeList();
      if (feeListJson.isNotEmpty && feeListJson != '[]') {
        final List<dynamic> feeList = _parseJsonList(feeListJson);
        setState(() {
          _feeItems = feeList.map((item) => item as Map<String, dynamic>).toList();
        });
      } else {
        // Tạo dữ liệu mẫu nếu không lấy được từ trang web
        setState(() {
          _feeItems = [
            {
              'id': '1',
              'name': 'Đảng phí tháng 5/2025',
              'amount': '120.000 VNĐ',
              'dueDate': '31/05/2025',
              'status': 'Chưa nộp'
            },
            {
              'id': '2',
              'name': 'Đảng phí tháng 4/2025',
              'amount': '120.000 VNĐ',
              'dueDate': '30/04/2025',
              'status': 'Đã nộp'
            },
            {
              'id': '3',
              'name': 'Đảng phí tháng 3/2025',
              'amount': '120.000 VNĐ',
              'dueDate': '31/03/2025',
              'status': 'Đã nộp'
            },
          ];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lấy danh sách đảng phí: $e')),
      );
      // Tạo dữ liệu mẫu nếu có lỗi
      setState(() {
        _feeItems = [
          {
            'id': '1',
            'name': 'Đảng phí tháng 5/2025',
            'amount': '120.000 VNĐ',
            'dueDate': '31/05/2025',
            'status': 'Chưa nộp'
          },
        ];
      });
    }
  }
  
  List<dynamic> _parseJsonList(String jsonString) {
    // Xử lý chuỗi JSON và chuyển đổi thành List
    try {
      // Loại bỏ các ký tự đặc biệt nếu có
      final cleanedJson = jsonString
          .replaceAll('\\', '')
          .replaceAll('"{', '{')
          .replaceAll('}"', '}');
      
      // Phân tích chuỗi JSON
      return []; // Placeholder, cần triển khai đầy đủ
    } catch (e) {
      print('Lỗi khi phân tích JSON: $e');
      return [];
    }
  }
  
  Future<void> _selectFee(Map<String, dynamic> fee) async {
    setState(() {
      _selectedFee = fee;
    });
    
    try {
      final result = await _jsBridgeUtil.selectPartyFee(fee['id'].toString());
      if (!result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể chọn đảng phí này')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }
  
  Future<void> _proceedToPayment() async {
    if (_selectedFee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn đảng phí cần nộp')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Hiển thị dialog xác nhận thanh toán
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xác nhận thanh toán'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Đảng phí: ${_selectedFee!['name']}'),
              Text('Số tiền: ${_selectedFee!['amount']}'),
              Text('Hạn nộp: ${_selectedFee!['dueDate']}'),
              const SizedBox(height: 16),
              const Text('Chọn phương thức thanh toán:'),
              const SizedBox(height: 8),
              _buildPaymentMethodItem(
                icon: Icons.account_balance,
                title: 'Chuyển khoản ngân hàng',
                onTap: () => _confirmPayment('bank'),
              ),
              _buildPaymentMethodItem(
                icon: Icons.credit_card,
                title: 'Thẻ tín dụng/ghi nợ',
                onTap: () => _confirmPayment('card'),
              ),
              _buildPaymentMethodItem(
                icon: Icons.wallet,
                title: 'Ví điện tử',
                onTap: () => _confirmPayment('ewallet'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
          ],
        ),
      );
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    }
  }
  
  Future<void> _confirmPayment(String method) async {
    Navigator.pop(context); // Đóng dialog
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Điền thông tin thanh toán
      final paymentInfo = {
        'method': method,
        'amount': _selectedFee!['amount'],
        'feeId': _selectedFee!['id'],
      };
      
      final fillResult = await _jsBridgeUtil.fillPaymentInfo(paymentInfo);
      
      if (fillResult) {
        // Xác nhận thanh toán
        final confirmResult = await _jsBridgeUtil.confirmPayment();
        
        if (confirmResult) {
          // Hiển thị thông báo thành công
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thanh toán thành công')),
          );
          
          // Cập nhật lại danh sách đảng phí
          await _loadPartyFeeList();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể xác nhận thanh toán')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể điền thông tin thanh toán')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Widget _buildPaymentMethodItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 16),
            Text(title),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nộp đảng phí'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPartyFeeList,
          ),
        ],
      ),
      body: Stack(
        children: [
          // WebView ẩn để tương tác với trang web
          Opacity(
            opacity: 0.0, // Ẩn WebView
            child: WebViewWidget(controller: _webViewController),
          ),
          
          // Giao diện native
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Danh sách đảng phí',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _feeItems.isEmpty
                      ? const Center(child: Text('Không có đảng phí nào'))
                      : ListView.builder(
                          itemCount: _feeItems.length,
                          itemBuilder: (context, index) {
                            final fee = _feeItems[index];
                            final isSelected = _selectedFee != null && 
                                              _selectedFee!['id'] == fee['id'];
                            final isUnpaid = fee['status'] == 'Chưa nộp';
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: isSelected ? Colors.blue.shade50 : null,
                              child: ListTile(
                                title: Text(fee['name'] ?? 'Đảng phí'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Số tiền: ${fee['amount'] ?? '0 VNĐ'}'),
                                    Text('Hạn nộp: ${fee['dueDate'] ?? 'N/A'}'),
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isUnpaid ? Colors.red.shade100 : Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    fee['status'] ?? 'Không xác định',
                                    style: TextStyle(
                                      color: isUnpaid ? Colors.red : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                onTap: isUnpaid ? () => _selectFee(fee) : null,
                                enabled: isUnpaid,
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _selectedFee != null ? _proceedToPayment : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('TIẾN HÀNH THANH TOÁN'),
                ),
              ],
            ),
          ),
          
          // Hiển thị loading indicator
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
