# إصلاح انهيار التطبيق على شاشة السيارة (Android car screen)

الغرض من هذا الملف: توثيق سبب الـ Crash الذي يظهر فور تشغيل التطبيق على شاشة
السيارة (والتطبيق يعمل طبيعيًا على الهاتف)، وما تم تعديله، وكيف تتأكد على
شاشة السيارة نفسها.

التطبيق Flutter Native بدون أي WebView، ولم يتم تغيير أي وظيفة من وظائفه:
Dashboard، WebSocket، HTTP fallback، قراءات البطارية/الحرارة/المروحة/المستوى،
حالة الاتصال، صفحة اتصال الجهاز، providers الخاصة بـ Riverpod، الويدجت،
وشاشة Android Auto — كلها كما هي.

---

## 1) قاعدة التشخيص: لماذا يعمل على الهاتف ويسقط على شاشة السيارة؟

رسالة "توقف التطبيق Car Guard" تظهر من نظام Android عندما يموت **الـ process
نفسه** بسبب استثناء غير ملتقط (أو SIGSEGV native). في هذا المشروع **كل**
المسارات التي يمكن أن ترمي استثناءً غير ملتقط أثناء الإقلاع توجد في طبقة
Android/Kotlin وليس في Dart:

| المسار | لماذا يعمل على الهاتف ويسقط على شاشة السيارة |
|---|---|
| `CarGuardForegroundService` (خدمة الإبقاء في المقدمة) | تُشغَّل آليًا بعد أول نجاح في الاتصال بالوحدة أو أول لقطة GPS (على شاشة السيارة الـ GPS متوفر غالبًا). في الكود القديم كانت كل خطواتها بدون أي حماية: `getSystemService(...) as WifiManager/NotificationManager`، `createWifiLock(WIFI_MODE_FULL_LOW_LATENCY)` (ثابت من API 29 فقط)، و`startForeground(id, n, FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE|LOCATION)`. أي من هذه الاستدعاءات ترفضها بعض builds السيارات (سياسة إشعارات مقفلة، بدون Wi-Fi service، أنواع خدمة غير مسموحة) وترمي `SecurityException`/`IllegalArgumentException`/`RemoteServiceException` → موت الـ process. Dart لا يستطيع التقاط ذلك: الاستثناء يحدث في main thread الخاص بالخدمة. |
| `MainActivity` (MethodChannel handlers) | كل معالجات `com.kayan.carguard/network` و`car_guard/background` تنفّذ عملًا مباشرًا ثم `result.success(...)`. أي استثناء يهرب من الـ handler يصل للنظام ولا يوصل لـ Dart كـ `PlatformException` → نفس النتيجة (موت التطبيق). التحويل العنيف `as WifiManager` كان **خارج** `try` في `suggestModuleWifi` / `removeModuleWifiSuggestion`. |
| `CarGuardCarAppService` (شاشة Android Auto) | على شاشة السيارة يقوم مضيف السيارة بـ **bind** لهذه الخدمة داخل process التطبيق؛ على الهاتف لا يربط بها أحد إطلاقًا. `onGetTemplate()` كانت تبني عدادين كـ `Bitmap` بحجم `256dp × density` (يصل إلى 720px ≈ 2MB لكل صورة، صورتان كل ثانيتين) بدون أي `try/catch` حول البناء كاملًا (الحماية كانت حول `builder.build()` فقط) → `OutOfMemoryError`/استثناءات framework على وحدة بموارد صغيرة = انهيار عند فتح التطبيق من launcher السيارة. كذلك `Thread { fetch() }.start()` كل ثانيتين مع timeout 4 ثوانٍ = تكديس خيوط (thread pile-up) ينتهي عند `pthread_create failed` على وحدات 1GB RAM. |
| `CarGuardWidgetProvider` (ويدجت الشاشة الرئيسية) | `PendingIntent.getActivity(context, 0, intent, …)` مع `intent` قد يكون **null** على launchers السيارات (`getLaunchIntentForPackage` يرجع null) → `NullPointerException` داخل process التطبيق، أي أن الانهيار قد يظهر حتى بدون فتح التطبيق. |
| مُصيّر Flutter (Impeller) | Impeller هو الافتراضي على Android من Flutter 3.29 وهو يفترض GPU حديث (GLES 3.1+/Vulkan). GPUs شاشات السيارات (Vivante / Mali-400-450 / PowerVR Series5-6 / Adreno 5xx) هي تحديدًا الأجهزة التي تسقط فيها تطبيقات Flutter داخل `libflutter.so` قبل أول إطار — بدون أي stack trace في Java، وهذا يطابق "انهيار فوري على السيارة فقط". |

ملاحظة مهمة بالأدلة من المشروع نفسه:

* `pubspec.lock` يطلب Flutter `>= 3.44.0` (Impeller هو الافتراضي).
* `flutter build apk --release` ناجح أصلًا على CI (run `33434664489`) بنفس شجرة
  `android/` الحالية بالضبط → **السبب ليس Gradle / AGP 9 / compileSdk 36 ولا
  ProGuard/R8** (لا يوجد `isMinifyEnabled` في المشروع من الأساس).
