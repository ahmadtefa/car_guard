# 📘 ملف الشرح الشامل لمشروع Car Guard

> **ملاحظة للـ AI:** اقرأ هذا الملف كاملاً أولًا، ثم افتح المستودع على GitHub.
> كل المسارات المذكورة هنا نسبية لجذر المستودع.
> الكود مكتوب بـ **Dart / Flutter** للتطبيق و**C++ (Arduino)** للفيرموير.
> المستودع: `ahmadtefa/car_guard`

---

## 1) نظرة عامة على المشروع

**Car Guard** هو نظام مراقبة سيارة يتكوّن من جزأين:

1. **جهاز هاردوير** مبني على **ESP8266 (NodeMCU)** يتصل بحساسات السيارة:
   - حساس حرارة المحرك **DS18B20**.
   - **مقسم جهد** على بطارية السيارة (12V) يُقرأ عبر `A0`.
   - **ريلاي/مروحة التبريد**.
   - **بازر/صفارة إنذار**.
   - (اختياري) حساس مستوى سائل التبريد.
2. **تطبيق موبايل بـ Flutter** يتصل بالجهاز عبر **Wi-Fi** ويعرض القراءات لحظيًّا،
   مع تنبيهات، تحليلات، توقعات، وعدّاد سرعة GPS.

الهدف: مراقبة درجة حرارة المحرك وجهد البطارية وتشغيل المروحة تلقائيًّا وإطلاق
إنذار عند الخطر، مع واجهة عربية/إنجليزية غنية ولوحة عدّادات وأنظمة تنبيه متقدمة.

---

## 2) الفيرموير (الجهاز) — `firmware/car_guard/car_guard.ino`

### 2.1 الهاردوير والتوصيل

| الإشارة | Pin (ESP8266) | ملاحظات |
| --- | --- | --- |
| DS18B20 data | **D1 = GPIO5** | بمقاومة 4.7kΩ pull-up إلى 3.3V |
| البازر النشط (HIGH = ON) | **D2 = GPIO4** | digitalWrite فقط، بدون tone() |
| ريلاي المروحة | **D3 = GPIO0** |  |
| دخل مقسم الجهد | **A0** | 0–1.024V بعد المقسم |
| LED الحالة | **D4 = GPIO2 (BUILTIN_LED)** | LOW = مضيء |

### 2.2 الشبكة الافتراضية

- **SSID:** `CarGaurd` (خطأ إملائي مقصود/متعمّد في الكود — لا تغيّره)
- **كلمة السر:** `12345678`
- **IP الجهاز:** `192.168.4.1`
- **HTTP:** المنفذ `80`
- **WebSocket:** المنفذ `81`
- **mDNS:** يعلن عن نفسه كـ `car_guard.local` (عند الاتصال بـ STA/hotspot)
  مع خدمات `_http._cp` على 80 و`_ws._tcp` على 81.

### 2.3 المكتبات المطلوبة (Arduino)

`OneWire`, `DallasTemperature`, `WebSocketsServer` (links2004)،
ومكتبات نواة ESP8266: `ESP8266WiFi`, `ESP8266WebServer`,
`ESP8266HTTPUpdateServer`, `ESP8266mDNS`, `DNSServer`, `EEPROM`.

### 2.4 القيم الافتراضية للحساسات والإعدادات

- `MAX_TEMP = 97.0` (درجة الإنذار)
- `FAN_ON_TEMP = 90.0` (تشغيل المروحة مع **hysteresis 5°C**)
- `MIN_VOLT = 12.0`, `MAX_VOLT = 14.8`
- `tempOffset = 0.0`
- مقسم الجهد: `VREF = 3.3`, `ADC_MAX = 1023`, والجهد الفعلي:
  `Vin = (ADC/1023 * 3.3) * ((R1+R2)/R2) * voltCalib`
- فلترة البرمجيات للقراءات:
  `filtered = filtered*0.7 + raw*0.3` (لكن الحرارة والجهد)
- قراءة الجهد = متوسط 10 عينات.
- الحرارة تُقرأ كل **ثانية** مع انتظار تحويل الحساس حتى 750ms.

### 2.5 منطق الإنذار والمروحة

- **إنذار الحرارة:** `filteredTemp >= MAX_TEMP`.
- **إنذار الجهد:** خارج النطاق لمدة ثانيتين متواصلتين (2s debounce).
- البازر ينبض **200ms ON / 200ms OFF** أثناء الخطر (إذا لم يُكتم).
- المروحة تُشغَّل عند `FAN_ON_TEMP` وتفصل عند `FAN_ON_TEMP - 5`.
- `/mute` يكتم البازر حتى يزول الخطر (ثم يعود تلقائيًّا).
- `alarmActive` و`buzzMuted` يُرسلان للتطبيق لمزامنة الحالة.

