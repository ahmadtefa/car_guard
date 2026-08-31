// lib/presentation/providers/customer_provider.dart
import '../../core/constants/enums.dart';

import 'package:flutter/foundation.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';

// LoadState is imported from core/constants/enums.dart

class CustomerProvider extends ChangeNotifier {
  final CustomerRepository _repo;

  CustomerProvider(this._repo);

  List<Customer> _customers = [];
  LoadState _state = LoadState.idle;
  String? _error;

  List<Customer> get customers => _customers;
  LoadState get state => _state;
  String? get error => _error;

  Future<void> loadCustomers() async {
    _state = LoadState.loading;
    _error = null;
    notifyListeners();

    final result = await _repo.getAllCustomers();
    result.fold(
      onSuccess: (list) {
        _customers = list;
        _state = LoadState.loaded;
      },
      onFailure: (f) {
        _error = f.message;
        _state = LoadState.error;
      },
    );
    notifyListeners();
  }

  Future<void> searchCustomers(String query) async {
    if (query.isEmpty) {
      await loadCustomers();
      return;
    }
    final result = await _repo.searchCustomers(query);
    result.fold(
      onSuccess: (list) {
        _customers = list;
        _state = LoadState.loaded;
      },
      onFailure: (f) {
        _error = f.message;
        _state = LoadState.error;
      },
    );
    notifyListeners();
  }

  Future<bool> createCustomer(Customer customer) async {
    final result = await _repo.createCustomer(customer);
    if (result.isSuccess) {
      await loadCustomers();
      return true;
    }
    _error = result.failure.message;
    notifyListeners();
    return false;
  }

  Future<bool> updateCustomer(Customer customer) async {
    final result = await _repo.updateCustomer(customer);
    if (result.isSuccess) {
      final idx = _customers.indexWhere((c) => c.id == customer.id);
      if (idx >= 0) _customers[idx] = result.value;
      notifyListeners();
      return true;
    }
    _error = result.failure.message;
    notifyListeners();
    return false;
  }

  Future<bool> deleteCustomer(String id) async {
    final result = await _repo.deleteCustomer(id);
    if (result.isSuccess) {
      _customers.removeWhere((c) => c.id == id);
      notifyListeners();
      return true;
    }
    return false;
  }

  Customer? getById(String id) {
    try {
      return _customers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
