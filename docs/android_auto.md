# 🚗 دليل Android Auto — مشروع Car Guard

دليل كامل لفهم إيه اللي اتعمل في المشروع، وإزاي تشغّل **محاكي Android Auto (Desktop Head Unit — DHU)** على جهازك وتشوف تطبيق Car Guard عليه.

---

## 1) إيه اللي اتعمل في المشروع؟

Flutter مش بيرندر على شاشة العربية خالص — Android Auto بيشغّل واجهة مكتوبة **natively بـ Kotlin** عن طريق مكتبة **Android for Cars App Library**. فاتضاف الآتي:

| الملف | وظيفته |
|---|---|
| `android/app/src/main/kotlin/com/example/car_guard/car/CarGuardCarAppService.kt` | نقطة دخول Android Auto (`CarAppService` + `Session`) |
| `android/app/src/main/kotlin/com/example/car_guard/car/CarGuardHomeScreen.kt` | شاشة العربية: حرارة الموتور، فولت البطارية، مياه الرادياتور، حالة المراوح |
| `android/app/src/main/kotlin/com/example/car_guard/car/CarStatusStore.kt` | مخزن مشترك بين Flutter وواجهة العربية (SharedPreferences + تحديث فوري) |
| `android/app/src/main/kotlin/com/example/car_guard/MainActivity.kt` | MethodChannel باسم `car_guard/car_status` بياخد البيانات من Flutter |
| `lib/core/services/android_auto_bridge.dart` | الجسر من ناحية Dart (`AndroidAutoBridge.publishStatus(...)`) |
| `lib/features/dashboard/providers/dashboard_provider.dart` | بيبعت آخر حالة الجهاز للواجهة العربية مع كل تحديث |
| `android/app/src/main/res/xml/automotive_app_desc.xml` | تعريف إن التطبيق فيه Car UI |
| `android/app/build.gradle.kts` | مكتبة `androidx.car.app:app:1.7.0` + رفع `minSdk` لـ 23 |

**تدفق البيانات:**

```
ESP8266 → WebSocket → Flutter (deviceStatusProvider → dashboardProvider)
    → AndroidAutoBridge.publishStatus()  →  MethodChannel "car_guard/car_status"
    →  CarStatusStore (Kotlin)  →  CarGuardHomeScreen على شاشة العربية
```

