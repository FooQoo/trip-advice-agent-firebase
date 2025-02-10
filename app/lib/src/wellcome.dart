import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({Key? key}) : super(key: key);

  Future<void> _markWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenWelcome', true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("TRIP-LAN")),
      body: Center(
        child: Column(
          // mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 30),
            // ロゴ画像を中央に表示
            Image.asset(
              'assets/images/logo.png', // ここで画像のパスを指定
              width: 300,  // 画像の幅を指定（任意）
              height: 300, // 画像の高さを指定（任意）
            ),
            const SizedBox(height: 16),
            const Text(
              "ようこそ TRIP-LAN へ",
              style: TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                // 初回表示後フラグを更新してプラン作成画面へ遷移
                await _markWelcomeSeen();
                context.push('/create_plan');
              },
              child: const Text("プランを作成する"),
            ),
          ],
        ),
      ),
    );
  }
}
