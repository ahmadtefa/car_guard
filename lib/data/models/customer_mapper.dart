// lib/data/models/customer_mapper.dart

import '../database/app_database.dart';
import '../../domain/entities/customer.dart';

extension CustomerRowMapper on CustomerRow {
  Customer toDomain() {
    return Customer(
      id: id,
      name: name,
      phone: phone,
      phoneAlt: phoneAlt,
      email: email,
      address: address,
      governorate: governorate,
      city: city,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      revisionNumber: revisionNumber,
      lastModifiedAt: lastModifiedAt,
      lastModifiedBy: lastModifiedBy,
    );
  }
}

extension CustomerMapper on Customer {
  CustomersTableCompanion toCompanion() {
    return CustomersTableCompanion(
      id: Value(id),
      name: Value(name),
      phone: Value(phone),
      phoneAlt: Value(phoneAlt),
      email: Value(email),
      address: Value(address),
      governorate: Value(governorate),
      city: Value(city),
      notes: Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      createdBy: Value(createdBy),
      revisionNumber: Value(revisionNumber),
      lastModifiedAt: Value(lastModifiedAt),
      lastModifiedBy: Value(lastModifiedBy),
    );
  }
}