### 2.6 بروتوكول البيانات (مهم جدًا)

#### WebSocket — CSV (11 حقل):

```
temp,volt,fanState,?,maxTemp,fanOnTemp,minVolt,maxVolt,offset,alarm,muted
```

مثال: `92.50,12.17,1,0,97.0,90.0,12.0,14.8,0.00,0,0`

- الحقل الرابع `?` محجوز (يُرسل 0).
- الحقلان `alarm` و`muted` هما إضافات **[APP SYNC]** في آخر الـ CSV.
- البث يحدث فقط عند تغيّر الحرارة ≥ 0.5°C أو الجهد ≥ 0.1V (توفير للبطارية).

#### HTTP `GET /data` — JSON:

```json
{
  "temp": 92.5,
  "volt": 12.58,
  "voltDiff": 0.12,
  "fanState": 1,
  "buzzerState": 0,
  "alarm": 0,
  "muted": 0,
  "coolant": 1,
  "maxTemp": 97.0,
  "fanOnTemp": 90.0,
  "minVolt": 12.0,
  "maxVolt": 14.8,
  "offset": 0.0
}
```

> ملاحظة: في إصدارات فيرموير أحدث، تطبيق فلتر يستقبل أيضًا `speed`/`speedKmh`
> (لكن الفيرموير الحالي لا يرسل سرعة — السرعة تأتي من **GPS الموبايل** فقط).

#### كل Endpoints (المسارات في `DeviceEndpoints`):

| Endpoint | الوظيفة |
| --- | --- |
| `GET /data` | القراءات الحية + حدود الإنذار (JSON) |
| `GET /getallsettings` | كل الإعدادات + الرقم التسلسلي + تاريخ التركيب + R1/R2 |
| `GET /saveallsettings?maxTemp=&fanOnTemp=&minVolt=&maxVolt=&offset=` | حفظ حدود الإنذار |
| `GET /saveadvancedsettings?offset=&voltCalib=&r1=&r2=&sensorPullUp=&installDate=` | المعايرة المتقدمة |
| `GET /calibratevoltage?realVolt=` | معالج معايرة الجهد (8–18V) |
| `GET /getwifisettings` / `GET /savewifi?ssid=&password=` | بيانات AP |
| `GET /joinwifi?ssid=&pass=` | ضبط شبكة STA (هوتسبوت/راوتر) |
| `GET /testfan` | تشغيل المروحة 5 ثوانٍ |
| `GET /mute` | كتم البازر حتى زوال الخطر |
| `GET /restart` | إعادة تشغيل الجهاز |
| `GET /factoryreset` | ضبط المصنع |
| `GET /update` | صفحة OTA لرفع فيرموير جديد |

نطاقات القيم المفروضة من الفيرموير:
- حرارة الإنذار 50–150°C
- حرارة المروحة 40–140°C
- أقل جهد 8.0–14.0V
- أعلى جهد 12.0–18.0V
- إزاحة الحرارة ±10°C
- R1/R2/pull-up 0–100000Ω
- معامل المعايرة 0.1–10.0

---

## 3) التطبيق (Flutter) — `lib/`

### 3.1 التقنيات والحزم الرئيسية (من `pubspec.yaml`)

- **State management:** `flutter_riverpod` (Notifier/StreamProvider).
- **التنقل:** `go_router`.
- **الشبكة:** `http`, `web_socket_channel`, `multicast_dns` (mDNS),
  `connectivity_plus`.
- **الموقع/Speed:** `geolocator` (GPS).
- **التخزين:** `shared_preferences`.
- **الإشعارات:** `flutter_local_notifications`.
- **الخدمة الخلفية:** `flutter_foreground_task`.
- **الصوت (siren):** `audioplayers`.
- **ودجت الشاشة الرئيسية:** `home_widget` + `wakelock_plus`.
- **اختيار ملفات (OTA):** `file_picker`.
- التطبيق يدعم **العربية والإنجليزية** مع RTL تلقائي.
- `applicationId = com.kayan.carguard`، `minSdk = 23`، `compileSdk = 36`.

### 3.2 البنية المعمارية (Feature-first + Riverpod)

