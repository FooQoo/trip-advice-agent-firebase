import 'package:cloud_firestore/cloud_firestore.dart';
import 'suggested_plan.dart';

class SuggestedPlanStore {
  // Firestore の "plans" コレクションへの参照
  static final CollectionReference _plansCollection =
      FirebaseFirestore.instance.collection('plans');

  /// 指定した planId を持つドキュメントから suggestedPlan を取得する
  static Future<SuggestedPlan?> getSuggestedPlan(String planId) async {
    try {
      // ドキュメントを取得
      DocumentSnapshot docSnapshot =
          await _plansCollection.doc(planId).get();

      if (!docSnapshot.exists) {
        print('Document $planId does not exist.');
        return null;
      }

      // Firestore のデータは Map<String, dynamic> として取得
      final data = docSnapshot.data() as Map<String, dynamic>;

      // suggestedPlan フィールドが存在するかチェック
      if (data['suggestedPlan'] != null) {
        return SuggestedPlan.fromJson(
            data['suggestedPlan'] as Map<String, dynamic>);
      } else {
        print('suggestedPlan field is null for document $planId');
        return null;
      }
    } catch (e) {
      throw e;
      // print('Error retrieving suggestedPlan: $e');
      // return null;
    }
  }
}
