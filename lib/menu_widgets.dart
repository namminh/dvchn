// lib/menu_widgets.dart

import 'package:flutter/material.dart';

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

  MenuItem({
    required this.title,
    required this.url,
    required this.icon,
    this.requiresLogin = false,
    this.subMenuItems,
  });
}

/// Lớp chứa dữ liệu cho các menu, sử dụng AppConfig
class MenuData {
  // Danh sách các menu chính cho AppDrawer
  static List<MenuItem> mainMenuItems = [
    MenuItem(
      title: 'Trang chủ',
      url: AppConfig.homeUrl,
      icon: Icons.home,
    ),
    MenuItem(
      title: 'Giới thiệu',
      url: AppConfig.aboutUrl,
      icon: Icons.info,
    ),
    MenuItem(
      title: 'Thủ tục hành chính',
      url: AppConfig.thunop,
      icon: Icons.description,
      requiresLogin: true,
      subMenuItems: [
        MenuItem(
          title: 'Thu nộp Đảng phí',
          url: AppConfig.partyFeePaymentUrl,
          icon: Icons.payment,
          requiresLogin: true,
        ),
        MenuItem(
          title: 'Chuyển sinh hoạt Đảng chính thức',
          url: AppConfig.administrativeProceduresUrl,
          icon: Icons.verified_user,
          requiresLogin: true,
        ),
        MenuItem(
          title: 'Chuyển sinh hoạt Đảng tạm thời',
          url: AppConfig.partyFeePaymentUrl,
          icon: Icons.transfer_within_a_station,
          requiresLogin: true,
        ),
        MenuItem(
          title: 'Chuyển sinh hoạt Đảng tạm thời',
          url: AppConfig.partyActivityConfirmationUrl,
          icon: Icons.swap_horiz,
          requiresLogin: true,
        ),
      ],
    ),
    MenuItem(
      title: 'Hồ sơ',
      url: AppConfig.profileUrl,
      icon: Icons.folder,
      requiresLogin: true,
    ),
    MenuItem(
      title: 'Hướng dẫn',
      url: AppConfig.guideUrl,
      icon: Icons.help,
    ),
    MenuItem(
      title: 'Đánh giá mức độ hài lòng',
      url: AppConfig.feedbackUrl,
      icon: Icons.star,
      requiresLogin: true,
    ),
    MenuItem(
      title: 'Thông tin tài khoản',
      url: AppConfig.accountInfoUrl,
      icon: Icons.account_circle,
      requiresLogin: true,
    ),
  ];

  // Danh sách các menu cho Bottom Navigation Bar
  static List<MenuItem> bottomNavItems = [
    MenuItem(
      title: 'Trang chủ',
      url: AppConfig.homeUrl,
      icon: Icons.home,
    ),
    MenuItem(
      title: 'Thủ tục',
      url: AppConfig.thunop,
      icon: Icons.description,
      requiresLogin: true,
    ),
    MenuItem(
      title: 'Hồ sơ',
      url: AppConfig.profileUrl,
      icon: Icons.folder,
      requiresLogin: true,
    ),
    MenuItem(
      title: 'Xác nhận sinh hoạt Đảng hai chiều',
      url: AppConfig.administrativeProceduresUrl,
      icon: Icons.verified_user,
    ),
    MenuItem(
      title: 'Chuyển sinh hoạt Đảng chính thức',
      url: AppConfig.partyFeePaymentUrl,
      icon: Icons.transfer_within_a_station,
      requiresLogin: true,
    ),
  ];
}

// --- CÁC WIDGET GIAO DIỆN (Không thay đổi) ---

class AppDrawer extends StatelessWidget {
  final Function(String) onNavigate;
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
                ...MenuData.mainMenuItems
                    .map((item) =>
                        _buildMenuItem(context, item, theme, colorScheme))
                    .toList(),
                const Divider(height: 1, thickness: 0.5),
                if (!isLoggedIn)
                  ListTile(
                    leading: Icon(Icons.login, color: colorScheme.primary),
                    title: Text('Đăng nhập',
                        style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context);
                      onNavigate(AppConfig.loginUrl);
                    },
                  )
                else
                  ListTile(
                    leading: Icon(Icons.logout, color: colorScheme.error),
                    title: Text('Đăng xuất',
                        style: TextStyle(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w600)),
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
        leading: Icon(item.icon, color: iconColor),
        backgroundColor: tileColor,
        collapsedBackgroundColor: tileColor,
        initiallyExpanded: isSubMenuSelected,
        title: Text(
          item.title,
          style: TextStyle(color: textColor, fontWeight: textWeight),
        ),
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
            leading: Icon(subItem.icon, color: subIconColor, size: 22),
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
                onNavigate(subItem.url);
              }
            },
            selected: isSubItemSelected,
            selectedTileColor: colorScheme.secondary.withOpacity(0.15),
          );
        }).toList(),
      );
    } else {
      return ListTile(
        tileColor: tileColor,
        leading: Icon(item.icon, color: iconColor),
        title: Text(
          item.title,
          style: TextStyle(color: textColor, fontWeight: textWeight),
        ),
        onTap: () {
          Navigator.pop(context);
          if (isDisabled) {
            onLoginRequired();
          } else {
            onNavigate(item.url);
          }
        },
        selected: isSelected,
        selectedTileColor: colorScheme.primary.withOpacity(0.15),
      );
    }
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

    final TextStyle selectedLabelStyle = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: colorScheme.primary,
    );

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

        return BottomNavigationBarItem(
          icon: Icon(
            item.icon,
            color: iconColorOverride,
          ),
          activeIcon: Icon(item.icon),
          label: item.title,
        );
      }).toList(),
    );
  }
}