> ⚠️ ملحوظة: فئة التطبيق في المانيفست حاليًا `androidx.car.app.category.POI` (أقرب فئة متاحة لتطبيقات حالة العربية) — كفاية للتجربة والتطوير. لو هتنشر على Google Play لازم تراجع [سياسات فئات تطبيقات العربيات](https://developer.android.com/training/cars/apps#supported-app-categories) الأول. وكذلك `HostValidator.ALLOW_ALL_HOSTS_VALIDATOR` للتجربة بس — راجع التعليق `TODO(production)` في `CarGuardCarAppService.kt` قبل النشر.

---

## 2) المحاكي (DHU) بيشتغل إزاي؟

الـ **Desktop Head Unit** مش محاكي مستقل — هو شاشة عربية افتراضية بتحاول على الكمبيوتر، وبتوصل بـ **موبايل حقيقي أو إيموليتور** شغّال عليه تطبيق **Android Auto** عن طريق ADB:

```
[الموبايل: تطبيق Android Auto + تطبيقك] ← ADB (port 5277) ← [DHU على الكمبيوتر: شاشة العربية]
```

## 3) المتطلبات (مرة واحدة)

1. **Android Studio** (أو SDK بس) على جهازك.
2. **باكدج الـ DHU**: من Android Studio → Settings → Languages & Frameworks → Android SDK → تبويب **SDK Tools** → علّم على **Android Auto Desktop Head Unit emulator** → Apply.
   - أو منTerminal: `sdkmanager --install "extras;google;auto"`
3. **موبايل أندرويد** (Android 9+ للراحة) عليه:
   - تطبيق **Android Auto** متثبت ومحدّث (من Google Play).
   - **USB debugging** مفعّل من Developer options.
4. *(اختياري لو مش معاك موبايل)* إيموليتور بصورة **Google Play** (API 30+) وتسجّل بحساب Google وتثبّت تطبيق Android Auto من المتجر — أوضح وأسرع بالموبايل الحقيقي.
5. **لينكس بس**: مكتبات الصوت والرسم:
   ```bash
   sudo apt install portaudio19-dev libpng-dev libsdl2-dev libsdl2-ttf-dev
   ```

## 4) خطوات التشغيل

### الخطوة 1 — فعّل خيار الـ Head Unit Server على الموبايل (مرة واحدة)

1. افتح تطبيق **Android Auto** على الموبايل.
2. من الإعدادات، انزل لآخر حاجة عند **Version and permissions / الإصدار**.
3. دوس على رقم الإصدار **10 مرات** → هيظهر وضع المطور.
4. افتح قائمة ⋮ → **Developer settings** → شغّل **Start head unit server**.

### الخطوة 2 — ثبّت تطبيق Car Guard على نفس الموبايل

```bash
flutter run                       # والموبايل موصّل USB
# أو:
flutter build apk --debug && adb install build/app/outputs/flutter-apk/app-debug.apk
```

### الخطوة 3 — شغّل المحاكي

في المشروع فيه سكريبت جاهز بيعمل كل حاجة (تثبيت DHU لو ناقص + `adb forward` + تشغيل المحاكي):

```bash
# macOS / Linux
./scripts/android-auto/run-dhu.sh

# Windows (PowerShell)
.\scripts\android-auto\run-dhu.ps1
```

أو يدوي لو بتحب:

```bash
adb forward tcp:5277 tcp:5277
cd $ANDROID_HOME/extras/google/auto      # ويندوز: %LOCALAPPDATA%\Android\Sdk\extras\google\auto
./desktop-head-unit                      # ويندوز: desktop-head-unit.exe
```

### الخطوة 4 — افتح التطبيق من شاشة العربية

هتلاقي شاشة العربية ظهرت في نافذة الـ DHU → افتح قائمة التطبيقات (AppBar) → أيقونة **Car Guard** → هتشوف:

- Connection (متصل / غير متصل + آخر تحديث)
- Engine temperature (°C)
- Battery voltage (V)
- Coolant (OK / Low)
- Fan (ON / OFF)

وكل ما الجهاز يبعت قراءة جديدة، الشاشة بتتحدّث لحظيًا.

## 5) خيارات مفيدة للـ DHU

| الأمر | بيعمل إيه |
|---|---|
| `./run-dhu.sh -i touch` | شاشة لمس (الافتراضي) |
| `./run-dhu.sh -i rotary` | تجربة تدوير/ضغط (زي عربيات الماركات القديمة) |
| `./run-dhu.sh -i hybrid` | لمس + تدوير مع بعض |
| `./run-dhu.sh -c <file.ini>` | إعدادات شاشة مخصصة — عينات جاهزة في `extras/google/auto/configs/` |
| `./run-dhu.sh --usb` | توصيل بـ USB AOA بدل الـ ADB tunnel (أسرع) |

## 6) مشاكل شائعة

| المشكلة | الحل |
|---|---|
| `connection refused` / الشاشة سودة | اتأكد إنك عملت **Start head unit server** من تطبيق Android Auto على الموبايل، وإن `adb devices` شايف الموبايل، وبعدين أعد تشغيل السكريبت |
| التطبيق مش ظاهر في قائمة تطبيقات العربية | اتأكد إن `flutter run` خلّص التثبيت على نفس الموبايل، وإن `automotive_app_desc.xml` و`<service>` موجودين في المانيفست |
| القيم بتظهر Offline طول الوقت | افتح تطبيق Car Guard على موبايلك مرة وهو موصّل بالـ ESP8266 عشان يبعت آخر قراءة للـ Store |
| `desktop-head-unit: error while loading shared libraries` (لينكس) | ركّب المكتبات في الخطوة 3.5 فوق |

---

## 7) الخطوة الجاية (اختياري)

- إظهار **تنبيهات** على شاشة العربية (مثلاً حرارة الموتور عالية) عن طريق `CarToast` أو Alert APIs.
- التحكم في المراوح من شاشة العربية (الوقت ده بيتطلب ربط الأوامر بالـ ESP8266 من الـ Kotlin side أو تمريرها لـ Flutter).
- دعم **Android Automotive OS** (نظام العربيات المدمج) — نفس الكود تقريبًا + artifact `androidx.car.app:app-automotive`.
