# Car Guard على Android Auto

## الوضع الحالي

شاشة Android Auto (`CarGuardCarAppService`) بتعرض **عدادين كبيرين**
بياخدوا الشاشة كلها:

| الكارت | المصدر | الشكل |
|---|---|---|
| 🌡️ حرارة المحرك | `/data` من الوحدة | **عداد نص دائري كبير** (40–140°C + إبرة، أخضر/أصفر/أحمر) |
| 🔋 فولت البطارية | `/data` من الوحدة | **شريط أفقي كبير** بمناطق حمراء/خضراء وحدّي min/max (10–16V) |

و**شاشة "قراءات إضافية"** بتتفتح بالضغط على أي عداد أو من الزر العائم:

| الكارت | المصدر |
|---|---|
| 🚀 السرعة (+ المسافة) | GPS الموبايل (من التطبيق) |
| 🌀 المروحة | `/data` من الوحدة |
| ⚙️ الدينامو | `volt >= 13V` |
| 🔔 الحالة | `/data` من الوحدة |

التحديث كل **2 ثانية** مباشرة من `http://<ip>/data` بنفس منطق الحدود
اللي في التطبيق، والسرعة/المسافة بتتشارك من الـ GPS عبر SharedPreferences
(`flutter.speed_kmh`, `flutter.trip_distance_km`) — يعني شاشة العربية
بتفضل حية حتى لو واجهة Flutter مش معروضة. العددان والصور بتتحدث
عبر `invalidate()` من `CarReadings` (poller واحد مشترك بين الشاشتين).

> ملاحظة: Android Auto مبيسمحش بتشغيل واجهة Flutter جوه شاشة العربية —
> بيتعرض من خلال Templates قياسية (Grid/List)، وحجم الصورة في كل عنصر
> محدود، فإكتر طريقة تخلي العداد "كبير" هي قلة عدد العناصر (عدادين فقط)
> مع `ITEM_SIZE_LARGE` على الـ hosts اللي بتدعم Car API 8+. العدادات
> بترسم Bitmap بنفس منطق `MiniArcGauge` و `MiniVoltBarGauge` (40–140°C،
> 10–16V) بحجم 240dp بخطوط أسمك وأرقام أوضح.

**الملفات الأساسية للـ Car UI:**

| الملف | وظيفته |
|---|---|
| `android/app/src/main/kotlin/com/example/car_guard/CarGuardCarAppService.kt` | نقطة دخول Android Auto (`CarAppService` + `Session` + `Screen` + رسم العدادات) — بتسحب القراءات مباشرة من `http://<ip>/data` |
| `android/app/src/main/kotlin/com/example/car_guard/MainActivity.kt` | النشاط الرئيسي لتطبيق Flutter |
| `android/app/src/main/res/xml/automotive_app_desc.xml` | تعريف إن التطبيق فيه Car UI |
| `android/app/build.gradle.kts` | مكتبة `androidx.car.app:app` |

