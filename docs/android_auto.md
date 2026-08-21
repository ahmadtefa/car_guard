# Car Guard على Android Auto

## اللي اتعمل

التطبيق دلوقتي بيدعم **Android Auto** عن طريق مكتبة جوجل الرسمية
[Android for Cars App Library](https://developer.android.com/training/cars/apps)
بفئة التطبيقات `IoT` (التحكم في الأجهزة).

لما توصّل الموبايل بالعربية هيظهر **Car Guard** في قائمة التطبيقات على شاشة
العربية، ولما تفتحه هتلاقي لوحة حالة بالعربي بتتحدّث تلقائي كل ٣ ثواني:

- فولت البطارية (+ فرق الفولت لو بيتبعت)
- حرارة المحرك
- مستوى ماء التبريد
- حالة المروحة
- حالة الإنذار (بيحل محل صف الاتصال لما الإنذار شغّال)

القيم الخطرة (بطارية أقل من 11.5V أو حرارة 100°C أو أكتر أو مياه ناقصة)
بتظهر **بالأحمر**. وفي زرار **كتم الإنذار** بيضرب على endpoint `/mute`
بتاع الجهاز، وزرار **تحديث** في الهيدر.

## إزاي الشاشة دي بتشتغل

- شاشة العربية **مش** واجهة Flutter — دي قوالب قيادة آمنة (Templates) بترسمها
  شاشة العربية نفسها. دي الطريقة الوحيدة المسموح بيها رسميًا لتطبيقات زي
  بتاعتنا أثناء القيادة.
- كود العربية (Kotlin/Car App Library) بيقرأ البيانات من ESP8266 **مباشرة** على
  طول (`http://<device>/data`)، فبيشتغل حتى لو واجهة التطبيق مقفولة على الموبايل.
- عنوان الجهاز بيتشارك مع التطبيق عن طريق SharedPreferences: التطبيق بيحفظ
  المفتاح `device_host` (صفحة الاتصال بتحفظه دلوقتي عند الضغط على Connect)،
  وشاشة العربية بتقراه. لو مفيش قيمة محفوظة بيستخدم الافتراضي `192.168.4.1`.
- الملفات الجديدة:
  - `android/app/src/main/res/xml/automotive_app_desc.xml`
  - `android/app/src/main/res/values/strings.xml` (نصوص الشاشة بالعربي)
  - `android/app/src/main/res/drawable/ic_*_24.xml` (أيقونات الشاشة)
  - `android/app/src/main/kotlin/com/example/car_guard/car/`:
    `CarGuardCarAppService.kt`, `CarGuardSession.kt`,
    `CarGuardDashboardScreen.kt`, `DeviceClient.kt`

## التشغيل والتجربة (عربيتك / وضع المطوّر)

1. ابني التطبيق وثبّته على الموبايل:

   ```bash
   flutter build apk --debug
   # أو
   flutter run
   ```

2. على الموبايل افتح **Android Auto** ← الإعدادات ← انزل تحت خالص واضغط على
   **رقم الإصدار** ١٠ مرات لتفعيل **إعدادات المطوّر**.
3. من قائمة النقاط (⋮) فوق افتح **إعدادات المطوّر** وفعّل **مصادر غير معروفة**
   (Unknown sources) — مطلوبة لأن التطبيق مش منزل من Play.
4. وصّل الموبايل بالعربية (USB أو لاسلكي) وافتح **Car Guard** من قائمة
   التطبيقات على شاشة العربية.
5. لو ظهرت رسالة "الجهاز غير متصل": اتأكد إن الموبايل متوصّل بشبكة الـ Wi-Fi
   بتاعة الجهاز، وافتح التطبيق على الموبايل الأول مرة واحدة على الأقل.

### تجربة من غير عربية

من الـ SDK بتاع Android فيه **Desktop Head Unit (DHU)** بيحاكي شاشة العربية:
`./desktop-head-unit` وبعدين على الموبايل من إعدادات مطوّر Android Auto اختار
"Start head unit server" وشغّل `adb forward tcp:5277 tcp:5277`.

## لو هتنشر على Google Play

- الفئة المصرّح بيها للتطبيق ده هي **IoT** — اختارها في إعدادات التطبيق في Play
  Console (Android Auto → App category → IoT) أو في بيان التطبيق.
- قبل الرفع عدّل `CarGuardCarAppService.createHostValidator()` بحيث الـ release
  يستخدم **قائمة سماح** صارمة بدل `ALLOW_ALL_HOSTS_VALIDATOR`:

  ```kotlin
  return HostValidator.Builder(applicationContext)
      .addAllowedHosts(R.array.hosts_allowlist)
      .build()
  ```

  مع ملف `res/values/arrays.xml` فيه توقيعات شهادات الـ host الرسمية
  (Android Auto / Automotive OS) زي الأمثلة الرسمية في مستندات جوجل.
- جوجل بتراجع تطبيقات العربيات يدويًا (App Quality Guidelines) — اللوحة هنا
  معمولة بالـ Templates القياسية فده متوافق مع الشروط.

## ملاحظات فنية

- `minSdk` اترفع لـ 23 كحد أقصى بين إصدار Flutter والـ 23 المطلوب من مكتبة
  السيارات (Android Auto أصلًا محتاج Android 8+).
- `usesCleartextTraffic="true` في الـ manifest ضروري لأن الجهاز بيشتغل HTTP
  (من غير تشفير) على الشبكة المحلية — من غيره الـ HTTP الـ native بيتمنع على
  Android 9+. (تطبيق Flutter نفسه بيستخدم HTTP بتاع Dart فكان شغّال، لكن كود
  العربية بيستخدم شبكة أندرويد.)
- اتضاف إذن `INTERNET` للـ manifest الرئيسي عشان نسخة الـ release تقدر توصّل
  للجهاز (قبل كده كان موجود في debug بس).
- زر "كتم الإنذار" بيبعت طلب GET على `/mute`. لو الفيرموير بيستقبل POST بدل
  GET أو endpoint مختلف، عدّل `DeviceClient.muteAlarm()`.
- اتجاه RTL والـ day/night theme بيتحسب تلقائيًا من شاشة العربية.
