import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/feed_controller.dart';
import '../../core/app_theme.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final FeedController controller = Get.find<FeedController>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
      ),
      body: Obx(
        () => controller.notifications.isEmpty
            ? const Center(child: Text("No notifications yet"))
            : ListView.separated(
                itemCount: controller.notifications.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.grey.withAlpha(25),
                ),
                itemBuilder: (context, index) {
                  final alert = controller.notifications[index];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: alert.color.withAlpha(26),
                      child: Icon(alert.icon, color: alert.color, size: 20),
                    ),
                    title: Text(
                      alert.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : AppTheme.deepNavy,
                      ),
                    ),
                    subtitle: Text(
                      alert.subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    trailing: Text(
                      alert.time,
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                    onTap: () {},
                  );
                },
              ),
      ),
    );
  }
}
