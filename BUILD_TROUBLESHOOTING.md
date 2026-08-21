# حل مشكلة `flutter build apk --release` بياخد وقت طويل ومش بيطلع APK

> هذا الدليل معمول لمشروع `car_guard` - يلخص ليه البناء بطيء وازاي تسرّعه خطوة بخطوة (Windows / macOS / Linux).

## 1) ليه أول مرة بتطوّل جداً؟ (طبيعي)

أول `flutter build apk --release` لازم يعمل:

1.  **تحميل Gradle Wrapper** `gradle-9.1.0-all.zip` ~ 250MB
2.  **تحميل Android Gradle Plugin 9.0.1 + Kotlin 2.3.20 + dependencies** ~ 700MB-1GB
3.  **تحميل NDK + compileSdk** لو مش موجود
4.  **تجميع Dart AOT + تجميع 3 معماريات** `arm64-v8a, armeabi-v7a, x86_64`

على إنترنت متوسط ده بياخد **15-40 دقيقة أول مرة**. لو فصلت النت أو قفلت الـ terminal في النص، هايعيد التحميل من الأول.

**مهم:** في الـ sandbox بتاع Arena مفيش Flutter/Android SDK أصلاً، فـ `flutter build apk` مش هيشتغل هناك نهائياً - لازم تبني على جهازك أو على GitHub Actions (شف آخر الملف).

## 2) شخّص المشكلة بسرعة

شغّل بالأمر ده عشان تشوف واقف فين بالظبط (مش هيعلق صامت):

```bash
flutter clean
flutter pub get
flutter build apk --release --split-per-abi --verbose 2>&1 | Tee build.log
```

لو واقف عند `Downloading https://services.gradle.org/distributions/gradle-9.1.0-all.zip` يبقى مشكلة نت.
لو واقف عند `Resolving dependencies` يبقى Maven بطيء.
لو واقف عند `Running Gradle task 'assembleRelease'` بدون progress لدقائق يبقى RAM/CPU.

للتأكد من البيئة:

```bash
flutter doctor -v
flutter --version
java -version   # لازم JDK 17
gradle --version # (اختياري)
```

## 3) الحلول السريعة (جرّب بالترتيب)

### أ. ما تلغيش البناء في النص
سيبه يكمل للآخر حتى لو 30 دقيقة. تاني مرة هيبقى 2-4 دقائق بس بسبب الـ cache.

### ب. استخدم `--split-per-abi` (أسرع 30-50%)
بدل ما يبني APK واحد فيه 3 معماريات (تقيل):

```bash
flutter build apk --release --split-per-abi
# الناتج: app-arm64-v8a-release.apk (هو اللي 95% من الأجهزة الحديثة بتحتاجه)
# موجود في: build/app/outputs/flutter-apk/
```

### ج. اتأكد من المساحة والرام
- محتاج **10GB فاضي** على الـ C:
- اقفل Android Emulator + Chrome + VS Code تقيل أثناء البناء
- **تم تعديل `android/gradle.properties` في المشروع:** قللنا `-Xmx8G` لـ `-Xmx4G` + فعلنا `parallel` و `caching`. الـ 8G كان بيخلي أجهزة 8GB RAM تعمل swapping وتبطّء جداً.

لو جهازك 8GB RAM فقط، خليه:
```
org.gradle.jvmargs=-Xmx2G -XX:MaxMetaspaceSize=512m
```

### د. النت والـ Firewall
- اقفل VPN/Proxy
- لو في مصر والـ Maven بطيء، جرّب Hotspot من الموبايل مرة واحدة للتحميل الأول
- اقفل Windows Defender مؤقتاً على فولدر المشروع (Real-time protection بيفحص كل ملف Gradle)

### هـ. نظّف الكاش لو البناء باظ
```bash
flutter clean
# احذف يدوياً لو لسه بطيء:
# Windows: rmdir /s /q %USERPROFILE%\.gradle\caches
# macOS/Linux: rm -rf ~/.gradle/caches
flutter pub get
```

### و. جرّب Debug أولاً للتأكد إن المشروع سليم
```bash
flutter build apk --debug --split-per-abi --verbose
# لو ده نجح بسرعة، يبقى المشكلة في خطوة الـ shrink/minify للـ release فقط
```

## 4) إيه اللي اتصلّح في المشروع ده؟

1.  `android/gradle.properties`:
    ```properties
    org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G ...
    org.gradle.parallel=true
    org.gradle.caching=true
    org.gradle.configureondemand=true
    org.gradle.daemon=true
    kotlin.incremental=true
    ```
    ده بيسرّع تاني build بنسبة كبيرة.

2.  `android/app/build.gradle.kts`: ثبتنا `isMinifyEnabled = false` للـ release مؤقتاً (أسرع). بعد ما أول APK يطلع بنجاح، تقدر ترجعه `true` لو عايز تصغير الحجم.

3.  أضفنا GitHub Actions (`.github/workflows/build-apk.yml`): تقدر تبني APK في السحابة بدون ما تستهلك جهازك. ادخل تب GitHub > Actions > Build APK > Run workflow > حمّل الـ APK من Artifacts.

## 5) بناء سحابي بدون ما تبني محلياً (أنصح بيه)

1. اعمل `git push` للـ branch ده `arena/01a0258d-car-guard`
2. افتح GitHub > Actions > هتلاقي `Build APK (Release)` شغال تلقائياً
3. بعد 6-10 دقائق حمّل الـ APK من `Artifacts` (app-arm64-v8a-release.apk)
4. جرّبه على موبايلك

ده بيحل مشكلة النت البطيء والـ Gradle تماماً.

## 6) checklist قبل ما تفتح issue

- [ ] شغلت `flutter doctor` وكل علاماته ✅ (Android toolchain ✅)
- [ ] JDK 17 مثبت (`java -version` يطبع 17)
- [ ] جربت `flutter build apk --release --split-per-abi --verbose` وسيبته 30 دقيقة كاملة
- [ ] شفت `build.log` وعرفت واقف فين
- [ ] جربت البناء السحابي من Actions

لو لسه واقف، ابعت `build.log` آخر 100 سطر + ناتج `flutter doctor -v` وسأساعدك فوراً.