* لا يوجد أي `abiFilters` ولا كود C/C++ في التطبيق → الـ APK الواحد يحتوي
  `arm64-v8a` + `armeabi-v7a` + `x86_64`، فلا مشكلة ABI في البناء الافتراضي.
* كل أكواد Dart في المسار الحرِج محميّة أصلًا بـ `try/catch` أو `unawaited(...)`
  (rivers/storage/websocket/mdns/notifications) → لا يوجد شيء في Dart يفسّر
  رسالة "توقف التطبيق".

بما أنه لا توجد شاشة سيارة متاحة للاختبار هنا (ولا `flutter`/Android SDK في بيئة
التطوير)، لم أدّعِ أنني جرّبت على السيارة: الإصلاحات أعلاه كلها **مبرهنة من
الكود** (مسارات انهيار غير محمية + سلوك مختلف على أجهزة السيارة)، وأُضيف
instrumentation يحدد بالضبط أي مرحلة تموت على جهازك (بند 4).

---

## 2) الملفات التي تم تعديلها

| الملف | ما تم تغييره |
|---|---|
| `android/app/src/main/AndroidManifest.xml` | (1) `io.flutter.embedding.android.EnableImpeller = false` للرجوع إلى Skia على GPU شاشات السيارات. (2) `android:configChanges` أُضيف إليها `colorMode\|navigation\|touchscreen` حتى لا يُعاد إنشاء الـ Activity (recreate) عند تغيّر هذه الإعدادات على شاشة السيارة أثناء الإقلاع. |
| `.../CarGuardForegroundService.kt` | `onStartCommand` داخل `try/catch (Throwable)` كامل. سُلّم `startForeground`: `CONNECTED_DEVICE\|LOCATION` ثم `CONNECTED_DEVICE` ثم بدون نوع، وعند الرفض الكامل `stopSelf()` بأمان بدل موت التطبيق. أيقونة الإشعار أصبحت `R.drawable.ic_launcher_foreground` (bitmap عادي) بدل `applicationInfo.icon` (adaptive icon → `RemoteServiceException: Bad notification for startForeground` على بعض builds السيارات). إعادة إنشاء قناة الإشعار فقط عند غيابها، ورفض القناة لا يُسقط التطبيق. `wakeLock`/`wifiLock` اختيارية تمامًا مع اختيار `WIFI_MODE_FULL_HIGH_PERF` لمن هو أقل من API 29 (الثابت القديم جديد على هذه الأجهزة). `WifiManager`/`ConnectivityManager`/`PowerManager` تُقرأ بشكل nullable. `stop()` صارت `stopService()` بدل `startService(action)` التي كانت ترمي `IllegalStateException` عندما يكون التطبيق في الخلفية. |
| `.../MainActivity.kt` | كل MethodChannels تمر عبر `reply(...)`: أي استثناء يرجع كـ `PlatformException` لـ Dart بدل ما يقتل الـ process. تحويلات `as ConnectivityManager` / `as WifiManager` العنيفة → `connectivityManager()` / `wifiManager()` nullable. `acquireMulticastLock` يلتقط `Throwable` (وليس `Exception`). `onCreate` يسجّل المراحل (انظر بند 4) ويلتقط أي فشل في `super.onCreate`. تنظيف: أُزيل `catch` مكرر غير مُدرَك في `removeModuleWifiSuggestion`. |
| `.../CarGuardCarAppService.kt` | `onGetTemplate()` كلها داخل `try/catch (Throwable)` مع تدرّج: عدادات مصوّرة → قائمة نصوص → شاشة فارغة. رسم العدادات يعتمد `allocateGauge()` الذي يصغّر الحجم تلقائيًا عند `OutOfMemoryError`، وحجم الصورة صار محدودًا بـ 360px بدل `256dp × density` حتى 720px (يقلل الذاكرة لكل تحديث ~4×). إذا فشل إنشاء الصورة يتم عرض الأيقونة المتجهية بدلًا منها — القراءة النصية تبقى ظاهرة دائمًا. `Thread{}` لكل poll → خيط عمل واحد معاد استخدامه. `onBind` و`onCreateScreen` و`onStart/onStop` محميّة. |
| `.../CarGuardWidgetProvider.kt` | `onUpdate`/`onReceive` داخل `try/catch`، و`PendingIntent` يُنشأ فقط عند وجود launch intent صحيح (لم يعد null يسبب NPE). الويدجت يستمر في عرض القراءات بدون ضغطة في هذه الحالة. |
| `.../BootDiagnostics.kt` (جديد — مؤقت) | تسجيل مراحل الإقلاع + حفظ آخر انهيار Java في `SharedPreferences` الخاصة بالتطبيق. |
| `lib/core/services/boot_diagnostics.dart` (جديد — مؤقت) | جسر Dart لقراءة آخر انهيار وعرضه في Dialog على شاشة الـ Dashboard، وتمرير أخطاء Dart غير الملتقطة لنفس السجل. |
| `lib/main.dart` | استدعاء `BootDiagnostics.installErrorCapture()` + مرحلة `dart.main` (بدون أي تغيير في تسلسل التشغيل). |
| `lib/features/dashboard/pages/dashboard_page.dart` | بعد أول إطار: تسجيل مرحلة `dashboard.first-frame` وعرض تقرير آخر انهيار إن وُجد. |

