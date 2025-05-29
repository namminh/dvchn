import 'package:flutter/material.dart';

/// Lớp chứa thông tin về các menu và URL tương ứng
class MenuConfig {
  // URL cơ sở của website
  static const String baseUrl = 'http://113.160.48.99:8791';

  // Các URL chính
  static const String homeUrl = '$baseUrl/Home';
  static const String aboutUrl = '$baseUrl/#';
  static const String administrativeUrl =
      'https://dichvucong.gov.vn/p/home/dvc-thanh-toan-truc-tuyen.html';
  static const String profileUrl =
      'http://113.160.48.99:8791/KhayHoSoDang/Index';
  static const String guideUrl =
      'http://113.160.48.99:8791/HuongDanSuDung/Index';
  static const String feedbackUrl = '$baseUrl/Feedback';
  static const String accountUrl = '$baseUrl/Account/login';
  static const String loginUrl = '$baseUrl/Account/Login';

  // URL của submenu Thủ tục hành chính
  static const String partyFeeUrl =
      'https://dichvucong.gov.vn/p/home/dvc-thanh-toan-truc-tuyen.html';
  static const String partyActivityConfirmationUrl =
      'https://dichvucong.gov.vn/p/home/dvc-chi-tiet-thu-tuc-nganh-doc.html?ma_thu_tuc=2.002753';
  static const String officialPartyTransferUrl =
      'https://dichvucong.gov.vn/p/home/dvc-chi-tiet-thu-tuc-nganh-doc.html?ma_thu_tuc=2.002768';
  static const String temporaryPartyTransferUrl =
      'https://dichvucong.gov.vn/p/home/dvc-chi-tiet-thu-tuc-nganh-doc.html?ma_thu_tuc=2.002769';
// Danh sách các menu chính
  static List<MenuItem> mainMenuItems = [
    MenuItem(
      title: 'Trang chủ',
      url: homeUrl,
      icon: Icons.home,
      requiresLogin: false,
    ),
    MenuItem(
      title: 'Giới thiệu',
      url: aboutUrl,
      icon: Icons.info,
      requiresLogin: false,
    ),
    MenuItem(
      title: 'Thủ tục hành chính',
      url: administrativeUrl,
      icon: Icons.description,
      requiresLogin: true,
      subMenuItems: [
        MenuItem(
          title: 'Thu nộp Đảng phí',
          url: partyFeeUrl,
          icon: Icons.payment,
          requiresLogin: true,
        ),
        MenuItem(
          title: 'Xác nhận sinh hoạt Đảng hai chiều',
          url: partyActivityConfirmationUrl,
          icon: Icons.verified_user,
          requiresLogin: true,
        ),
        MenuItem(
          title: 'Chuyển sinh hoạt Đảng chính thức',
          url: officialPartyTransferUrl,
          icon: Icons.transfer_within_a_station,
          requiresLogin: true,
        ),
        MenuItem(
          title: 'Chuyển sinh hoạt Đảng tạm thời',
          url: temporaryPartyTransferUrl,
          icon: Icons.swap_horiz,
          requiresLogin: true,
        ),
      ],
    ),
    MenuItem(
      title: 'Hồ sơ',
      url: profileUrl,
      icon: Icons.folder,
      requiresLogin: true,
    ),
    MenuItem(
      title: 'Hướng dẫn',
      url: guideUrl,
      icon: Icons.help,
      requiresLogin: false,
    ),
    MenuItem(
      title: 'Đánh giá mức độ hài lòng',
      url: feedbackUrl,
      icon: Icons.star,
      requiresLogin: true,
    ),
    MenuItem(
      title: 'Thông tin tài khoản',
      url: accountUrl,
      icon: Icons.account_circle,
      requiresLogin: true,
    ),
  ];

