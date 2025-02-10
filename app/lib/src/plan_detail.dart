// plan_detail_page.dart
import 'package:flutter/material.dart';
import 'package:form_app/src/domain/model/suggested_plan.dart'; // SuggestedPlan, Schedule, Spot, Review などが定義されている
import 'package:intl/intl.dart' as intl;
import 'package:flutter_rating_bar/flutter_rating_bar.dart'; // flutter_rating_bar を利用

import 'domain/model/plan.dart';

class PlanDetail extends StatelessWidget {
  final Plan plan;
  final SuggestedPlan suggestedPlan;
  const PlanDetail({Key? key, required this.plan, required this.suggestedPlan})
      : super(key: key);

  static const List<String> budgetRanges = [
    '〜10,000円',
    '10,000円〜30,000円',
    '30,000円〜50,000円',
    '50,000円〜100,000円',
    '100,000円〜200,000円',
    '200,000円〜300,000円',
    '300,000円〜',
  ];

  @override
  Widget build(BuildContext context) {
    final mergedTitle = plan.title.trim().isNotEmpty
        ? plan.title
        : suggestedPlan.name;
    final period =
        '${intl.DateFormat("yyyy年MM月dd日").format(plan.dateRange!.start)} ～ ${intl.DateFormat("yyyy年MM月dd日").format(plan.dateRange!.end)}';
    final userBudget =
        (plan.budgetIndex >= 0 && plan.budgetIndex < budgetRanges.length)
            ? budgetRanges[plan.budgetIndex]
            : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('AIおすすめのプラン'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Padding(
          // 横幅100%で表示するため、横paddingは16のみ
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー情報
              _buildUnifiedItem(
                context,
                icon: Icons.location_on,
                label: '旅先',
                value: mergedTitle,
              ),
              _buildUnifiedItem(
                context,
                icon: Icons.location_city,
                label: 'エリア',
                value: suggestedPlan.area,
              ),
              _buildUnifiedItem(
                context,
                icon: Icons.edit,
                label: 'テーマ',
                value: suggestedPlan.theme,
              ),
              _buildUnifiedItem(
                context,
                icon: Icons.description,
                label: '概要',
                value: suggestedPlan.description,
              ),
              _buildUnifiedItem(
                context,
                icon: Icons.date_range,
                label: '期間',
                value: period,
              ),
              _buildUnifiedItem(
                context,
                icon: Icons.attach_money,
                label: '予算',
                value: userBudget,
              ),
              const SizedBox(height: 16),
              _buildScheduleHeader(context),
              _buildScheduleSection(context, suggestedPlan.schedule),
              // 注意事項（caution は List<dynamic> として渡される想定）
              _buildCautionList(
                context,
                icon: Icons.warning,
                label: '注意事項',
                cautionList: suggestedPlan.caution,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 統一項目を、項目名と内容の行に分けて表示するウィジェット（ラベルは太字）
  Widget _buildUnifiedItem(BuildContext context,
      {required IconData icon, required String label, required String value}) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }

  /// 注意事項をリスト形式で表示するウィジェット
  Widget _buildCautionList(BuildContext context,
      {required IconData icon, required String label, required List<dynamic> cautionList}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: cautionList
                  .map((item) => Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("• ", style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                          Expanded(child: Text(item, style: Theme.of(context).textTheme.bodyLarge)),
                        ],
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// スケジュールヘッダー：左にアイコンを配置して表示、文字は太字
  Widget _buildScheduleHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            'スケジュール',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// スケジュールセクション：各スケジュールをリスト表示
  Widget _buildScheduleSection(BuildContext context, List<Schedule> schedules) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: schedules.map((schedule) {
        // 日付文字列を DateTime に変換してフォーマット
        final DateTime scheduleDate = DateTime.parse(schedule.date);
        final String formattedDate = intl.DateFormat("yyyy年MM月dd日").format(scheduleDate);
        return ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          // タイトルに日付、スケジュール名、エリアを表示
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formattedDate,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.normal),
              ),
              const SizedBox(height: 4),
              Text(
                "${schedule.name} (${schedule.area})",
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _buildScheduleDetail(context, schedule),
          ],
        );
      }).toList(),
    );
  }

