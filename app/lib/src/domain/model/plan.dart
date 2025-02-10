import 'package:flutter/material.dart';

class Plan {
  final String planId;
  final String title;
  final String description;
  final DateTimeRange? dateRange;
  final int budgetIndex;

  Plan({
    required this.planId,
    required this.title,
    required this.description,
    required this.dateRange,
    required this.budgetIndex,
  });

  Map<String, dynamic> toJson() => {
        'planId': planId,
        'title': title,
        'description': description,
        'dateRangeStart': dateRange?.start.toIso8601String(),
        'dateRangeEnd': dateRange?.end.toIso8601String(),
        'budgetIndex': budgetIndex,
      };

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
        planId: json['planId'],
        title: json['title'],
        description: json['description'],
        dateRange: (json['dateRangeStart'] != null && json['dateRangeEnd'] != null)
            ? DateTimeRange(
                start: DateTime.parse(json['dateRangeStart']),
                end: DateTime.parse(json['dateRangeEnd']),
              )
            : null,
        budgetIndex: json['budgetIndex'],
      );
}