```
lib/
├── app/                 # main.dart, app.dart, router.dart
├── core/
│   ├── constants/       # الألوان، المسافات، الـ endpoints، النصوص
│   ├── l10n/            # app_l10n.dart — كل الترجمات العربية/الإنجليزية
│   ├── models/          # AppSettings, DeviceAlert, ReadingSample ...
│   ├── providers/       # Riverpod providers (الجهاز، الحالة، الإشعارات...)
│   ├── services/        # esp8266_repository, alert_evaluator, gps,
│   │                    # background_service, notification, ota, storage ...
│   ├── theme/           # ثيم Material 3
│   └── widgets/         # ودجتس مشتركة (بطاقات، أزرار، عناوين)
└── features/
    ├── dashboard/       # الصفحة الرئيسية + العدّادات + بطاقات الرحلة + GPS
    ├── analysis/        # صفحة "التنبيهات والتحليل"
    ├── device/          # المعايرة المتقدمة + OTA
    └── settings/        # صفحة الإعدادات الموحّدة
```

### 3.3 المسارات (Routes)

- `/` → **DashboardPage** (الرئيسية)
- `/alerts-analysis` → **AlertsAnalysisPage** (التنبيهات والتحليل)
- `/settings` → **SettingsPage**
- `/ota-update` → **OtaUpdatePage**
- `/advanced-settings` → **AdvancedSettingsPage**

### 3.4 مكوّنات الاتصال بالجهاز

- **`Esp8266Repository`** (`core/services/esp8266_repository.dart`):
  - يفتح **WebSocket** على `ws://<host>:81`، وعند فشله/انقطاعه يبدأ **HTTP polling**
    على `http://<host>/data` كل **800ms** (حاليًّا).
  - يبث `DeviceStatus` عبر Stream (`deviceStatusProvider`).
  - إعادة اتصال تلقائية للـ WebSocket حتى 10 محاولات بتأخير متزايد.
  - على أندرويد يستخدم `bindProcessToNetwork` لربط الترافيك بشبكة الجهاز
    (يبقى الموبايل على بيانات الموبايل للإنترنت في نفس الوقت).
  - الاكتشاف التلقائي عبر **mDNS** (`car_guard.local`) في `MdnsDiscoveryService`.
  - يدعم إرسال الأوامر: `/mute`, `/testfan`, `/restart`, حفظ الإعدادات، الـ OTA...
  - يحلّل صيغتين: JSON و CSV (الـ 11 حقل).

- **`DeviceStatus`** (`core/services/device_models.dart`):
  يحتوي:
  - `connected`, `deviceId`, `lastUpdated`
  - `batteryData` (voltage, voltageDifference)
  - `temperatureData` (engineTemperature)
  - `coolantLevelData` (coolantAvailable)
  - `controlData` (fanRunning, buzzerActive, muted)
  - `moduleLimits` (maxTemp, fanOnTemp, minVolt, maxVolt, offset)
  - `deviceModuleSettings` (إعدادات كاملة: R1, R2, voltCalib, serial...)

> ⚠️ نقطة مهمة: حدود إنذار الحرارة/الجهد تؤخذ **حصريًّا من الجهاز**
> (`moduleLimits`)، سواء من البث المباشر أو من كاش `/getallsettings`.
> لم يعد هناك عتبات محلية منزلقة (sliders) تؤثر على الإنذار.

### 3.5 نظام التنبيهات

- **`AlertEvaluator`** (`core/services/alert_evaluator.dart`) — منطق نقي (pure):
  - **سرعة زائدة** (GPS) عند `settings.speedLimit`.
  - **فقد الاتصال** (إن كان قد اتصل قبل ذلك).
  - **ارتفاع حرارة المحرك** عند `maxTemp` (تحذير وإنذار عند نفس القيمة
    حسب طلب المستخدم، بدون فرق 5 درجات).
  - **انخفاض/ارتفاع جهد البطارية** خارج حدود الجهاز.
  - **انخفاض سائل التبريد**.
- **`AlertsNotifier`** يزيل التكرار ويعرض `AlertsBanner` ويطلق إشعارات محلية.
- يوجد **siren داخل التطبيق** (audioplayers) يعمل أثناء الإنذار، مع زر كتم
  يرسل `/mute` للجهاز أيضًا.
- **`flutter_local_notifications`** + **foreground service** للمراقبة في الخلفية
  كل 5 ثوانٍ مع إشعار دائم + إقلاع تلقائي بعد إعادة تشغيل الموبايل.

### 3.6 صفحة التنبيهات والتحليل (`features/analysis/`)

هذه أهم صفحة منطقيًّا، وتحتوي على (من أعلى لأسفل بعد آخر تعديل):

