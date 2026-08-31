# Solar Manager 🌞

**نظام إدارة محطات الطاقة الشمسية**

A comprehensive Flutter application for managing solar energy stations. Built with Clean Architecture, Offline-First approach, and ready for Cloud sync.

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK ≥ 3.5.0
- Dart SDK ≥ 3.5.0
- Android Studio / VS Code with Flutter plugin

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/ahmadtefa/solar_manager.git
cd solar_manager

# 2. Install dependencies
flutter pub get

# 3. Generate database code (required!)
flutter pub run build_runner build --delete-conflicting-outputs

# 4. Run the app
flutter run
```

### Running Tests

```bash
flutter test
flutter analyze
```

---

## 🏗️ Architecture

```
lib/
├── core/
│   ├── constants/       # App constants, status keys
│   ├── errors/          # Failure types
│   ├── extensions/      # DateTime, String extensions
│   ├── theme/           # App theme (colors, typography)
│   └── utils/           # Money, IdGenerator, Result
│
├── data/
│   ├── database/
│   │   ├── app_database.dart    # Drift DB (run build_runner)
│   │   └── tables/              # 13 database tables
│   ├── models/                  # Row → Entity mappers
│   └── repositories/            # Repository implementations
│
├── domain/
│   ├── entities/               # Pure Dart business objects
│   ├── repositories/           # Repository interfaces (abstract)
│   └── usecases/               # (Phase 2 additions)
│
└── presentation/
    ├── providers/               # ChangeNotifier state management
    ├── screens/                 # UI screens
    │   ├── dashboard/
    │   ├── stations/
    │   ├── customers/
    │   ├── items/
    │   ├── expenses/
    │   └── settings/
    └── widgets/common/          # Reusable widgets
```

---

## 📦 Packages Used

| Package | Version | Purpose |
|---------|---------|---------|
| `drift` | ^2.21.0 | SQLite ORM - Offline First database |
| `drift_flutter` | ^0.2.4 | Flutter-specific Drift setup |
| `sqlite3_flutter_libs` | ^0.5.24 | SQLite native libraries |
| `provider` | ^6.1.2 | State management (simple & stable) |
| `uuid` | ^4.5.1 | Unique ID generation |
| `intl` | ^0.19.0 | Date formatting, localization |
| `decimal` | ^2.3.3 | Precise financial arithmetic |
| `equatable` | ^2.0.7 | Value equality for entities |
| `path_provider` | ^2.1.4 | App directory paths |
| `path` | ^1.9.0 | Path utilities |
| `file_picker` | ^8.1.4 | File import (Phase 4) |
| `share_plus` | ^10.0.3 | File export/sharing (Phase 4) |
| `archive` | ^3.6.1 | ZIP export for stations (Phase 4) |

---

## 🗄️ Database Schema

13 tables with full migration support:

- `customers` - Customer management
- `stations` - Station records
- `station_items` - Items in each station (price snapshots)
- `item_catalog` - Master items catalog
- `item_categories` - User-configurable categories
- `expenses` - Station expenses
- `expense_categories` - User-configurable expense types
- `station_photos` - Photo management
- `station_documents` - Document management
- `price_history` - Historical price tracking
- `station_history` - Audit log
- `project_statuses` - User-configurable statuses
- `users` - Multi-user ready

---

## 💰 Financial Model

All monetary values stored as **integer millimes** (1 EGP = 1000 millimes) to avoid floating-point errors.

```
Total = (Quantity × UnitPriceSnapshot) - Discount + Tax

Profit = NetSellingValue - TotalActualCost

ProfitMargin% = (Profit / NetSellingValue) × 100
```

**Price Snapshots**: When an item is added to a station, the current price is captured as a snapshot. Future catalog price changes do NOT affect historical station data.

---

## 📱 Features (Phase 1)

- ✅ Offline-First Architecture
- ✅ Customer Management (CRUD)
- ✅ Station Management (CRUD)
- ✅ Items Catalog (with user-defined categories)
- ✅ Station Items (with price snapshots)
- ✅ Expense Management
- ✅ Financial Summary (auto-calculated)
- ✅ Dashboard with statistics
- ✅ Search & Filter
- ✅ RTL Arabic UI
- ✅ Clean Architecture
- ✅ Repository Pattern
- ✅ Unit Tests for financial calculations

## 🗺️ Roadmap

- **Phase 2**: Complete UI polishing, photos, documents
- **Phase 3**: PDF generation
- **Phase 4**: Import/Export (.station files), sharing
- **Phase 5**: Audit history
- **Phase 6**: Offline sync architecture
- **Phase 7**: Backend API integration

---

## 🧪 Tests

```
test/
├── unit/
│   ├── money_test.dart           # Financial calculations
│   ├── station_item_test.dart    # Item totals with discount/tax
│   ├── financial_summary_test.dart # Profit & margin calculations
│   ├── id_generator_test.dart    # UUID & station numbers
│   └── result_test.dart          # Result/Either pattern
└── widget_test.dart              # Basic widget tests
```

---

## 👥 Multi-User Ready

The architecture supports multiple users via `users` table and `created_by`/`modified_by` fields. Conflict detection uses `revision_number` + `last_modified_at`.

---

*Made with ❤️ for the Solar Energy industry*
