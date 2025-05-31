import 'package:flutter/material.dart';
import 'menu_widgets.dart'; // Import AppConfig

class ProceduresScreen extends StatelessWidget {
  final Function(String) onNavigateToUrl;
  final bool isLoggedIn;
  final VoidCallback onLoginRequired;

  const ProceduresScreen({
    Key? key,
    required this.onNavigateToUrl,
    required this.isLoggedIn,
    required this.onLoginRequired,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              // _buildHeaderSection(context, colorScheme),
              // const SizedBox(height: 24),

              // Authentication Status
              _buildAuthenticationStatus(context, colorScheme),
              const SizedBox(height: 24),

              // Main Procedure Buttons
              _buildProcedureButtons(context, colorScheme),
              const SizedBox(height: 24),

              // Info Section
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthenticationStatus(
      BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isLoggedIn ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: isLoggedIn ? Colors.green : Colors.orange,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLoggedIn ? Icons.verified_user : Icons.warning_amber,
            color: isLoggedIn ? Colors.green : Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isLoggedIn
                  ? 'Đã đăng nhập - Có thể truy cập tất cả thủ tục'
                  : 'Cần đăng nhập để truy cập các thủ tục',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isLoggedIn ? Colors.green[700] : Colors.orange[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcedureButtons(BuildContext context, ColorScheme colorScheme) {
    final procedures = [
      {
        'title': 'Danh Sách Đảng Phí',
        'subtitle': 'Xem danh sách và lịch sử nộp Đảng phí',
        'icon': Icons.list_alt,
        'color': Colors.blue,
        'url': AppConfig.partyFeeIndexUrl,
        'requiresLogin': true,
      },
      {
        'title': 'Tự Tạo Đảng Phí',
        'subtitle': 'Tạo mới phiếu thu Đảng phí cá nhân',
        'icon': Icons.add_box,
        'color': Colors.green,
        'url': AppConfig.selfCreatePartyFeeUrl,
        'requiresLogin': true,
      },
      {
        'title': 'Chi Bộ Tạo Đảng Phí',
        'subtitle': 'Chi bộ tạo phiếu thu cho đảng viên',
        'icon': Icons.group_add,
        'color': Colors.orange,
        'url': AppConfig.cellCreatePartyFeeUrl,
        'requiresLogin': true,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Các Thủ Tục Khả Dụng',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        ...procedures
            .map((procedure) =>
                _buildProcedureCard(context, procedure, colorScheme))
            .toList(),
      ],
    );
  }

  Widget _buildProcedureCard(BuildContext context,
      Map<String, dynamic> procedure, ColorScheme colorScheme) {
    final bool requiresLogin = procedure['requiresLogin'] as bool;
    final bool isDisabled = requiresLogin && !isLoggedIn;
    final Color procedureColor = procedure['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Material(
        elevation: isDisabled ? 1.0 : 4.0,
        borderRadius: BorderRadius.circular(16.0),
        color: isDisabled ? Colors.grey[100] : Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.0),
          onTap: isDisabled
              ? () {
                  onLoginRequired();
                }
              : () {
                  onNavigateToUrl(procedure['url'] as String);
                },
          child: Container(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Icon Container
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isDisabled
                        ? Colors.grey[300]
                        : procedureColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30.0),
                  ),
                  child: Icon(
                    procedure['icon'] as IconData,
                    size: 30,
                    color: isDisabled ? Colors.grey[500] : procedureColor,
                  ),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        procedure['title'] as String,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDisabled
                              ? Colors.grey[600]
                              : colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        procedure['subtitle'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDisabled
                              ? Colors.grey[500]
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (requiresLogin) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 14,
                              color: isDisabled
                                  ? Colors.grey[500]
                                  : procedureColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Yêu cầu đăng nhập',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDisabled
                                    ? Colors.grey[500]
                                    : procedureColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Arrow Icon
                Icon(
                  Icons.arrow_forward_ios,
                  size: 20,
                  color: isDisabled
                      ? Colors.grey[400]
                      : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
