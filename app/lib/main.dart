import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // Firebase Core のインポート
import 'package:form_app/src/wellcome.dart';
import 'firebase_options.dart'; // Flutterfire CLI で生成された設定ファイルのインポート
import 'package:go_router/go_router.dart';
import 'package:window_size/window_size.dart';
import 'package:intl/intl.dart' as intl;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'src/domain/model/plan.dart';
import 'src/domain/model/plan_store.dart';
import 'src/create_plan.dart';
import 'src/domain/model/suggested_plan.dart';
import 'src/domain/model/suggested_plan_store.dart';
import 'src/plan_detail.dart';

/// グローバルでローカル通知プラグインを利用できるようにする
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// ローカル通知の初期化（Android と iOS の両方の設定を指定）
Future<void> initializeLocalNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  // iOS 向けの設定（DarwinInitializationSettings を使用）
  const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings();

  // 両プラットフォーム用の初期化設定を作成
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      // 通知タップ時の処理（必要に応じて詳細画面への遷移など）
      debugPrint("Notification payload: ${response.payload}");
    },
  );
}

/// ローカル通知を表示する関数
Future<void> showPlanGeneratedNotification(String planTitle) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'plan_generated_channel', // チャンネルID
    'Plan Generated', // チャンネル名
    channelDescription: 'プランが生成されたときの通知',
    importance: Importance.max,
    priority: Priority.high,
  );
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.show(
    0, // 通知ID（必要に応じて各プランごとに管理してください）
    'プラン生成完了',
    '「$planTitle」が生成されました。',
    platformChannelSpecifics,
    payload: planTitle,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase の初期化
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 事前にプラン一覧を取得し、存在すれば hasPlans = true とする
  final plans = await PlanStore.getPlans();
  final bool hasPlans = plans.isNotEmpty;

  // ローカル通知の初期化
  // await initializeLocalNotifications();

  setupWindow();
  runApp(FormApp(hasPlans: hasPlans));
}

const double windowWidth = 480;
const double windowHeight = 854;

/// ウィンドウサイズ設定（デスクトップ向け）
void setupWindow() {
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    WidgetsFlutterBinding.ensureInitialized();
    setWindowTitle('Trip Advisor Agent');
    setWindowMinSize(const Size(windowWidth, windowHeight));
    setWindowMaxSize(const Size(windowWidth, windowHeight));
    getCurrentScreen().then((screen) {
      setWindowFrame(Rect.fromCenter(
        center: screen!.frame.center,
        width: windowWidth,
        height: windowHeight,
      ));
    });
  }
}

/// グローバルな RouteObserver（RouteAware 用）
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

/// GoRouter の設定。ホーム画面、プラン作成画面、詳細画面のルートを定義
// final router = GoRouter(
//   observers: [routeObserver],
//   routes: [
//     // ウェルカム画面
//     GoRoute(
//       path: '/welcome',
//       builder: (context, state) => const WelcomePage(),
//     ),
//     GoRoute(
//       path: '/',
//       builder: (context, state) => const HomePage(),
//       routes: [
//         GoRoute(
//           path: 'create_plan',
//           builder: (context, state) => const FormWidgetsDemo(),
//         ),
//         GoRoute(
//           path: 'plan_detail',
//           builder: (context, state) {
//             final data = state.extra as Map<String, dynamic>;
//             final plan = data['plan'] as Plan;
//             final suggestedPlan = data['suggestedPlan'] as SuggestedPlan;
//             return PlanDetail(plan: plan, suggestedPlan: suggestedPlan);
//           },
//         ),
//       ],
//     ),
//   ],
// );

class FormApp extends StatelessWidget {

  final bool hasPlans;

  const FormApp({super.key, required this.hasPlans});

