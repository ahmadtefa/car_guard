# Car Guard على Android Auto

## الوضع الحالي

شاشة Android Auto (`CarGuardCarAppService`) بقت بتعرض **نفس قراءات شاشة
الموبايل** في شكل كروت حية (GridTemplate زي كروت التطبيق) بنفس ألوان النيون:

| الكارت | المصدر | الحالة |
|---|---|---|
| 🌡️ حرارة المحرك | `/data` من الوحدة | أخضر/أحمر حسب `maxTemp` |
| 🔋 فولت البطارية | `/data` من الوحدة | أخضر/أحمر حسب `minVolt`/`maxVolt` |
| 🚀 السرعة (+ المسافة) | GPS الموبايل (من التطبيق) | أخضر/أحمر حسب حد السرعة |
| 🌀 المروحة | `/data` من الوحدة | شغالة/متوقفة |
| ⚙️ الدينامو | `volt >= 13V` | شاحن/غير شاحن |
| 🔔 الحالة | `/data` من الوحدة | متصل · سليم / إنذار فعّال / مكتوم |

التحديث كل **2 ثانية** مباشرة من `http://<ip>/data` بنفس منطق الحدود
اللي في التطبيق، والسرعة/المسافة بتتشارك من الـ GPS عبر SharedPreferences
(`flutter.speed_kmh`, `flutter.trip_distance_km`) — يعني شاشة العربية
بتفضل حية حتى لو واجهة Flutter مش معروضة.

> ملاحظة: Android Auto مبيسمحش بتشغيل واجهة Flutter جوه شاشة العربية —
> بيتعرض من خلال Templates قياسية (Grid/List). الكروت دي هي أقرب شكل
> مطابق للكروت اللي في الموبايل، ببيانات حية من نفس المصدر ونفس الألوان.

## أمر تشغيل المحاكي

### 1) محاكي Android Automotive OS (أفضل طريقة للتجربة من غير عربية)

**إنشاء المحاكي** (مرة واحدة) — من Android Studio:
`Device Manager ← Create Device ← فئة Automotive ← مثلاً
"Automotive OS (API 34) AOSP x86_64"`، وسمّيه `car_guard`.

أو من سطر الأوامر:

```bash
sdkmanager "system-images;android-34;automotive;x86_64"
avdmanager create avd -n car_guard -k "system-images;android-34;automotive;x86_64"
```

**تشغيل المحاكي:**

```bash
# من داخل مجلد Android SDK
emulator -avd car_guard -gpu swiftshader_indirect -no-snapshot -no-boot-anim -memory 2048
```

أو بسطر واحد لو الـ SDK في `$ANDROID_HOME`:

```bash
$ANDROID_HOME/emulator/emulator -avd car_guard -gpu swiftshader_indirect -no-snapshot -no-boot-anim -memory 2048
```

(على Windows استخدم `%ANDROID_HOME%` بدل `$ANDROID_HOME`.)

لو المحاكي مش ظاهر في إعدادات Flutter أول مرة، اعمل:

```bash
flutter emulators          # يوريك الأسماء المتاحة
flutter emulators --launch car_guard
flutter devices            # لازم تظهر emulator-5554
```

### 2) تحميل التطبيق على المحاكي

```bash
cd ~/car_guard
flutter pub get
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

أو مباشرة بـ `flutter run`:

```bash
flutter run -d emulator-5554
```

### 3) فتح شاشة العربية

- من قائمة تطبيقات شاشة المحاكي افتح **Car Guard** (شعار التطبيق) —
  المشغّل (host) هيربط بـ `CarGuardCarAppService` تلقائيًا.
- لو مش ظاهر: `adb reboot` مرة واحدة بعد التثبيت.

### 4) شرط مهم عشان القراءات الحية تظهر

العنوان الافتراضي للوحدة `192.168.4.1`. المحاكي بيعدّي الشبكة عبر
اللابتوب (NAT)، فـ **اللابتوب لازم يكون متوصل بشبكة الوحدة `CarGaurd`**
(باسوورد `12345678`) عشان المحاكي يوصل للوحدة. الموبايل عادي يقدر يفتح
هوت سبوت أو يحتفظ بنت الداتا لو هو اللي بيستخدم التطبيق.

### بديل: Desktop Head Unit (DHU) + موبايل حقيقي

لو اللابتوب قديم وشغيل المحاكي تقيل عليه:

1. افتح الـ DHU من مجلد SDK:
   `$ANDROID_HOME/extras/google/auto/desktop-head-unit/desktop-head-unit`
2. وصّل الموبايل باللابتوب USB، ونفّذ:
   ```bash
   adb forward tcp:5277 tcp:5277
   ```
3. من الموبايل: **Android Auto ← ⋮ ← Developer settings ← Start head unit server**.
4. بيظهر Car Guard في قائمة تطبيقات الـ DHU على اللابتوب.

## ملاحظات

- لو الشاشة ظاهرة **غير متصل**: اتأكد إن الموبايل/اللابتوب على شبكة الوحدة
  وإن الوحدة بتطلع `http://192.168.4.1/data` (جرّبها من متصفح).
- لو الوحدة متوصّلة بهوت سبوت: افتح التطبيق مرة واحدة على الموبايل قبل ما
  تفتح Android Auto عشان يكتشف `car_guard.local` ويحفظ عنوانها في
  `flutter.mdns_module_ip` — شاشة العربية بتقراه تلقائيًا.
- أيقونات الكروت `VectorDrawable` ملوّنة بنفس ألوان التطبيق (أخضر/أصفر/أحمر نيون)
  ومحمّلة من `res/drawable/ic_car_*.xml`.
