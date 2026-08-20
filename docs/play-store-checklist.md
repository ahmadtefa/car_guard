# ✅ خريطة الرفع على Google Play Store — Car Guard

## المرحلة 1: حساب المطوّر
- [ ] فتح حساب Google Play Developer ($25 مرة واحدة): https://play.google.com/console
- [ ] إكمال بيانات المطوّر (الاسم اللي هيظهر، بريد، هاتف)

## المرحلة 2: الهوية والتوقيع (مهم جداً — قبل أول تحميل)
- [x] `applicationId` اتحوّل لـ `com.kayan.carguard` (غيّره دلوقتي لو عايز اسم تاني — بعد النشر مستحيل يتغير!)
- [ ] إنشاء keystore الإصدار (مرة واحدة، خليه في مكان آمن جداً + خد نسخة احتياطية):
```bash
keytool -genkey -v -keystore ~/car_guard_release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias carguard
```
- [x] إعداد التوقيع جاهز في الـ gradle — يقرأ `android/key.properties` تلقائياً ويرجع للـ debug لو الملف مش موجود
- [ ] ملف `android/key.properties` (متضيفش الجواب ده على git!):
```properties
storePassword=كلمة_سر_الـ_keystore
keyPassword=كلمة_سر_المفتاح
keyAlias=carguard
storeFile=/home/ahmd/car_guard_release.jks
```
- [x] تم — إعداد التوقيع مضاف تلقائياً في الـ gradle

## المرحلة 3: قبل بناء نسخة المتجر ⚠️
- [ ] **شيل بلوك خدمة Android Auto من `AndroidManifest.xml`** (فئة غير مسموح بيها في مراجعة Play — الميزة تفضل موجودة في نسختك الشخصية، والشات ده في الأسفل لو حبيت ترجعها):
```xml
<!-- احذف هذا البلوك قبل نسخة Play -->
<service
    android:name=".CarGuardCarAppService"
    android:exported="true">
    <intent-filter>
        <action android:name="androidx.car.app.CarAppService" />
        <category android:name="androidx.car.app.category.POI" />
    </intent-filter>
</service>
```
(خلي `minCarApiLevel` أو اشيله — مش مهم)

## المرحلة 4: متطلبات المحتوى والسياسات
- [x] **صفحة Privacy Policy جاهزة** في `docs/privacy-policy.html` (عربي/إنجليزي) — ارفعها على GitHub Pages والصق الرابط في الكونسول
- [ ] نموذج "Data safety" في الكونسول: لا يوجد جمع بيانات (Set to "No data collected")
- [ ] Content rating questionnaire (تصنيف "Everyone" أو "3+")
- [ ] التصريحات في الكونسول:
  - Foreground service (dataSync): سبب = مراقبة بيانات المركبة
  - RECEIVE_BOOT_COMPLETED: إعادة تشغيل خدمة المراقبة
  - طلب تجاهل تحسين البطارية: اختياري للمستخدم
- [ ] Target API level: شغال بأحدث SDK — عادة مقبول تلقائياً

## المرحلة 5: الأصول
- [x] أيقونة التطبيق جاهزة في `assets/icon/app_icon.png` — نفّذ الأمر التالي مرة على جهازك لتوليد كل المقاسات:
```bash
flutter pub get && dart run flutter_launcher_icons
```
- [ ] لقطات شاشة: هاتف (2-8 صور) + 7/10 بوصة لو هتعلّم مدعوم للتابلت
- [x] نصوص المتجر (عربي/إنجليزي) جاهزة في `docs/play-listing.md`
- [ ] صورة بارزة 1024×500

## المرحلة 6: البناء والرفع
```bash
flutter build appbundle --release
```
- [ ] رفع `.aab` على Testing track الأول (Internal testing) — جرّبه بنفسك على الموبايل من رابط الاختبار
- [ ] بعدها Closed testing → Open testing → Production
- [ ] أول مراجعة من جوجل تأخذ من ساعات لـ 7 أيام — عادي

## ملاحظات
- **iOS/CarPlay**: محتاج حساب Apple Developer ($99/سنة) + جهاز Mac للبناء — CarPlay نفسه مش ممكن (قيود الفئات)
- النسخة الشخصية (بالـ Android Auto) تفضل كـ APK جانبي ليك: `flutter build apk --release`