  @override
  Widget build(BuildContext context) {

    final router = GoRouter(
      initialLocation: this.hasPlans ? '/' : '/welcome',
      observers: [routeObserver],
      routes: [
        // ウェルカム画面
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const WelcomePage(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const HomePage(),
          routes: [
            GoRoute(
              path: 'create_plan',
              builder: (context, state) => const FormWidgetsDemo(),
            ),
            GoRoute(
              path: 'plan_detail',
              builder: (context, state) {
                final data = state.extra as Map<String, dynamic>;
                final plan = data['plan'] as Plan;
                final suggestedPlan = data['suggestedPlan'] as SuggestedPlan;
                return PlanDetail(plan: plan, suggestedPlan: suggestedPlan);
              },
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'Trip Advisor Agent',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
      ),
      routerConfig: router,
    );
  }
}

/// ホーム画面：保存されたプラン一覧を表示する
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

/// RouteAware を mixin して、他画面から戻った際に自動更新する
class _HomePageState extends State<HomePage> with RouteAware {
  List<Plan> _plans = [];
  bool _isLoading = true;
  /// 各プランごとの SuggestedPlan 状態を管理するマップ  
  /// key: planId, value: 生成済みの SuggestedPlan（存在しなければ null）
  Map<String, SuggestedPlan?> _suggestedPlans = {};
  /// 各プランのポーリング開始時刻を記録するマップ
  Map<String, DateTime> _pollStartTimes = {};
  /// 各プランのポーリングでタイムアウトしたかどうかを管理するマップ
  Map<String, bool> _pollTimeout = {};
  Timer? _statusTimer;
  /// ポーリングの最大待機時間（例：10分）
  final Duration _maxPollDuration = const Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  /// プラン一覧を取得し、各プランごとにまず即座に SuggestedPlan が存在するか確認する
  Future<void> _loadPlans() async {
    final plans = await PlanStore.getPlans();
    debugPrint('DEBUG: Loaded ${plans.length} plans');
    for (var plan in plans) {
      debugPrint('DEBUG: Plan: ${plan.toJson()}');
    }

    // 各プランについて初回で SuggestedPlan を取得する
    final Map<String, SuggestedPlan?> initialMap = {};
    final Map<String, DateTime> pollStartTimes = {};
    final Map<String, bool> pollTimeout = {};

    await Future.wait(plans.map((plan) async {
      pollStartTimes[plan.planId] = DateTime.now();
      pollTimeout[plan.planId] = false;
      final sp = await SuggestedPlanStore.getSuggestedPlan(plan.planId);
      initialMap[plan.planId] = sp;
    }));

    setState(() {
      _plans = plans;
      _suggestedPlans = initialMap;
      _pollStartTimes = pollStartTimes;
      _pollTimeout = pollTimeout;
      _isLoading = false;
    });
    _startPolling();
  }

  /// Timer.periodic を用いて、各プランの SuggestedPlan 状態を定期的にチェック
  void _startPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      for (var plan in _plans) {
        // すでに生成済みもしくはタイムアウトしている場合は処理しない
        if (_suggestedPlans[plan.planId] != null || _pollTimeout[plan.planId] == true) {
          continue;
        }
        // ポーリング開始からの経過時間を計算
        final elapsed = DateTime.now().difference(_pollStartTimes[plan.planId]!);
        if (elapsed > _maxPollDuration) {
          // 最大待機時間を超えたらタイムアウトフラグを立てる
          setState(() {
            _pollTimeout[plan.planId] = true;
          });
        } else {
          // まだ生成中の場合、SuggestedPlan を取得しに行く
          SuggestedPlanStore.getSuggestedPlan(plan.planId).then((suggestedPlan) {
            if (suggestedPlan != null) {
              // もし初回（以前は null）から生成済みに変わったならローカル通知を表示
              if (_suggestedPlans[plan.planId] == null) {
                showPlanGeneratedNotification(plan.title);
              }
              setState(() {
                _suggestedPlans[plan.planId] = suggestedPlan;
              });
            }
          });
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null) {
      routeObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _statusTimer?.cancel();
    super.dispose();
  }

  // 他画面から戻ったときに自動更新
  @override
  void didPopNext() {
    _loadPlans();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プラン一覧'),
        actions: [
          // プラン作成画面へ遷移するボタン
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.go('/create_plan');
            },
          ),
        ],
      ),
      // RefreshIndicator を追加して下にスワイプで更新できるようにする
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
              ? const Center(child: Text('保存されたプランはありません'))
              : RefreshIndicator(
                  onRefresh: _loadPlans,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _plans.length,
                    itemBuilder: (context, index) {
                      final plan = _plans[index];
                      String dateStr = '';
                      if (plan.dateRange != null) {
                        dateStr =
                            ' (${intl.DateFormat("yyyy年MM月dd日").format(plan.dateRange!.start)}～${intl.DateFormat("yyyy年MM月dd日").format(plan.dateRange!.end)})';
                      }
                      final label = '${plan.title}旅行$dateStr';
                      // suggestedPlan が生成済みなら true
                      final isGenerated = _suggestedPlans[plan.planId] != null;
                      // タイムアウトしているかどうか
                      final isTimeout = _pollTimeout[plan.planId] ?? false;
                      return Dismissible(
                        key: Key(plan.planId),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('プランの削除'),
                                content: const Text('本当にこのプランを削除してもよろしいですか？'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('キャンセル'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('削除'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: const [
                              Icon(Icons.delete, color: Colors.white),
                              SizedBox(width: 8),
                              Text('削除', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        onDismissed: (direction) async {
                          final deletedPlan = plan;
                          await PlanStore.deletePlan(plan.planId);
                          await _loadPlans();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('プランを削除しました'),
                              action: SnackBarAction(
                                label: '元に戻す',
                                onPressed: () async {
                                  await PlanStore.savePlan(deletedPlan);
                                  await _loadPlans();
                                },
                              ),
                            ),
                          );
                        },
                        child: ListTile(
                          title: Text(label),
                          // 状態に応じたサブタイトル・アイコンの表示
                          subtitle: isTimeout
                              ? const Text("生成に失敗しました")
                              : (isGenerated ? null : const Text("生成中")),
                          trailing: isTimeout
                              ? IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () {
                                    // 再取得のために状態を初期化
                                    setState(() {
                                      _pollTimeout[plan.planId] = false;
                                      _pollStartTimes[plan.planId] = DateTime.now();
                                      _suggestedPlans[plan.planId] = null;
                                    });
                                  },
                                )
                              : (isGenerated ? null : const Icon(Icons.hourglass_bottom)),
                          // 生成済みの場合のみタップ可能
                          onTap: isGenerated
                              ? () {
                                  final suggestedPlan = _suggestedPlans[plan.planId]!;
                                  context.push('/plan_detail', extra: {
                                    'plan': plan,
                                    'suggestedPlan': suggestedPlan,
                                  });
                                }
                              : null,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}