لا شيء تم حذفه: لم تُزل شاشة Android Auto ولا الويدجت ولا خدمة الخلفية ولا أي
ميزة — كل ما تم هو حماية المسارات حتى لا تُسقط التطبيق + fallbackات تحافظ على
الوظيفة عند الإمكان.

---

## 3) لماذا هذه التعديلات تحل المشكلة

1. **الانهيار لم يعد ممكنًا من طبقة Android**: كل استدعاء نظام يمكن أن يرفضه
   build السيارة صار إما داخل `try/catch (Throwable)` أو يُقرأ بشكل nullable،
   والفشل يتحوّل إلى "ميزة إضافية مطفأة" (إشعار خدمة الخلفية، قفل Wi‑Fi، صورة
   العداد) وليس إلى موت التطبيق.
2. **خدمة الخلفية لم تعد فرضًا بنوع واحد**: سُلّم الأنواع يعني أن وحدة ترفض
   `connectedDevice` أو لا تسمح بـ `location` بدون إذن runtime ستظل شغّالة على
   أي حال، وهو تحديدًا ما كان يقتل التطبيق بعد الإقلاع بثانية أو ثانيتين على
   شاشة السيارة.
3. **شاشة Android Auto لم تعد قادرة على قتل التطبيق**: البناء الكامل للتبليطة
   داخل حماية، مع رسم أصغر بـ 4 مرات وإعادة استخدام خيط واحد بدل خيط لكل poll.
4. **لو السبب هو المُصيّر** (وهو الاحتمال الوحيد الذي لا يمكن إثباته بدون
   logcat من السيارة) فإن `EnableImpeller=false` ينقل Flutter إلى Skia — مسار
   مدعوم وموثّق لتحطّم `libflutter.so` على GPUs السيارات.
5. **إعادة إنشاء الـ Activity** بسبب `colorMode/navigation/touchscreen` لم تعد
   تحدث أثناء الإقلاع.

---

## 4) كيف تختبر على شاشة السيارة (مهم)

1. ثبّت APK هذه الفرع (release موقّع بمفتاح debug لتجربة sideload):

   ```bash
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```

   أو نزّل الـ artifact من تبويب Actions لهذا الـ run/branch.
2. افتح التطبيق. **إذا انهار**، افتحه مرة ثانية: سيظهر Dialog
   «تشخيص بدء التشغيل / startup diagnostics» يعرض:
   * سطر الجهاز: إصدار Android، الشركة/الموديل، الـ ABIs؛
   * آخر انهيار Java مع الـ stack trace الكامل؛
   * قائمة مراحل الإقلاع، وآخر سطر فيها هو المكان الذي مات عنده التطبيق.
   صوّر هذا الشاشة (أو انسخ النص بالضغط عليه) وأرفقه بالتقرير.
3. إن كانت `adb` متاحة على شاشة السيارة:

   ```bash
   adb logcat -b crash -d
   adb logcat -d | grep -E "CarGuardBoot|AndroidRuntime|F DEBUG|impeller|libc"
   ```

   `CarGuardBoot` هي مراحل الإقلاع، و`F DEBUG` يعطي الـ native crash
   (توقيع `libflutter.so` يعني أنه موضوع المُصيّر/الـ ABI وليس الكود).
4. إذا أظهر التقرير أن التطبيق مات **قبل** مرحلة `activity.onCreate` أو داخل
   `libflutter.so`: جرّب رفع `EnableImpeller` إلى `true` (أو العكس) وابنِ مرة
   واحدة — الفرق بين القيمتين يقطع الشك باليقين في موضوع الـ GPU.
5. لتأكيد أن التحميل على وحدة 32-bit سليم:

   ```bash
   unzip -l app-release.apk | grep -E "lib/(arm64-v8a|armeabi-v7a|x86_64)/libflutter.so"
   ```

   يجب أن تظهر المعماريات الثلاثة؛ إذا اختار شخص ما بناء `--split-per-abi`
   فليثبتوا APK المطابق لمعمارية الشاشة (`adb shell getprop
   ro.product.cpu.abilist`).

## 5) تنظيف مطلوب بعد تأكيد زوال المشكلة

Instrumentation مؤقت ومكتوب عليه `TEMP(car-crash)`. عند التأكيد:

* احذف `android/app/src/main/kotlin/com/example/car_guard/BootDiagnostics.kt`
  و`lib/core/services/boot_diagnostics.dart`.
* احذف استدعاءات `BootDiagnostics.*` من `MainActivity.kt`,
  `CarGuardForegroundService.kt`, `CarGuardCarAppService.kt`,
  `CarGuardWidgetProvider.kt`، وقناة `car_guard/boot`، والسطرين في `main.dart`
  و`dashboard_page.dart`.
* كل الحماية الأخرى (`try/catch`، سُلّم `startForeground`، حدود الـ bitmaps،
  الـ nullable services) تبقى — هي الإصلاح الحقيقي وليست تشخيصًا.
