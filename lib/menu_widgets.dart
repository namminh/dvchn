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

/// Widget hiển thị Drawer Menu
class AppDrawer extends StatelessWidget {
  final Function(String) onNavigate;
  final bool isLoggedIn;
  final VoidCallback onLoginRequired;

  const AppDrawer({
    Key? key,
    required this.onNavigate,
    required this.isLoggedIn,
    required this.onLoginRequired,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hệ thống dịch vụ công',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Thành ủy Hà Nội',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isLoggedIn ? 'DVCHN' : 'Chưa đăng nhập',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ...MenuConfig.mainMenuItems
              .map((item) => _buildMenuItem(context, item))
              .toList(),
          if (!isLoggedIn)
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Đăng nhập'),
              onTap: () {
                Navigator.pop(context); // Đóng drawer
                onNavigate(MenuConfig.loginUrl);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, MenuItem item) {
    // Nếu menu yêu cầu đăng nhập và người dùng chưa đăng nhập
    final bool isDisabled = item.requiresLogin && !isLoggedIn;

    if (item.subMenuItems != null && item.subMenuItems!.isNotEmpty) {
      return ExpansionTile(
        leading: Icon(
          item.icon,
          color: isDisabled ? Colors.grey : null,
        ),
        title: Text(
          item.title,
          style: TextStyle(
            color: isDisabled ? Colors.grey : null,
          ),
        ),
        children: item.subMenuItems!.map((subItem) {
          final bool isSubItemDisabled = subItem.requiresLogin && !isLoggedIn;

          return ListTile(
            leading: Icon(
              subItem.icon,
              color: isSubItemDisabled ? Colors.grey : null,
            ),
            title: Text(
              subItem.title,
              style: TextStyle(
                color: isSubItemDisabled ? Colors.grey : null,
              ),
            ),
            onTap: () {
              Navigator.pop(context); // Đóng drawer

              if (isSubItemDisabled) {
                onLoginRequired();
              } else {
                onNavigate(subItem.url);
              }
            },
          );
        }).toList(),
      );
    } else {
      return ListTile(
        leading: Icon(
          item.icon,
          color: isDisabled ? Colors.grey : null,
        ),
        title: Text(
          item.title,
          style: TextStyle(
            color: isDisabled ? Colors.grey : null,
          ),
        ),
        onTap: () {
          Navigator.pop(context); // Đóng drawer

          if (isDisabled) {
            onLoginRequired();
          } else {
            onNavigate(item.url);
          }
        },
      );
    }
  }
}

/// Widget hiển thị Bottom Navigation Bar
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
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        final item = MenuConfig.bottomNavItems[index];

        if (item.requiresLogin && !isLoggedIn) {
          onLoginRequired();
        } else {
          onTap(index);
        }
      },
      type: BottomNavigationBarType.fixed,
      items: MenuConfig.bottomNavItems.map((item) {
        final bool isDisabled = item.requiresLogin && !isLoggedIn;

        return BottomNavigationBarItem(
          icon: Icon(
            item.icon,
            color: isDisabled ? Colors.grey : null,
          ),
          label: item.title,
        );
      }).toList(),
    );
  }
}

/// Widget hiển thị các chức năng chính ở trang chủ
class MainFeatureGrid extends StatelessWidget {
  final Function(String) onNavigate;
  final bool isLoggedIn;
  final VoidCallback onLoginRequired;

  const MainFeatureGrid({
    Key? key,
    required this.onNavigate,
    required this.isLoggedIn,
    required this.onLoginRequired,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: MenuConfig.mainFeatures.map((feature) {
        final bool isDisabled = feature.requiresLogin && !isLoggedIn;

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              if (isDisabled) {
                onLoginRequired();
              } else {
                onNavigate(feature.url);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  feature.icon,
                  size: 48,
                  color:
                      isDisabled ? Colors.grey : Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    feature.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDisabled ? Colors.grey : null,
                    ),
                  ),
                ),
                if (isDisabled)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      '(Yêu cầu đăng nhập)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
