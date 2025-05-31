// lib/menu_widgets.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

// lib/config.dart

class AppConfig {
  // URL cơ sở của website
  static const String baseUrl = 'http://113.160.48.99:8791';
  // --- Các URL chính của ứng dụng ---
  static const String homeUrl = '$baseUrl/Home';
  static const String loginUrl = '$baseUrl/Account/Login?mobile=1';
  static const String accountInfoUrl =
      '$baseUrl/Account/ThayDoiThongTinTaiKhoan';
  static const String authenticationUrl = '$baseUrl/Account/Authentication';
  // --- Các URL cho chức năng nghiệp vụ ---
  static const String profileUrl = '$baseUrl/KhayHoSoDang/Index';
  static const String guideUrl = '$baseUrl/HuongDanSuDung/Index';
  static const String feedbackUrl = '$baseUrl/Feedback';
  static const String feedbackRequestUrl = '$baseUrl/FeedbackRequest';
  // --- Các URL cho chức năng Nộp Đảng phí ---
  static const String partyFeeIndexUrl = '$baseUrl/NopDangPhi/Index';
  static const String selfCreatePartyFeeUrl = '$baseUrl/NopDangPhi/SelfCreate';
  static const String cellCreatePartyFeeUrl =
      '$baseUrl/NopDangPhi/NopChiBoCreate';
  // --- Các URL liên kết ngoài (Dịch vụ công & VNeID) ---
  static const String aboutUrl = '#'; // Giữ chỗ cho trang giới thiệu
  static const String vneIdLoginUrl =
      'https://xacthuc.dichvucong.gov.vn/oauth2/authorize?response_type=code&client_id=ifI4Sqjt9R2Q2n0iZZapnCV4ASca&redirect_uri=https://dvc.hanoi.dcs.vn/SsoAuthenticate/LoginSSODVCQG&scope=openid&acr_values=LoA1';
  // URL cho các thủ tục hành chính trên DVC Quốc gia
  static const String thunop =
      'https://dichvucong.gov.vn/p/home/dvc-thanh-toan-truc-tuyen.html';
  static const String administrativeProceduresUrl =
      '$baseUrl/ChuyenSinhHoatDangChinhThuc/Detail';
  static const String partyFeePaymentUrl =
      '$baseUrl/ChuyenSinhHoatDangTamThoi/Detail';
  static const String partyActivityConfirmationUrl =
      '$baseUrl/ChuyenSinhHoatDangChinhThucNoiBo/Detail';
}

/// Lớp đại diện cho một mục menu
class MenuItem {
  final String title;
  final String url;
  final IconData icon;
  final bool requiresLogin;
  final List<MenuItem>? subMenuItems;

  const MenuItem({
    required this.title,
    required this.url,
    required this.icon,
    this.requiresLogin = false,
    this.subMenuItems,
  });
}

/// Lớp chứa dữ liệu cho các menu, sử dụng AppConfig
class MenuData {
  // Danh sách các menu chính cho AppDrawer - Đã cải thiện cấu trúc theo nhóm chức năng
  static List<MenuItem> mainMenuItems = [
    const MenuItem(
      title: 'Trang chủ',
      url: AppConfig.homeUrl,
      icon: Icons.home_outlined,
    ),
    const MenuItem(
      title: 'Giới thiệu',
      url: AppConfig.aboutUrl,
      icon: Icons.info_outline,
    ),
    const MenuItem(
      title: 'Thủ tục hành chính',
      url: AppConfig.thunop,
      icon: Icons.assignment_outlined,
      requiresLogin: true,
      subMenuItems: [
        MenuItem(
          title: 'Chuyển sinh hoạt Đảng chính thức',
          url: AppConfig.administrativeProceduresUrl,
          icon: Icons.verified_user_outlined,
          requiresLogin: true,
        ),
        MenuItem(
          title: 'Chuyển sinh hoạt Đảng tạm thời',
          url: AppConfig.partyFeePaymentUrl,
          icon: Icons.swap_horiz_outlined,
          requiresLogin: true,
        ),
        MenuItem(
          title: 'Xác nhận sinh hoạt Đảng',
          url: AppConfig.partyActivityConfirmationUrl,
          icon: Icons.assignment_turned_in_outlined,
          requiresLogin: true,
        ),
      ],
    ),
    const MenuItem(
      title: 'Hồ sơ',
      url: AppConfig.profileUrl,
      icon: Icons.folder_outlined,
      requiresLogin: true,
    ),
    const MenuItem(
      title: 'Hướng dẫn',
      url: AppConfig.guideUrl,
      icon: Icons.help_outline,
    ),
    const MenuItem(
      title: 'Đánh giá mức độ hài lòng',
      url: AppConfig.feedbackUrl,
      icon: Icons.star_outline,
      requiresLogin: true,
    ),
    const MenuItem(
      title: 'Thông tin tài khoản',
      url: AppConfig.accountInfoUrl,
      icon: Icons.account_circle_outlined,
      requiresLogin: true,
    ),
  ];