> ⚠️ ملحوظة: `HostValidator.ALLOW_ALL_HOSTS_VALIDATOR` للتجربة بس — راجع
> التعليق `TODO(production)` في `CarGuardCarAppService.kt` قبل النشر،
> وكمان راجع [سياسات فئات تطبيقات العربيات](https://developer.android.com/training/cars/apps#supported-app-categories).

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

## بديل: Desktop Head Unit (DHU)

لو اللابتوب قديم وشغيل المحاكي تقيل عليه، أو عايز تجرب بـ موبايل حقيقي.

### إزاي الـ DHU بيشتغل؟

الـ **Desktop Head Unit** مش محاكي مستقل — هو شاشة عربية افتراضية بتتحمل
على الكمبيوتر، وبتوصل بـ **موبايل حقيقي أو إيموليتور** شغّال عليه تطبيق
**Android Auto** عن طريق ADB:

```
[الموبايل: تطبيق Android Auto + تطبيقك] ← ADB (port 5277) ← [DHU على الكمبيوتر: شاشة العربية]
```

### المتطلبات (مرة واحدة)

1. **Android Studio** (أو SDK بس) على جهازك.
2. **باكدج الـ DHU**: من Android Studio → Settings → Languages & Frameworks → Android SDK → تبويب **SDK Tools** → علّم على **Android Auto Desktop Head Unit emulator** → Apply.
   - أو من Terminal: `sdkmanager --install "extras;google;auto"`
3. **موبايل أندرويد** (Android 9+ للراحة) عليه:
   - تطبيق **Android Auto** متثبت ومحدّث (من Google Play).
   - **USB debugging** مفعّل من Developer options.
4. *(اختياري لو مش معاك موبايل)* إيموليتور بصورة **Google Play** (API 30+) وتسجّل بحساب Google وتثبّت تطبيق Android Auto من المتجر — أوضح وأسرع بالموبايل الحقيقي.
5. **لينكس بس**: مكتبات الصوت والرسم:
   ```bash
   sudo apt install portaudio19-dev libpng-dev libsdl2-dev libsdl2-ttf-dev
   ```

### الخطوات (بموبايل حقيقي)

#### الخطوة 1 — فعّل خيار الـ Head Unit Server على الموبايل (مرة واحدة)

1. افتح تطبيق **Android Auto** على الموبايل.
2. من الإعدادات، انزل لآخر حاجة عند **Version and permissions / الإصدار**.
3. دوس على رقم الإصدار **10 مرات** → هيظهر وضع المطور.
4. افتح قائمة ⋮ → **Developer settings** → شغّل **Start head unit server**.

#### الخطوة 2 — ثبّت تطبيق Car Guard على نفس الموبايل

```bash
flutter run                       # والموبايل موصّل USB
# أو:
flutter build apk --debug && adb install build/app/outputs/flutter-apk/app-debug.apk
```

#### الخطوة 3 — شغّل المحاكي

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

> 💡 السكريبت كمان بيحاول يشغّل الـ Head Unit Server أوتوماتيك عن طريق adb — لو مانفع، هتضطر تعمل الخطوة 1 اليدوية مرة واحدة بس.

#### الخطوة 4 — افتح التطبيق من شاشة العربية

هتلاقي شاشة العربية ظهرت في نافذة الـ DHU → اختار قائمة التطبيقات (AppBar) → أيقونة **Car Guard** → هتشوف عداد الحرارة وفولت البطارية، وشاشة "قراءات إضافية" بالضغط على أي عداد (السرعة، المروحة، الدينامو، الحالة). وكل ما الوحدة تبعت قراءة جديدة، الشاشة بتتحدّث لحظيًا.

### طريقة الإيموليتور بس (من غير موبايل حقيقي)

طريقة مجرّبة ومظبوطة، مبنية على [التجربة دي](https://stackoverflow.com/questions/76482834/can-we-test-android-auto-purely-in-emulators-2023):

#### أولًا: Setup (مرة واحدة)

```bash
# macOS / Linux
./scripts/android-auto/setup-emulator.sh

# Windows (PowerShell)
.\scripts\android-auto\setup-emulator.ps1
```

السكريبت ده بيركّب: platform-tools + emulator + صورة النظام
`system-images;android-33;google_apis_playstore;x86_64` + الـ DHU،
وبيعمل AVD جاهزة اسمها `CarGuard_Auto`.

#### ثانيًا: نزّل تطبيق Android Auto (نسخة x86_64)

الإيموليتور مش بيجي فيه تطبيق Android Auto، ولا ينفع نجيبه من Play Store
من غير تسجيل دخول. الحل: نزّله كـ APK يدويًا من
[APKMirror — Android Auto](https://www.apkmirror.com/apk/google-inc/android-auto/)
واختار **نسخة x86_64** (نسخ مجربة وشغالة: **12.4.642858** أو **11.5.641018** —
خد بالك: النسخ الأحدث ممكن تتطلب صورة نظام أحدث).

#### ثالثًا: شغّل الإيموليتور وثبّت

```bash
./scripts/android-auto/setup-emulator.sh --boot --aa-apk android-auto.apk
```

(على ويندوز: `.\setup-emulator.ps1 -Boot -AaApk android-auto.apk`)

#### رابعًا: فعّل الـ Head Unit Server جوّه الإيموليتور (مرة واحدة)

1. فعّل Developer options في الإيموليتور: Settings → About emulated device →
   دوس على **Build number** 7 مرات.
2. افتح **Settings → Connection preferences → Android Auto**.
3. دوس على **Version and permissions / الإصدار** حوالي 10 مرات → هيقولك
   إن وضع المطور اتفعّل.
4. من قائمة ⋮ فوق يمين → **Developer settings** → **Start head unit server**.

> ملحوظة: سكريبت `run-dhu` بيحاول يعمل الخطوة دي أوتوماتيك عن طريق adb،
> لو مانفع اعملها بإيدك مرة واحدة.

#### خامسًا: شغّل التطبيق والمحاكي

```bash
flutter run                             # ثبّت Car Guard على الإيموليتور
./scripts/android-auto/run-dhu.sh       # شاشة العربية! 🚗
```

### خيارات مفيدة للـ DHU

| الأمر | بيعمل إيه |
|---|---|
| `./run-dhu.sh -i touch` | شاشة لمس (الافتراضي) |
| `./run-dhu.sh -i rotary` | تجربة تدوير/ضغط (زي عربيات الماركات القديمة) |
| `./run-dhu.sh -i hybrid` | لمس + تدوير مع بعض |
| `./run-dhu.sh -c <file.ini>` | إعدادات شاشة مخصصة — عينات جاهزة في `extras/google/auto/configs/` |
| `./run-dhu.sh --usb` | توصيل بـ USB AOA بدل الـ ADB tunnel (أسرع) |

### مشاكل شائعة

| المشكلة | الحل |
|---|---|
| `connection refused` / الشاشة سودة | اتأكد إنك عملت **Start head unit server** من تطبيق Android Auto على الموبايل، وإن `adb devices` شايف الموبايل، وبعدين أعد تشغيل السكريبت |
| التطبيق مش ظاهر في قائمة تطبيقات العربية | اتأكد إن `flutter run` خلّص التثبيت على نفس الموبايل، وإن `automotive_app_desc.xml` و`<service>` موجودين في المانيفست |
| القيم بتظهر Offline طول الوقت | اتأكد إن الموبايل/اللابتوب على شبكة الوحدة، وإن `flutter.mdns_module_ip` محفوظ (افتح التطبيق مرة على الموبايل وهو موصّل بالوحدة) |
| `desktop-head-unit: error while loading shared libraries` (لينكس) | ركّب المكتبات في بند 5 من المتطلبات فوق |

## ملاحظات

- لو الشاشة ظاهرة **غير متصل**: اتأكد إن الموبايل/اللابتوب على شبكة الوحدة
  وإن الوحدة بتطلع `http://192.168.4.1/data` (جرّبها من متصفح).
- لو الوحدة متوصّلة بهوت سبوت: افتح التطبيق مرة واحدة على الموبايل قبل ما
  تفتح Android Auto عشان يكتشف `car_guard.local` ويحفظ عنوانها في
  `flutter.mdns_module_ip` — شاشة العربية بتقراه تلقائيًا.
- أيقونات الكروت `VectorDrawable` ملوّنة بنفس ألوان التطبيق (أخضر/أصفر/أحمر نيون)
  ومحمّلة من `res/drawable/ic_car_*.xml`.
