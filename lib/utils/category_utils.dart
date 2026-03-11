import 'package:flutter/material.dart';

import '../models/department.dart';

class CategoryUtils {
  static IconData getIcon(DepartmentCategory category) {
    switch (category) {
      case DepartmentCategory.health:
        return Icons.health_and_safety;
      case DepartmentCategory.education:
        return Icons.school;
      case DepartmentCategory.transportation:
        return Icons.directions_car;
      case DepartmentCategory.finance:
        return Icons.attach_money;
      case DepartmentCategory.security:
        return Icons.security;
      case DepartmentCategory.environment:
        return Icons.eco;
      case DepartmentCategory.agriculture:
        return Icons.agriculture;
      case DepartmentCategory.socialServices:
        return Icons.people;
      case DepartmentCategory.defense:
        return Icons.shield;
      case DepartmentCategory.justice:
        return Icons.gavel;
      case DepartmentCategory.commerce:
        return Icons.business;
      case DepartmentCategory.labor:
        return Icons.work;
      case DepartmentCategory.energy:
        return Icons.bolt;
      case DepartmentCategory.housing:
        return Icons.home;
      case DepartmentCategory.veterans:
        return Icons.military_tech;
      case DepartmentCategory.other:
        return Icons.category;
    }
  }

  static List<Color> getGradient(DepartmentCategory category) {
    switch (category) {
      case DepartmentCategory.health:
        return [const Color(0xFFf093fb), const Color(0xFFf5576c)];
      case DepartmentCategory.education:
        return [const Color(0xFF4facfe), const Color(0xFF00f2fe)];
      case DepartmentCategory.transportation:
        return [const Color(0xFF43e97b), const Color(0xFF38f9d7)];
      case DepartmentCategory.finance:
        return [const Color(0xFFfa709a), const Color(0xFFfee140)];
      case DepartmentCategory.security:
        return [const Color(0xFF667eea), const Color(0xFF764ba2)];
      case DepartmentCategory.environment:
        return [const Color(0xFF00c6ff), const Color(0xFF0072ff)];
      case DepartmentCategory.agriculture:
        return [const Color(0xFF88d3ce), const Color(0xFF6e45e2)];
      case DepartmentCategory.socialServices:
        return [const Color(0xFFfbc2eb), const Color(0xFFa6c1ee)];
      case DepartmentCategory.defense:
        return [const Color(0xFF30cfd0), const Color(0xFF330867)];
      case DepartmentCategory.justice:
        return [const Color(0xFFa8edea), const Color(0xFFfed6e3)];
      case DepartmentCategory.commerce:
        return [const Color(0xFFff9a9e), const Color(0xFFfecfef)];
      case DepartmentCategory.labor:
        return [const Color(0xFF4facfe), const Color(0xFF00f2fe)];
      case DepartmentCategory.energy:
        return [const Color(0xFFffecd2), const Color(0xFFfcb69f)];
      case DepartmentCategory.housing:
        return [const Color(0xFFa1c4fd), const Color(0xFFC2e9fb)];
      case DepartmentCategory.veterans:
        return [const Color(0xFFfbc7d4), const Color(0xFF9796f0)];
      case DepartmentCategory.other:
        return [const Color(0xFFe0c3fc), const Color(0xFF8ec5fc)];
    }
  }
}
