import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'api_client.dart';

/// The signed-in farmer's farms and which one is currently selected.
class FarmStore extends ChangeNotifier {
  FarmStore._();

  static final FarmStore instance = FarmStore._();

  List<Farm> farms = [];
  Farm? selected;
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final data = await ApiClient.instance.get('/farms');

      farms = (data as List)
          .map((e) => Farm.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      final keep = farms.where((f) => f.id == selected?.id);

      selected = keep.isNotEmpty
          ? keep.first
          : (farms.isNotEmpty ? farms.first : null);
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void select(Farm farm) {
    selected = farm;
    notifyListeners();
  }

  Future<Farm> add({
    required String name,
    required String location,
    double? areaHectares,
  }) async {
    final data = await ApiClient.instance.post(
      '/farms',
      body: {
        'farm_name': name,
        'location': location,
        if (areaHectares != null) 'area_hectares': areaHectares,
      },
    );

    final farm = Farm.fromJson(
      Map<String, dynamic>.from((data as Map)['farm'] as Map),
    );

    farms = [...farms, farm];
    selected = farm;
    notifyListeners();

    return farm;
  }

  Future<void> update(
    int farmId, {
    required String name,
    required String location,
    double? areaHectares,
  }) async {
    final data = await ApiClient.instance.patch(
      '/farms/$farmId',
      body: {
        'farm_name': name,
        'location': location,
        if (areaHectares != null) 'area_hectares': areaHectares,
      },
    );

    final updated = Farm.fromJson(
      Map<String, dynamic>.from(data as Map),
    );

    farms = [
      for (final farm in farms)
        if (farm.id == farmId) updated else farm,
    ];

    if (selected?.id == farmId) {
      selected = updated;
    }

    notifyListeners();
  }

  void clear() {
    farms = [];
    selected = null;
    error = null;
    notifyListeners();
  }
}