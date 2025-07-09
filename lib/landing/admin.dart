import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:persistent_bottom_nav_bar_v2_style_4_upgraded/persistent_bottom_nav_bar_v2_style_4_upgraded.dart';
import 'package:sldmtrackingapp/landing/admin_screens/account_settings_screen.dart';
import 'package:sldmtrackingapp/landing/admin_screens/accounting_screen.dart';
import 'package:sldmtrackingapp/landing/admin_screens/home_screen.dart';
import 'package:sldmtrackingapp/landing/admin_screens/management_screen.dart';
import 'package:sldmtrackingapp/landing/student_screens/account_screen.dart';
import 'package:sldmtrackingapp/landing/student_screens/billings_screen.dart';
import 'package:sldmtrackingapp/landing/student_screens/home_screen.dart';
import 'package:sldmtrackingapp/landing/student_screens/settings_screen.dart';
import 'package:sldmtrackingapp/providers/auth_provider.dart';

class AdminPage extends ConsumerStatefulWidget {
  const AdminPage({super.key});

  @override
  ConsumerState<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends ConsumerState<AdminPage> {
  @override
  Widget build(BuildContext context) {
    final isAdminAsync = ref.watch(isAdminProvider);

    return isAdminAsync.when(
      data: (isAdmin) {
        if (isAdmin) {
          return PersistentTabView(
            tabs: [
              PersistentTabConfig(
                screen: const AdminHomeScreen(),
                item: ItemConfig(icon: const Icon(Icons.home), title: "Home"),
              ),
              PersistentTabConfig(
                screen: const AccountingScreen(),
                item: ItemConfig(
                  icon: const Icon(Icons.account_balance),
                  title: "Accounting",
                ),
              ),
              PersistentTabConfig(
                screen: const ManagementScreen(),
                item: ItemConfig(
                  icon: const Icon(Icons.business),
                  title: "Management",
                ),
              ),
              PersistentTabConfig(
                screen: const AccountSettingsScreen(),
                item: ItemConfig(
                  icon: const Icon(Icons.person),
                  title: "Account",
                ),
              ),
            ],
            navBarBuilder: (navBarConfig) => Style4BottomNavBar(
              navBarConfig: navBarConfig,
              animatedBorderRadius: BorderRadius.circular(20),
              activeForegroundColor: const Color(0xFF4CAF50),
              inactiveForegroundColor: Colors.grey,
              textStyle: const TextStyle(fontSize: 12),
              navBarDecoration: const NavBarDecoration(
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
            ),
          );
        } else {
          // Student navigation
          return PersistentTabView(
            tabs: [
              PersistentTabConfig(
                screen: const StudentHomeScreen(),
                item: ItemConfig(icon: const Icon(Icons.home), title: "Home"),
              ),
              PersistentTabConfig(
                screen: const BillingsScreen(),
                item: ItemConfig(
                  icon: const Icon(Icons.receipt),
                  title: "Billings",
                ),
              ),
              PersistentTabConfig(
                screen: const SettingsScreen(),
                item: ItemConfig(
                  icon: const Icon(Icons.settings),
                  title: "Settings",
                ),
              ),
              PersistentTabConfig(
                screen: const StudentAccountScreen(),
                item: ItemConfig(
                  icon: const Icon(Icons.person),
                  title: "Account",
                ),
              ),
            ],
            navBarBuilder: (navBarConfig) => Style4BottomNavBar(
              navBarConfig: navBarConfig,
              animatedBorderRadius: BorderRadius.circular(20),
              activeForegroundColor: const Color(0xFF4CAF50),
              inactiveForegroundColor: Colors.grey,
              textStyle: const TextStyle(fontSize: 12),
              navBarDecoration: const NavBarDecoration(
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
            ),
          );
        }
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) =>
          Scaffold(body: Center(child: Text('Error: $error'))),
    );
  }
}