  // Danh sách các menu cho Bottom Navigation Bar - Đã giảm từ 5 xuống 4 mục theo khuyến nghị
  static List<MenuItem> bottomNavItems = [
    const MenuItem(
      title: 'Trang chủ',
      url: AppConfig.homeUrl,
      icon: Icons.home_outlined,
    ),
    const MenuItem(
      title: 'Thủ tục',
      url: AppConfig.thunop,
      icon: Icons.assignment_outlined,
      requiresLogin: true,
    ),
    const MenuItem(
      title: 'Hồ sơ',
      url: AppConfig.profileUrl,
      icon: Icons.folder_outlined,
      requiresLogin: true,
    ),
    const MenuItem(
      title: 'Tài khoản',
      url: AppConfig.accountInfoUrl,
      icon: Icons.account_circle_outlined,
      requiresLogin: true,
    ),
  ];
}

// --- CÁC WIDGET GIAO DIỆN (Đã cải thiện) ---

class AppDrawer extends StatelessWidget {
  final Function(String, {bool requiresLogin}) onNavigate;
  final bool isLoggedIn;
  final VoidCallback onLoginRequired;
  final String? currentUrl;

  const AppDrawer({
    Key? key,
    required this.onNavigate,
    required this.isLoggedIn,
    required this.onLoginRequired,
    this.currentUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      child: Column(
        children: [
          _buildDrawerHeader(context, theme, colorScheme),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Phân nhóm các menu theo chức năng
                const _DrawerSectionTitle(title: 'Tổng quan'),
                ...MenuData.mainMenuItems
                    .where((item) =>
                        item.title == 'Trang chủ' || item.title == 'Giới thiệu')
                    .map((item) =>
                        _buildMenuItem(context, item, theme, colorScheme))
                    .toList(),

                const Divider(height: 16, thickness: 0.5),
                const _DrawerSectionTitle(title: 'Thủ tục hành chính'),
                ...MenuData.mainMenuItems
                    .where((item) => item.title == 'Thủ tục hành chính')
                    .map((item) =>
                        _buildMenuItem(context, item, theme, colorScheme))
                    .toList(),

                const Divider(height: 16, thickness: 0.5),
                const _DrawerSectionTitle(title: 'Tiện ích'),
                ...MenuData.mainMenuItems
                    .where((item) =>
                        item.title == 'Hồ sơ' ||
                        item.title == 'Hướng dẫn' ||
                        item.title == 'Đánh giá mức độ hài lòng')
                    .map((item) =>
                        _buildMenuItem(context, item, theme, colorScheme))
                    .toList(),

                const Divider(height: 16, thickness: 0.5),
                const _DrawerSectionTitle(title: 'Tài khoản'),
                ...MenuData.mainMenuItems
                    .where((item) => item.title == 'Thông tin tài khoản')
                    .map((item) =>
                        _buildMenuItem(context, item, theme, colorScheme))
                    .toList(),

                const Divider(height: 16, thickness: 0.5),
                // Nút đăng nhập/đăng xuất
                if (!isLoggedIn)
                  ListTile(
                    leading:
                        Icon(Icons.login, color: colorScheme.primary, size: 24),
                    title: Text('Đăng nhập',
                        style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 4.0),
                    minLeadingWidth: 24,
                    onTap: () {
                      Navigator.pop(context);
                      onNavigate(AppConfig.loginUrl);
                    },
                  )
                else
                  ListTile(
                    leading:
                        Icon(Icons.logout, color: colorScheme.error, size: 24),
                    title: Text('Đăng xuất',
                        style: TextStyle(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w600)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 4.0),
                    minLeadingWidth: 24,
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content:
                                Text('Chức năng đăng xuất cần được cài đặt!')),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(
      BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    return UserAccountsDrawerHeader(
      accountName: const Text(
        'Hệ thống dịch vụ công',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      accountEmail: const Text(
        'Thành ủy Hà Nội',
        style: TextStyle(
          fontSize: 14,
          color: Colors.white70,
        ),
      ),
      currentAccountPicture: CircleAvatar(
        backgroundColor: colorScheme.onPrimary,
        child: Icon(
          Icons.cloud_queue,
          size: 48,
          color: colorScheme.primary,
        ),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primaryContainer.withOpacity(0.8)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      otherAccountsPictures: [
        if (isLoggedIn)
          CircleAvatar(
            backgroundColor: colorScheme.secondary,
            child:
                const Icon(Icons.verified_user, color: Colors.white, size: 20),
          )
        else
          CircleAvatar(
            backgroundColor: Colors.grey.shade400,
            child: const Icon(Icons.person_off, color: Colors.white, size: 20),
          )
      ],
      margin: EdgeInsets.zero,
    );
  }

  Widget _buildMenuItem(BuildContext context, MenuItem item, ThemeData theme,
      ColorScheme colorScheme) {
    final bool isDisabled = item.requiresLogin && !isLoggedIn;
    final bool isSelected = currentUrl == item.url && !isDisabled;
    Color? tileColor =
        isSelected ? colorScheme.primary.withOpacity(0.12) : null;
    Color? iconColor = isDisabled
        ? Colors.grey[500]
        : (isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant);
    Color? textColor = isDisabled
        ? Colors.grey[600]
        : (isSelected ? colorScheme.primary : colorScheme.onSurface);
    FontWeight? textWeight = isSelected ? FontWeight.bold : FontWeight.normal;

    if (item.subMenuItems != null && item.subMenuItems!.isNotEmpty) {
      bool isSubMenuSelected = item.subMenuItems!.any((subItem) =>
          currentUrl == subItem.url && !(subItem.requiresLogin && !isLoggedIn));

      return ExpansionTile(
        leading: Icon(item.icon,
            color: iconColor, semanticLabel: '${item.title} menu'),
        backgroundColor: tileColor,
        collapsedBackgroundColor: tileColor,
        initiallyExpanded: isSubMenuSelected,
        title: Text(
          item.title,
          style: TextStyle(color: textColor, fontWeight: textWeight),
        ),
        childrenPadding: const EdgeInsets.only(left: 16.0),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0.0),
        children: item.subMenuItems!.map((subItem) {
          final bool isSubItemDisabled = subItem.requiresLogin && !isLoggedIn;
          final bool isSubItemSelected =
              currentUrl == subItem.url && !isSubItemDisabled;
          Color? subTileColor =
              isSubItemSelected ? colorScheme.secondary.withOpacity(0.1) : null;
          Color? subIconColor = isSubItemDisabled
              ? Colors.grey[500]
              : (isSubItemSelected
                  ? colorScheme.secondary
                  : colorScheme.onSurfaceVariant);
          Color? subTextColor = isSubItemDisabled
              ? Colors.grey[600]
              : (isSubItemSelected
                  ? colorScheme.secondary
                  : colorScheme.onSurface);
          FontWeight? subTextWeight =
              isSubItemSelected ? FontWeight.bold : FontWeight.normal;

          return ListTile(
            contentPadding: const EdgeInsets.only(left: 40.0, right: 16.0),
            tileColor: subTileColor,
            leading: Icon(subItem.icon,
                color: subIconColor,
                size: 22,
                semanticLabel: '${subItem.title} submenu'),
            title: Text(
              subItem.title,
              style: TextStyle(
                  color: subTextColor, fontWeight: subTextWeight, fontSize: 15),
            ),
            onTap: () {
              Navigator.pop(context);
              if (isSubItemDisabled) {
                onLoginRequired();
              } else {
                onNavigate(subItem.url, requiresLogin: subItem.requiresLogin);
              }
            },
            selected: isSubItemSelected,
            selectedTileColor: colorScheme.secondary.withOpacity(0.15),
            minLeadingWidth: 24,
          );
        }).toList(),
      );
    } else {
      return ListTile(
        tileColor: tileColor,
        leading: Icon(item.icon,
            color: iconColor, size: 24, semanticLabel: '${item.title} menu'),
        title: Text(
          item.title,
          style: TextStyle(color: textColor, fontWeight: textWeight),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24.0, vertical: 0.0),
        minLeadingWidth: 24,
        onTap: () {
          Navigator.pop(context);
          if (isDisabled) {
            onLoginRequired();
          } else {
            onNavigate(item.url, requiresLogin: item.requiresLogin);
          }
        },
        selected: isSelected,
        selectedTileColor: colorScheme.primary.withOpacity(0.15),
      );
    }
  }
}

/// Widget tiêu đề phần trong drawer
class _DrawerSectionTitle extends StatelessWidget {
  final String title;

  const _DrawerSectionTitle({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24.0, top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.secondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isLoggedIn;
  final VoidCallback onLoginRequired;

  const AppBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.isLoggedIn,
    required this.onLoginRequired,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    // Thêm kiểu chữ đậm hơn và rõ ràng hơn cho nhãn được chọn
    final TextStyle selectedLabelStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: colorScheme.primary,
    );

    // Kiểu chữ thường cho nhãn không được chọn
    final TextStyle unselectedLabelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: colorScheme.onSurface.withOpacity(0.75),
    );

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        final item = MenuData.bottomNavItems[index];
        if (item.requiresLogin && !isLoggedIn) {
          onLoginRequired();
        } else {
          onTap(index);
        }
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: theme.bottomAppBarTheme.color ?? colorScheme.surface,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onSurface.withOpacity(0.75),
      selectedLabelStyle: selectedLabelStyle,
      unselectedLabelStyle: unselectedLabelStyle,
      showUnselectedLabels: true,
      elevation: theme.bottomAppBarTheme.elevation ?? 8.0,
      items: MenuData.bottomNavItems.map((item) {
        final bool isDisabledByLogin = item.requiresLogin && !isLoggedIn;
        Color? iconColorOverride =
            isDisabledByLogin ? Colors.grey.shade500 : null;

        // Sử dụng icon khác nhau cho trạng thái được chọn và không được chọn
        return BottomNavigationBarItem(
          icon: Icon(
            item.icon,
            color: iconColorOverride,
            size: 24,
            semanticLabel: '${item.title} tab',
          ),
          activeIcon: Icon(
            // Sử dụng icon đặc (filled) khi được chọn, icon đường viền (outline) khi không được chọn
            _getFilledIcon(item.icon),
            size: 24,
            semanticLabel: '${item.title} tab đã chọn',
          ),
          label: item.title,
          tooltip:
              '${item.title}${isDisabledByLogin ? " (Cần đăng nhập)" : ""}',
        );
      }).toList(),
    );
  }

  // Hàm chuyển đổi icon đường viền sang icon đặc khi được chọn
  IconData _getFilledIcon(IconData outlinedIcon) {
    // Map các icon đường viền (outlined) sang icon đặc (filled)
    Map<IconData, IconData> iconMap = {
      Icons.home_outlined: Icons.home,
      Icons.assignment_outlined: Icons.assignment,
      Icons.folder_outlined: Icons.folder,
      Icons.account_circle_outlined: Icons.account_circle,
    };

    return iconMap[outlinedIcon] ?? outlinedIcon;
  }
}
