import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:form_app/src/service/gemini_service.dart';
import 'package:intl/intl.dart' as intl;
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'domain/model/plan.dart';
import 'domain/model/plan_store.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trip Plan Form',
      home: const FormWidgetsDemo(),
    );
  }
}

class FormWidgetsDemo extends StatefulWidget {
  const FormWidgetsDemo({super.key});

  @override
  State<FormWidgetsDemo> createState() => _FormWidgetsDemoState();
}

class _FormWidgetsDemoState extends State<FormWidgetsDemo> {
  final _formKey = GlobalKey<FormState>();

  // 旅先（Autocomplete用）
  String title = '';
  // 目的（＝おすすめキーワード）の選択結果
  List<String> _selectedPurposes = [];
  // Geminiから取得したおすすめキーワード（List<String>）
  List<String> _purposeData = [];

  // 日付の初期値（今日～明日）
  DateTimeRange dateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now().add(const Duration(days: 1)),
  );

  // 予算：段階スライダー用
  int _budgetIndex = 2;
  final List<String> _budgetRanges = [
    '〜10,000円',
    '10,000円〜30,000円',
    '30,000円〜50,000円',
    '50,000円〜100,000円',
    '100,000円〜200,000円',
    '200,000円〜300,000円',
    '300,000円〜',
  ];

  // 送信中フラグ
  bool _isSubmitting = false;

  // サジェスト用
  List<String> _suggestions = [];
  Timer? _debounce;
  String _lastAPIInput = '';
  final FocusNode _autocompleteFocusNode = FocusNode();

  // おすすめキーワードデータ取得中フラグ
  bool _isLoadingPurposeData = false;

  @override
  void initState() {
    super.initState();
    _autocompleteFocusNode.addListener(() {
      if (!_autocompleteFocusNode.hasFocus) {
        // 必要に応じた処理
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _autocompleteFocusNode.dispose();
    super.dispose();
  }

  void _onSuggestionInputChanged(String input) {
    _debounce?.cancel();
    if (input.isEmpty) {
      setState(() {
        _suggestions = [];
      });
      _lastAPIInput = '';
      return;
    }
    if (input.length < _lastAPIInput.length) {
      _debounce?.cancel();
      setState(() {
        _suggestions = [];
      });
      _lastAPIInput = input;
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 100), () async {
      try {
        final geminiService = GeminiService();
        final results = await geminiService.generateSuggestions(input);
        setState(() {
          _suggestions = results;
        });
        _lastAPIInput = input;
      } catch (e) {
        debugPrint('サジェスト取得エラー: $e');
      }
    });
  }

  /// エリア情報（旅先）を元にGeminiからおすすめキーワード（List<String>）を取得する
  Future<void> _fetchPurposeData(String area) async {
    setState(() {
      _isLoadingPurposeData = true;
    });
    try {
      final geminiService = GeminiService();
      // fetchPurposeData() は List<String> を返すと仮定
      final data = await geminiService.fetchPurposeData(area);
      setState(() {
        _purposeData = data;
      });
    } catch (e) {
      debugPrint('目的データ取得エラー: $e');
    } finally {
      setState(() {
        _isLoadingPurposeData = false;
      });
    }
  }

  Future<String> submitPlanToFirebaseFunction({
    required String title,
    required String description,
    required DateTimeRange dateRange,
    required int budgetIndex,
  }) async {
    final HttpsCallable callable =
        FirebaseFunctions.instance.httpsCallable('onCallCreatePlan');
    final request = {
      "area": title,
      "purpose": description,
      "start": intl.DateFormat("yyyy-MM-dd").format(dateRange.start),
      "end": intl.DateFormat("yyyy-MM-dd").format(dateRange.end),
      "budget": _budgetRanges[budgetIndex],
      "otherRequest": "",
    };
    debugPrint('Request: $request');
    final response = await callable.call(request);
    return response.data['planId'];
  }

  Future<void> _handleSubmitPlan() async {
    if (_formKey.currentState?.validate() == false) return;
    if (_selectedPurposes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('おすすめキーワードを選択してください')),
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      final planId = await submitPlanToFirebaseFunction(
        title: title,
        description: _selectedPurposes.join(', '),
        dateRange: dateRange,
        budgetIndex: _budgetIndex,
      );
      final plan = Plan(
        planId: planId,
        title: title,
        description: _selectedPurposes.join(', '),
        dateRange: dateRange,
        budgetIndex: _budgetIndex,
      );
      await PlanStore.savePlan(plan);
      debugPrint('Saved planId: $planId');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プラン作成をAIに依頼しました')),
        );
      }
      if (context.mounted) {
        context.go('/');
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プラン作成に失敗しました')),
        );
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プラン作成'),
      ),
      body: Form(
        key: _formKey,
        child: Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 旅先（Autocomplete）
                  Row(
                    children: [
                      const Icon(Icons.place),
                      const SizedBox(width: 8),
                      Text(
                        '旅先',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      return Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          return _suggestions;
                        },
                        optionsViewBuilder: (
                          BuildContext context,
                          AutocompleteOnSelected<String> onSelected,
                          Iterable<String> options,
                        ) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              child: Container(
                                width: constraints.maxWidth,
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  physics: const ClampingScrollPhysics(),
                                  padding: const EdgeInsets.all(8.0),
                                  itemCount: options.length,
                                  itemBuilder: (BuildContext context, int index) {
                                    final String option = options.elementAt(index);
                                    return ListTile(
                                      title: Text(option),
                                      onTap: () {
                                        onSelected(option);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                        onSelected: (String selection) {
                          // 旅先確定時：タイトルをセットし、既存のおすすめキーワードデータと選択結果をリセットして取得開始
                          setState(() {
                            title = selection;
                            _purposeData = [];
                            _selectedPurposes = [];
                          });
                          _fetchPurposeData(selection);
                        },
                        fieldViewBuilder: (
                          BuildContext context,
                          TextEditingController fieldTextEditingController,
                          FocusNode fieldFocusNode,
                          VoidCallback onFieldSubmitted,
                        ) {
                          // 入力が変更された場合、既存のおすすめキーワードデータを即座にリセット
                          fieldTextEditingController.addListener(() {
                            if (fieldTextEditingController.text != title) {
                              setState(() {
                                _purposeData = [];
                              });
                            }
                          });
                          return TextFormField(
                            controller: fieldTextEditingController,
                            focusNode: fieldFocusNode,
                            decoration: const InputDecoration(
                              filled: true,
                              hintText: '旅先を入力してください',
                              labelText: '例：沖縄や北海道など',
                            ),
                            onChanged: (value) {
                              _onSuggestionInputChanged(value);
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '旅先を入力してください';
                              }
                              return null;
                            },
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // おすすめキーワード選択セクション
                  Row(
                    children: [
                      const Icon(Icons.flag),
                      const SizedBox(width: 8),
                      Text(
                        'おすすめキーワード',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 旅先未入力またはおすすめキーワードデータが空の場合はプレースホルダー表示
                  (title.isEmpty || _purposeData.isEmpty)
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade200,
                          ),
                          child: const Text(
                            "旅先を入力するとキーワードが表示されます",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : PurposeSlotSelector(
                          purposes: _purposeData,
                          selectedPurposes: _selectedPurposes,
                          onSelectionChanged: (selected) {
                            setState(() {
                              _selectedPurposes = selected;
                            });
                          },
                        ),
                  const SizedBox(height: 24),
                  // 日付
                  Row(
                    children: [
                      const Icon(Icons.calendar_today),
                      const SizedBox(width: 8),
                      Text(
                        '期間',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  _FormDateRangePicker(
                    dateRange: dateRange,
                    onChanged: (newRange) {
                      setState(() {
                        dateRange = newRange;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  // 予算
                  Row(
                    children: [
                      const Icon(Icons.attach_money),
                      const SizedBox(width: 8),
                      Text(
                        '予算',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  Text(
                    _budgetRanges[_budgetIndex],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: _budgetIndex.toDouble(),
                    min: 0,
                    max: (_budgetRanges.length - 1).toDouble(),
                    divisions: _budgetRanges.length - 1,
                    label: _budgetRanges[_budgetIndex],
                    onChanged: (value) {
                      setState(() {
                        _budgetIndex = value.toInt();
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  // 送信ボタン
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmitPlan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('プラン作成を依頼する', style: TextStyle(color: Colors.white),),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// おすすめキーワード選択ウィジェット（選択済みはChipで×アイコン付き）
class PurposeSlotSelector extends StatelessWidget {
  final List<String> purposes;
  final List<String> selectedPurposes;
  final ValueChanged<List<String>> onSelectionChanged;

  const PurposeSlotSelector({
    Key? key,
    required this.purposes,
    required this.selectedPurposes,
    required this.onSelectionChanged,
  }) : super(key: key);

  void _openSelectionModal(BuildContext context) async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      builder: (context) {
        return _SlotSelectionModal(
          purposes: purposes,
          initialSelected: selectedPurposes,
        );
      },
    );
    if (result != null) {
      onSelectionChanged(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: purposes.isEmpty ? null : () => _openSelectionModal(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
          color: purposes.isEmpty ? Colors.grey.shade200 : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: selectedPurposes.isEmpty
                  ? const Text(
                      "キーワードを選びましょう",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    )
                  : Wrap(
                      spacing: 4,
                      children: selectedPurposes.map((p) {
                        return Chip(
                          label: Text(p),
                          deleteIcon: const Icon(
                            Icons.close,
                            size: 18,
                          ),
                          onDeleted: () {
                            final newSelected = List<String>.from(selectedPurposes);
                            newSelected.remove(p);
                            onSelectionChanged(newSelected);
                          },
                        );
                      }).toList(),
                    ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

/// おすすめキーワード選択用モーダル（PageView で1ページあたり6個：3列×2行、ページインジケーター付き）
class _SlotSelectionModal extends StatefulWidget {
  final List<String> purposes;
  final List<String> initialSelected;

  const _SlotSelectionModal({
    Key? key,
    required this.purposes,
    required this.initialSelected,
  }) : super(key: key);

  @override
  _SlotSelectionModalState createState() => _SlotSelectionModalState();
}

class _SlotSelectionModalState extends State<_SlotSelectionModal> {
  late List<bool> _selectedFlags;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _selectedFlags =
        widget.purposes.map((p) => widget.initialSelected.contains(p)).toList();
  }

  void _toggleSelection(int index) {
    setState(() {
      _selectedFlags[index] = !_selectedFlags[index];
    });
  }

  @override
  Widget build(BuildContext context) {
    int itemsPerPage = 6;
    int totalPages = (widget.purposes.length / itemsPerPage).ceil();

    return SafeArea(
      child: SizedBox(
        height: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "おすすめキーワードを選択",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 250,
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.horizontal,
                itemCount: totalPages,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                itemBuilder: (context, pageIndex) {
                  int startIndex = pageIndex * itemsPerPage;
                  int endIndex = min(startIndex + itemsPerPage, widget.purposes.length);
                  List<int> indices = List.generate(endIndex - startIndex, (i) => startIndex + i);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GridView.count(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.0,
                      children: indices.map((index) {
                        return _SlotItem(
                          label: widget.purposes[index],
                          isSelected: _selectedFlags[index],
                          onTap: () => _toggleSelection(index),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(totalPages, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  width: 8.0,
                  height: 8.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index ? Colors.lightGreen : Colors.grey,
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                List<String> selected = [];
                for (int i = 0; i < widget.purposes.length; i++) {
                  if (_selectedFlags[i]) {
                    selected.add(widget.purposes[i]);
                  }
                }
                Navigator.pop(context, selected);
              },
              child: const Text("決定"),
            ),
          ],
        ),
      ),
    );
  }
}

/// スロット風アイテム（タップ時に回転アニメーション、テキストは常に正しい向き・中央揃え）
class _SlotItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SlotItem({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  _SlotItemState createState() => _SlotItemState();
}

class _SlotItemState extends State<_SlotItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300), 
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut)
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _handleTap() {
    _controller.forward(from: 0).then((_) {
      widget.onTap();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          double angle = _animation.value * 3.1415;
          return Transform(
            transform: Matrix4.rotationX(angle),
            alignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                color: widget.isSelected ? Colors.teal : Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Transform(
                transform: Matrix4.rotationX(-angle),
                alignment: Alignment.center,
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: widget.isSelected ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 日付ピッカーウィジェット（変更なし）
class _FormDateRangePicker extends StatelessWidget {
  final DateTimeRange dateRange;
  final ValueChanged<DateTimeRange> onChanged;

  const _FormDateRangePicker({
    required this.dateRange,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final start = dateRange.start;
    final end = dateRange.end;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${intl.DateFormat("yyyy年MM月dd日").format(start)} ～ ${intl.DateFormat("yyyy年MM月dd日").format(end)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        TextButton(
          child: const Text('Edit'),
          onPressed: () async {
            final newDateRange = await showDateRangePicker(
              context: context,
              initialDateRange: dateRange,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (newDateRange == null) return;
            onChanged(newDateRange);
          },
        ),
      ],
    );
  }
}
