import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'plan.dart';

class PlanStore {
  static const String _plansKey = 'plans';

  // プラン情報を保存する
  static Future<void> savePlan(Plan plan) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> plans = prefs.getStringList(_plansKey) ?? [];
    plans.add(json.encode(plan.toJson()));
    await prefs.setStringList(_plansKey, plans);
  }

  // 保存されているプラン情報のリストを取得する
  static Future<List<Plan>> getPlans() async {
    final prefs = await SharedPreferences.getInstance();
    // キーの存在チェック
    if (!prefs.containsKey(_plansKey)) {
      return [];
    }

    List<String> plans = prefs.getStringList(_plansKey) ?? [];
    return plans.map((p) => Plan.fromJson(json.decode(p))).toList();
  }

  // 指定された planId のプランを削除する
  static Future<void> deletePlan(String planId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> plans = prefs.getStringList(_plansKey) ?? [];
    // 指定した planId を持つプランを除外
    plans = plans.where((p) {
      final plan = Plan.fromJson(json.decode(p));
      return plan.planId != planId;
    }).toList();
    await prefs.setStringList(_plansKey, plans);
  }
}