1. **بانر الحالة العامة للسيارة** (normal/attention/warning/danger).
2. **التنبيهات النشطة حاليًّا**.
3. **تحليل السلوك** (شبكة إحصائيات الجلسة: متوسط/أقصى حرارة، معدل الصعود،
   زمن المروحة، تذبذب الجهد...).
4. **رسم بياني sparkline** لآخر 5 دقائق (حرارة + جهد) عبر CustomPainter.
5. **مقارنة "بالمعدل المعتاد"** (baseline متعدد الجلسات).
6. **التوقعات (Predictions)** احتمالية: ارتفاع الحرارة، نمط جهد غير معتاد،
   اقتراح فحص التبريد، تكرار الحرارة في الزحمة...
7. **إحصائيات الرحلة الحالية** (المسافة، متوسط/أقصى سرعة، المدة) من GPS.
8. **سجل التنبيهات (التاريخ)** — **آخر شيء في الصفحة**، ومعه **زر "مسح
   السجل" أسفل القائمة مباشرة** (يفتح dialog تأكيد ثم `clearHistory()`).

- **`AnalysisNotifier`** يجمع بيانات الجلسة، baseline (EMA عبر الجلسات)،
  وينتج التوقعات، ويحفظ السجل في SharedPreferences (حد أقصى 100).
- **`SmartAlertTracker`** في `analysis_engine.dart`: يفتح حلقة تنبيه (episode)
  ويصعّدها بعد cooldown، ويحدّث نفس سجل التاريخ بدل التكرار، ويغلقها بعد زوال
  السبب بـ 45 ثانية.
- التخزين المحلي: `analysis_baseline_v1`, `analysis_history_v1`.

### 3.7 السرعة والرحلة (GPS — `features/dashboard/`)

- **لا توجد سرعة قادمة من الجهاز**؛ السرعة تُحسب من **GPS الموبايل**.
- **`TripNotifier`** (`trip_provider.dart`) عبر `geolocator`:
  - `LocationAccuracy.bestForNavigation` + `distanceFilter: 0` لاستقاب تحديثات سريعة.
  - ينتج `TripState(speedKmh, distanceKm, hasFix, available, denied)`.
  - يحفظ العداد (odometer) في SharedPreferences.
  - زر إعادة تصفير الرحلة.
- **`GpsTripFilter`** (`gps_trip_filter.dart`):
  - فلتر جودة + **Kalman filter** على الموقع لاستخراج سرعة ومسافة موثوقة.
  - يرفض القفزات المستحيلة (teleport) والدقة السيئة (> 35m).
  - يفضّل سرعة **Doppler** من الحساس (`position.speed`).
  - يمنع تراكم مسافة وهمية عند الوقوف (stop-band ~0.8 km/h).
  - يستخدم EMA متكيّف للسرعة (هجوم سريع / إفلات سريع).
  - يُنصح بتشغيل التطبيق في الهواء الطلق للحصول على سرعة دقيقة؛ تحت 20km/h
    يمكن تحسين الاستجابة بزيادة معدل التحديث وتقليل التنعيم (قابل للتعديل هنا).

### 3.8 الصفحة الرئيسية (Dashboard)

تعرض بالتتابع:
- `AlertsBanner` (إن وُجد تنبيه).
- `buildGaugeArea(...)`: عدّادات قابلة للتبديل بين أنماط (cards/racing/sporty/
  segments/sweeper/ring/led/needle/orb/combo) في `dashboard_gauges.dart`،
  مع صفحة عدّادات ملء الشاشة وHUD عملاق.
- `SystemStatusCard`, `ModuleLimitsCard` (حدود الجهاز).
- `TripCards`: بطاقتا السرعة الحالية (GPS) والمسافة + زر reset.
- رسوم بيانية للقراءات (`ReadingChartCard`).
- `AnalysisEntryCard`: اختصار لصفحة "التنبيهات والتحليل".

### 3.9 الإعدادات

صفحة واحدة (`SettingsPage`) تشمل:
- عنوان الجهاز (IP) والاتصال/الـ mDNS.
- نمط لوحة العدّادات.
- الثيم (فاتح/داكن/تلقائي) واللغة (عربي/إنجليزي).
- وضع Demo (يحاكي جهازًا كاملًا — أنظر `DemoDeviceService`).
- المراقبة في الخلفية.
- مفاتيح التنبيهات (عامة/تبريد/اتصال) وحد السرعة.
- **إعدادات الجهاز (Module Settings):** تعديل حدود `maxTemp/fanOnTemp/minVolt/
  maxVolt/offset` وترسل للـ ESP.