  /// スケジュール詳細の表示ウィジェット（各スポットの情報を表示）
  Widget _buildScheduleDetail(BuildContext context, Schedule schedule) {
    List<Widget> detailWidgets = [];

    // もともと実装されていた「1日のテーマ」の表示（schedule.description）
    if (schedule.description.trim().isNotEmpty) {
      detailWidgets.add(
        _buildUnifiedItem(
          context,
          icon: Icons.star,
          label: '1日のテーマ',
          value: schedule.description,
        ),
      );
      detailWidgets.add(const SizedBox(height: 8));
    }

    // 新たに追加された dayFlow が存在する場合、FlowChart を利用して表示
    if (schedule.dayFlow.isNotEmpty) {
      detailWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: FlowChart(items: schedule.dayFlow),
        ),
      );
      detailWidgets.add(const SizedBox(height: 8));
    }

    detailWidgets.add(
      _buildUnifiedItem(
        context,
        icon: Icons.attach_money,
        label: '一日の予算',
        // minPrice と maxPrice の存在すれば「最小価格〜最大価格」と表示
        // どちらかが null の場合は残っている方を表示
        // どちらも null の場合は「現地でお問い合わせください」と表示
        value: schedule.dayBudget.toString() + '円',
      ),
    );

    // その下に各スポットの詳細を表示（従来の実装）
    for (var i = 0; i < schedule.spot.length; i++) {
      final Spot spot = schedule.spot[i];
      detailWidgets.add(_buildSpotItem(context, spot, i+1));
      if (i < schedule.spot.length - 1) detailWidgets.add(const Divider());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: detailWidgets,
    );
  }

  /// 各スポットの詳細を統一デザインで表示するウィジェット
  Widget _buildSpotItem(BuildContext context, Spot spot, int number) {
    List<Widget> items = [];
    items.add(
      _buildUnifiedItem(
        context,
        icon: Icons.place,
        label: number.toString() + '個目の訪問スポット',
        value: spot.name,
      ),
    );
    items.add(
      _buildUnifiedItem(
        context,
        icon: Icons.local_activity,
        label: 'アクティビティ',
        value: spot.activity,
      ),
    );
    // ラベルを「おすすめポイント」に変更
    items.add(
      _buildUnifiedItem(
        context,
        icon: Icons.info_outline,
        label: 'おすすめポイント',
        value: spot.reason,
      ),
    );
    // 全体評価（rating, ratingCount）が存在すれば表示
    if (spot.rating != null && spot.ratingCount != null) {
      items.add(
        _buildOverallRatingSection(
          context,
          spot.rating!,
          spot.ratingCount!,
        ),
      );
    }
    // レビューが存在すれば表示（Spot.review は List<Review>）
    if (spot.review.isNotEmpty) {
      items.add(_buildReviewsSection(context, spot.review));
    }
    // items.add(
    //   _buildUnifiedItem(
    //     context,
    //     icon: Icons.schedule,
    //     label: '営業時間',
    //     value: spot.businessHours.join(', '),
    //   ),
    // );
    // items.add(
    //   _buildUnifiedItem(
    //     context,
    //     icon: Icons.timer,
    //     label: '所要時間',
    //     value: '${spot.duration}分',
    //   ),
    // );
    // items.add(
    //   _buildUnifiedItem(
    //     context,
    //     icon: Icons.attach_money,
    //     label: '価格',
    //     // minPrice と maxPrice の存在すれば「最小価格〜最大価格」と表示
    //     // どちらかが null の場合は残っている方を表示
    //     // どちらも null の場合は「現地でお問い合わせください」と表示
    //     value:
    //         spot.minPrice != null && spot.maxPrice != null ? '${spot.minPrice}円〜${spot.maxPrice}円' : spot.minPrice != null ? '${spot.minPrice}円' : spot.maxPrice != null ? '${spot.maxPrice}円' : '現地でお問い合わせください',
    //   ),
    // );
    // 画像表示部分：全幅表示
    if (spot.photoUri != null && spot.photoUri!.isNotEmpty) {
      final String photoUrl = spot.photoUri!;
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Image.network(
            photoUrl,
            height: 150,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
  
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }

  /// 各スポットのレビューを、横幅いっぱいで表示するウィジェット
  Widget _buildReviewsSection(BuildContext context, List<Review> reviews) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: reviews.map((review) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              Icon(Icons.person, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 数値評価と星アイコンを表示
                  // Row(
                  //   children: [
                  //     Text(
                  //       review.rating.toStringAsFixed(1),
                  //       style: Theme.of(context).textTheme.bodyMedium,
                  //     ),
                  //     const SizedBox(width: 8),
                  //     _buildRatingBar(review.rating, size: 16.0),
                  //   ],
                  // ),
                  // const SizedBox(height: 4),
                  Text(
                  review.text ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                ),
              ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 全体評価（評価値と星アイコン、件数）を表示するウィジェット
  Widget _buildOverallRatingSection(BuildContext context, double rating, int ratingCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '評価',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Row(
              children: [
                Text(rating.toStringAsFixed(1), style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(width: 8),
                _buildRatingBar(rating, size: 16.0),
                const SizedBox(width: 8),
                Text('($ratingCount 件)', style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// RatingBarIndicator を使って星評価を表示するウィジェット（最大5、0.1刻み対応）
  Widget _buildRatingBar(double rating, {double size = 16.0}) {
    return RatingBarIndicator(
      rating: rating,
      itemBuilder: (context, index) => const Icon(Icons.star, color: Colors.amber),
      itemCount: 5,
      itemSize: size,
      direction: Axis.horizontal,
    );
  }
}

/// FlowChart ウィジェット：指定された文字列リストを縦方向に、長方形と縦の線で表示する
class FlowChart extends StatelessWidget {
  final List<DayFlow> items;

  const FlowChart({Key? key, required this.items}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 各アイテムを組み立てる
    List<Widget> children = [];
    for (int i = 0; i < items.length; i++) {
      if (i > 0) {
        children.add(_buildLine());
      }
      children.add(_buildRect(items[i]));
    }

    // 縦方向のスクロールビューで Column を返す
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    );
  }

  /// 長方形ウィジェット：横幅最大、spotImageUrl があれば背景画像＋黒い半透明オーバーレイ、その上に開始時刻（左寄せ）とラベル（中央寄せ）を表示
  Widget _buildRect(DayFlow dayFlow) {
    final hasImage =
        dayFlow.spotImageUrl != null && dayFlow.spotImageUrl!.isNotEmpty && dayFlow.spotImageUrl!.startsWith('http');
    return Container(
      width: double.infinity, // 横幅最大
      height: 60, // 適宜調整してください
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Stack(
        children: [
          // 背景：画像がある場合は画像、ない場合は teal の背景色
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: hasImage ? null : Colors.teal,
                image: hasImage
                    ? DecorationImage(
                        image: NetworkImage(dayFlow.spotImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          // 画像がある場合は黒い半透明オーバーレイ
          if (hasImage)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          // 開始時刻（startTime）：左寄せ
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                dayFlow.startTime, // startTime プロパティを表示
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          // ラベル（label）：中央寄せ
          Center(
            child: Padding(
              // 横幅に少しマージンがほしい
              padding: const EdgeInsets.all(4.0),
              child: Text(
                insertLineBreaks(dayFlow.label),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String insertLineBreaks(String text, {int step = 10}) {
  // 10文字以下なら改行せずそのまま返す
  if (text.length <= step) return text;

  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i += step) {
    final end = (i + step < text.length) ? i + step : text.length;
    // 現在の部分文字列を追加
    buffer.write(text.substring(i, end));
    // まだ残りがある場合は改行を入れる
    if (end != text.length) {
      buffer.write('\n');
    }
  }
  return buffer.toString();
}


  /// 長方形同士をつなぐ縦の線ウィジェット（teal 色）
  Widget _buildLine() {
    return Container(
      width: 2,
      height: 15,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.teal,
    );
  }
}

