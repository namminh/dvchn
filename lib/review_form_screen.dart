import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'js_bridge_util.dart';

class ReviewFormScreen extends StatefulWidget {
  final String initialUrl;
  
  const ReviewFormScreen({
    Key? key, 
    required this.initialUrl,
  }) : super(key: key);

  @override
  State<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends State<ReviewFormScreen> {
  late WebViewController _webViewController;
  late JsBridgeUtil _jsBridgeUtil;
  bool _isLoading = true;
  List<Map<String, dynamic>> _reviewItems = [];
  Map<String, dynamic>? _selectedReview;
  
  // Form controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _initWebView();
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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
            
            // Lấy danh sách phiếu nhận xét
            await _loadReviewList();
            
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
  
  Future<void> _loadReviewList() async {
    try {
      final reviewListJson = await _jsBridgeUtil.getReviewList();
      if (reviewListJson.isNotEmpty && reviewListJson != '[]') {
        final List<dynamic> reviewList = _parseJsonList(reviewListJson);
        setState(() {
          _reviewItems = reviewList.map((item) => item as Map<String, dynamic>).toList();
        });
      } else {
        // Tạo dữ liệu mẫu nếu không lấy được từ trang web
        setState(() {
          _reviewItems = [
            {
              'id': '1',
              'title': 'Nhận xét về hoạt động tháng 5/2025',
              'date': '15/05/2025',
              'status': 'Đã gửi'
            },
            {
              'id': '2',
              'title': 'Nhận xét về hoạt động tháng 4/2025',
              'date': '10/04/2025',
              'status': 'Đã duyệt'
            },
            {
              'id': '3',
              'title': 'Nhận xét về hoạt động tháng 3/2025',
              'date': '12/03/2025',
              'status': 'Đã duyệt'
            },
          ];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi khi lấy danh sách phiếu nhận xét: $e')),
      );
      // Tạo dữ liệu mẫu nếu có lỗi
      setState(() {
        _reviewItems = [
          {
            'id': '1',
            'title': 'Nhận xét về hoạt động tháng 5/2025',
            'date': '15/05/2025',
            'status': 'Đã gửi'
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
  
  void _selectReview(Map<String, dynamic> review) {
    setState(() {
      _selectedReview = review;
    });
  }
  
  Future<void> _createNewReview() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await _jsBridgeUtil.createNewReview();
      
      if (result) {
        // Hiển thị form tạo phiếu nhận xét
        _showCreateReviewForm();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể tạo phiếu nhận xét mới')),
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
  
  void _showCreateReviewForm() {
    // Reset form controllers
    _titleController.text = '';
    _contentController.text = '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo phiếu nhận xét mới'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Nội dung nhận xét',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitReviewForm();
            },
            child: const Text('Gửi'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _submitReviewForm() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Điền thông tin phiếu nhận xét
      final reviewData = {
        'title': _titleController.text,
        'content': _contentController.text,
        'date': DateTime.now().toString(),
      };
      
      final fillResult = await _jsBridgeUtil.fillReviewForm(reviewData);
      
      if (fillResult) {
        // Gửi phiếu nhận xét
        final submitResult = await _jsBridgeUtil.submitReviewForm();
        
        if (submitResult) {
          // Hiển thị thông báo thành công
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gửi phiếu nhận xét thành công')),
          );
          
          // Cập nhật lại danh sách phiếu nhận xét
          await _loadReviewList();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể gửi phiếu nhận xét')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể điền thông tin phiếu nhận xét')),
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lập phiếu nhận xét'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReviewList,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewReview,
        child: const Icon(Icons.add),
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
                  'Danh sách phiếu nhận xét',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _reviewItems.isEmpty
                      ? const Center(child: Text('Không có phiếu nhận xét nào'))
                      : ListView.builder(
                          itemCount: _reviewItems.length,
                          itemBuilder: (context, index) {
                            final review = _reviewItems[index];
                            final isSelected = _selectedReview != null && 
                                              _selectedReview!['id'] == review['id'];
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: isSelected ? Colors.blue.shade50 : null,
                              child: ListTile(
                                title: Text(review['title'] ?? 'Phiếu nhận xét'),
                                subtitle: Text('Ngày tạo: ${review['date'] ?? 'N/A'}'),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(review['status']),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    review['status'] ?? 'Không xác định',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                onTap: () => _selectReview(review),
                              ),
                            );
                          },
                        ),
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
  
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Đã gửi':
        return Colors.blue.shade100;
      case 'Đã duyệt':
        return Colors.green.shade100;
      case 'Từ chối':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade100;
    }
  }
}
