// lib/domain/repositories/customer_repository.dart

import '../entities/customer.dart';
import '../../core/utils/result.dart';

abstract class CustomerRepository {
  Future<Result<List<Customer>>> getAllCustomers();
  Future<Result<Customer>> getCustomerById(String id);
  Future<Result<Customer>> createCustomer(Customer customer);
  Future<Result<Customer>> updateCustomer(Customer customer);
  Future<Result<void>> deleteCustomer(String id);
  Future<Result<List<Customer>>> searchCustomers(String query);
}