  // Danh sách các menu cho Bottom Navigation Bar
  static List<MenuItem> bottomNavItems = [
    MenuItem(
      title: 'Trang chủ',
      url: homeUrl,
      icon: Icons.home,
      requiresLogin: false,
    ),
    MenuItem(
      title: 'Thủ tục',
      url: administrativeUrl,
      icon: Icons.description,
      requiresLogin: true,
    ),
    MenuItem(
      title: 'Hồ sơ',
      url: profileUrl,
      icon: Icons.folder,
      requiresLogin: true,
    ),
    MenuItem(
      title: 'Hướng dẫn',
      url: guideUrl,
      icon: Icons.help,
      requiresLogin: false,
    ),
    MenuItem(
      title: 'Tài khoản',
      url: accountUrl,
      icon: Icons.account_circle,
      requiresLogin: true,
    ),
  ];

  // Danh sách các chức năng chính hiển thị ở trang chủ
  static List<MenuItem> mainFeatures = [
    MenuItem(
      title: 'Thu nộp đảng phí',
      url: partyFeeUrl,
      icon: Icons.payment,
      requiresLogin: true,
    ),
    MenuItem(
      title: 'Lấy ý kiến nhận xét',
      url: '$baseUrl/FeedbackRequest',
      icon: Icons.feedback,
      requiresLogin: true,
    ),
    MenuItem(
      title: 'Chuyển sinh hoạt đảng chính thức',
      url: officialPartyTransferUrl,
      icon: Icons.transfer_within_a_station,
      requiresLogin: true,
    ),
    MenuItem(
      title: 'Chuyển sinh hoạt đảng tạm thời',
      url: temporaryPartyTransferUrl,
      icon: Icons.swap_horiz,
      requiresLogin: true,
    ),
  ];
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
    required this.requiresLogin,
    this.subMenuItems,
  });
}

class AppDrawer extends StatelessWidget {
  final Function(String) onNavigate;
  final bool isLoggedIn;
  final VoidCallback onLoginRequired;
  final String? currentUrl; // Thêm biến này để biết URL nào đang được hiển thị