- الأقسام المتقدمة (المعايرة، R1/R2، معالج الجهد) وشاشة تحديث OTA.

### 3.10 الأندرويد أوتو (Android Auto)

- خدمة `CarGuardCarAppService` تعرض حرارة المحرك والجهد والمروحة والإنذار.
- الفئة `IoT` (مناسبة لتطبيقات مراقبة الأجهزة)، ملف `automotive_app_desc.xml`.
- تقرأ عنوان الجهاز المحفوظ وتعمل poll لـ `/data` كل 5 ثوانٍ.
- **CarPlay غير مدعوم** (Apple تقيّد الفئات).

### 3.11 الاختبارات

- في `test/` وتعكس بنية `lib/`. تشغيلها: `flutter test`.
- تشمل اختبارات لـ `GpsTripFilter` (الدقة، الـ drift، استجابة السرعة، الفرملة)،
  و`analysis_engine`، و`dashboard_provider`.

---

## 4) سير العمل والأوامر

```bash
flutter pub get        # تحميل الحزم
flutter run            # تشغيل على جهاز/محاكي
flutter analyze        # فحص ثابت
flutter test           # الاختبارات
```

رفع الفيرموير:
- Arduino IDE → Board **NodeMCU 1.0 (ESP-12E)** → Upload،
  أو لاحقًا عبر `http://192.168.4.1/update`.

---

## 5) ملاحظات للمساعدة/التطوير المستقبلي (اقرأها جيدًا)

1. **مصدر السرعة الوحيد هو GPS الموبايل** (`TripNotifier`/`GpsTripFilter`).
   الجهاز **لا يرسل** سرعة. أي طلب يخص "استجابة السرعة تحت 20 كم/س" يكون
   بتعديل:
   - `GpsTripFilter` (الـ EMA، الـ stop-band، قبول الدقة، استخدام Doppler).
   - `TripNotifier` (إعدادات `geolocator`).
   - `Esp8266Repository` HTTP polling interval لو بُني سرعة من الجهاز لاحقًا.
2. **حدود الإنذار من الجهاز فقط** — لا تضف عتبات محلية جديدة إلا إذا طُلب ذلك.
3. **صيغة الـ CSV 11 حقل** وحقلا `alarm,muted` في الآخر — لا تغيّر الترتيب
   لأنه يكسر التوافق.
4. عند إضافة نصوص جديدة، أضفها في **`core/l10n/app_l10n.dart`** بالعربي
   والإنجليزي (الكائن `AppL10n`).
5. كل البيانات الحساسة/الإعدادات محفوظة بـ `SharedPreferences`؛ لا يوجد سيرفر
   سحابي أو إنترنت — كل التحليل محلي على الموبايل.
6. اسم نقطة الوصول `CarGaurd` به خطأ إملائي — متعمّد لأنه محفوظ في الفيرموير.
7. التطبيق يستخدم **Riverpod 3** و**GoRouter 17** — انتبه لتغييرات الـ API.

---

## 6) خريطة الملفات الأكثر أهمية (ابدأ بها)

| الملف | المحتوى |
| --- | --- |
| `firmware/car_guard/car_guard.ino` | كل منطق الجهاز: الحساسات، الشبكة، الـ endpoints |
| `lib/core/services/esp8266_repository.dart` | اتصال WebSocket/HTTP وتحليل البروتوكول |
| `lib/core/services/device_models.dart` | نماذج بيانات الجهاز والحدود |
| `lib/core/services/alert_evaluator.dart` | منطق التنبيهات النقي |
| `lib/features/analysis/pages/alerts_analysis_page.dart` | صفحة التنبيهات والتحليل (واجهة + ترتيب الأقسام) |
| `lib/features/analysis/providers/analysis_provider.dart` | منطق التحليل والتوقعات والتاريخ |
| `lib/features/analysis/services/analysis_engine.dart` | SmartAlertTracker + قواعد التنبؤ |
| `lib/features/dashboard/providers/trip_provider.dart` | تتبّع GPS والرحلة |
| `lib/features/dashboard/services/gps_trip_filter.dart` | فلتر Kalman وحساب السرعة |
| `lib/features/dashboard/pages/dashboard_page.dart` | الصفحة الرئيسية وترتيب البطاقات |
| `lib/features/settings/pages/settings_page.dart` | الإعدادات الموحّدة |
| `lib/core/models/app_settings.dart` | كل إعدادات التطبيق |
| `lib/core/l10n/app_l10n.dart` | كل النصوص العربية/الإنجليزية |