  const AppDrawer({
    Key? key,
    required this.onNavigate,
    required this.isLoggedIn,
    required this.onLoginRequired,
    this.currentUrl, // Khởi tạo
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
                ...MenuConfig.mainMenuItems
                    .map((item) =>
                        _buildMenuItem(context, item, theme, colorScheme))
                    .toList(),
                const Divider(
                    height: 1,
                    thickness: 0.5), // Phân cách trước mục đăng nhập/đăng xuất
                if (!isLoggedIn)
                  ListTile(
                    leading: Icon(Icons.login, color: colorScheme.primary),
                    title: Text('Đăng nhập',
                        style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(context); // Đóng drawer
                      onNavigate(MenuConfig.loginUrl);
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
                      Navigator.pop(context); // Đóng drawer
                      // TODO: Thêm logic đăng xuất ở đây
                      // Ví dụ: onNavigate(MenuConfig.logoutUrl); // Nếu có URL đăng xuất
                      // Hoặc gọi một hàm onLogout()
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
          // Optional: Footer cho drawer
          // Container(
          //   padding: const EdgeInsets.all(16.0),
          //   child: Text(
          //     'Phiên bản 1.0.0',
          //     style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          //     textAlign: TextAlign.center,
          //   ),
          // )
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
          color: Colors.white, // Đảm bảo màu chữ dễ đọc trên nền header
        ),
      ),
      accountEmail: const Text(
        'Thành ủy Hà Nội',
        style: TextStyle(
          fontSize: 14,
          color: Colors.white70, // Màu chữ hơi mờ hơn
        ),
      ),
      currentAccountPicture: CircleAvatar(
        backgroundColor: colorScheme.onPrimary, // Màu nền cho avatar
        child: Icon(
          Icons.cloud_queue, // Icon ví dụ, bạn có thể thay đổi
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
    final bool isSelected = currentUrl == item.url &&
        !isDisabled; // Kiểm tra xem item có đang được chọn không

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
      // Kiểm tra xem có submenu item nào đang được chọn không
      bool isSubMenuSelected = item.subMenuItems!.any((subItem) =>
          currentUrl == subItem.url && !(subItem.requiresLogin && !isLoggedIn));

      return ExpansionTile(
        leading: Icon(item.icon, color: iconColor),
        backgroundColor: tileColor, // Màu nền khi mở rộng
        collapsedBackgroundColor: tileColor, // Màu nền khi đóng
        initiallyExpanded:
            isSubMenuSelected, // Mở rộng nếu có submenu item được chọn
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
            contentPadding: const EdgeInsets.only(
                left: 40.0, right: 16.0), // Thụt lề cho submenu
            tileColor: subTileColor,
            leading: Icon(subItem.icon, color: subIconColor, size: 22),
            title: Text(
              subItem.title,
              style: TextStyle(
                  color: subTextColor, fontWeight: subTextWeight, fontSize: 15),
            ),
            onTap: () {
              Navigator.pop(context); // Đóng drawer
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
          Navigator.pop(context); // Đóng drawer
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

    // Kiểu chữ cho label được chọn và không được chọn
    final TextStyle selectedLabelStyle = TextStyle(
      fontSize: 12.5, // Kích thước chữ có thể điều chỉnh
      fontWeight: FontWeight.w600, // Đậm hơn một chút khi được chọn
      color: colorScheme
          .primary, // Màu này cũng sẽ được áp dụng bởi selectedItemColor
    );

    final TextStyle unselectedLabelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: colorScheme.onSurface.withOpacity(
          0.75), // Màu này cũng sẽ được áp dụng bởi unselectedItemColor
    );

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        final item = MenuConfig.bottomNavItems[index];
        if (item.requiresLogin && !isLoggedIn) {
          onLoginRequired(); // Gọi callback yêu cầu đăng nhập
        } else {
          onTap(index); // Gọi callback khi item được chọn
        }
      },
      // ----- Thuộc tính cải thiện giao diện -----
      type: BottomNavigationBarType
          .fixed, // 'fixed' tốt cho 3-5 items, các label luôn hiển thị
      backgroundColor: theme.bottomAppBarTheme.color ??
          colorScheme.surface, // Màu nền từ theme, hoặc surface color
      selectedItemColor:
          colorScheme.primary, // Màu cho icon và label của item được chọn
      unselectedItemColor: colorScheme.onSurface
          .withOpacity(0.75), // Màu cho icon và label của item không được chọn

      selectedLabelStyle: selectedLabelStyle,
      unselectedLabelStyle: unselectedLabelStyle,

      showUnselectedLabels:
          true, // Luôn hiển thị label của các item không được chọn
      elevation: theme.bottomAppBarTheme.elevation ??
          8.0, // Độ nổi (shadow) từ theme, hoặc giá trị mặc định

      items: MenuConfig.bottomNavItems.map((item) {
        final bool isDisabledByLogin = item.requiresLogin && !isLoggedIn;

        // Xác định màu sắc cho icon dựa trên trạng thái isDisabledByLogin
        // Nếu không bị vô hiệu hóa bởi login, BottomNavigationBar sẽ tự quản lý màu selected/unselected
        Color? iconColorOverride =
            isDisabledByLogin ? Colors.grey.shade500 : null;

        return BottomNavigationBarItem(
          icon: Icon(
            item.icon,
            color: iconColorOverride, // Áp dụng màu xám nếu bị vô hiệu hóa
          ),
          // activeIcon cho phép bạn chỉ định một widget khác (hoặc Icon khác) khi item được chọn.
          // Ở đây, chúng ta dùng cùng Icon nhưng nó sẽ tự động nhận màu từ selectedItemColor.
          activeIcon: Icon(
            item.icon,
            // color: colorScheme.primary, // Không thực sự cần thiết vì selectedItemColor đã được đặt ở BottomNavigationBar
          ),
          label: item.title,
        );
      }).toList(),
    );
  }
}
