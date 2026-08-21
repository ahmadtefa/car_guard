import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/providers/settings_provider.dart';

/// Lightweight typed translations for the whole app.
///
/// The original Kayan dashboard shipped a small ar/en dictionary; this is the
/// same idea with compile-time-safe getters. Add a string here first, then
/// reference it from widgets.
class AppL10n {
  const AppL10n(this.languageName);

  /// Either 'en' or 'ar'.
  final String languageName;

  bool get isAr => languageName == 'ar';

  // ---------- General ----------
  String get appName => isAr ? 'حارس العربية' : 'Car Guard';
  String get connected => isAr ? 'متصل' : 'Connected';
  String get disconnected => isAr ? 'غير متصل' : 'Disconnected';
  String get liveReading => isAr ? 'قراءة حية' : 'Live reading';
  String get noData => isAr ? 'لا توجد بيانات' : 'No data';
  String get lastUpdated => isAr ? 'آخر تحديث' : 'Last updated';
  String get monitoring => isAr ? 'مراقبة' : 'Monitoring';
  String get cancel => isAr ? 'إلغاء' : 'Cancel';
  String get retry => isAr ? 'إعادة المحاولة' : 'Retry';
  String get on => isAr ? 'تعمل' : 'ON';
  String get off => isAr ? 'متوقفة' : 'OFF';
  String get available => isAr ? 'متوفر' : 'Available';
  String get low => isAr ? 'منخفض' : 'Low';
  String get needsAttention => isAr ? 'يحتاج انتباه' : 'Needs attention';
  String get normal => isAr ? 'طبيعي' : 'Normal';
  String get unknown => isAr ? 'غير معروف' : 'Unknown';

  // ---------- Gauges / HUD ----------
  String get engineTempLabel => isAr ? 'حرارة المحرك' : 'ENGINE TEMP';
  String get batteryVoltLabel => isAr ? 'جهد البطارية' : 'BATTERY VOLT';
  String get tapToClose => isAr ? 'اضغط للخروج' : 'Tap to close';
  String get last5Minutes => isAr ? 'آخر 5 دقائق' : 'Last 5 minutes';
  String get collectingData => isAr ? 'جمع البيانات...' : 'Collecting data...';

  // ---------- Trip / GPS ----------
  String get vehicleSpeed => isAr ? 'سرعة العربية' : 'Vehicle speed';
  String get tripDistance => isAr ? 'المسافة المقطوعة' : 'Trip distance';
  String get resetTrip => isAr ? 'تصفير المسافة' : 'Reset trip';
  String get kmh => isAr ? 'كم/س' : 'km/h';
  String get km => isAr ? 'كم' : 'km';
  String get gpsOff => isAr
      ? 'شغّل خدمة الموقع (GPS) عشان تشتغل السرعة والمسافة.'
      : 'Turn on Location services for speed and distance.';
  String get locationDenied => isAr
      ? 'إذن الموقع مرفوض — السرعة والمسافة مش هتشتغل.'
      : 'Location permission denied — speed and distance stay off.';

  // ---------- Dashboard cards ----------
  String get connectionStatus => isAr ? 'حالة الاتصال' : 'Connection Status';
  String get streamingLive =>
      isAr ? 'قراءات حية متدفقة' : 'Streaming live readings';
  String get waitingForDevice =>
      isAr ? 'في انتظار الجهاز...' : 'Waiting for device...';
  String get engineTemperature => isAr ? 'حرارة المحرك' : 'Engine Temperature';
  String get coolantSensorInfo =>
      isAr ? 'حساس حرارة المحرك' : 'Coolant temperature sensor';
  String get batteryVoltage => isAr ? 'جهد البطارية' : 'Battery Voltage';
  String get vehicleBatteryInfo =>
      isAr ? 'قراءة بطارية العربية' : 'Vehicle battery reading';
  String get voltageDifference => isAr ? 'فرق الجهد' : 'Voltage Difference';
  String get chargingDeltaInfo =>
      isAr ? 'الفرق بين الشحن والسكون' : 'Charging vs. resting delta';
  String get voltageDeltaInfo => isAr
      ? 'تغير الجهد خلال آخر دقيقة ونص.'
      : 'Voltage change over the last ~90 seconds.';
  String get deltaRising =>
      isAr ? 'الجهد في ارتفاع (شحن) ⬆️' : 'Voltage rising (charging) ⬆️';
  String get deltaFalling =>
      isAr ? 'الجهد في انخفاض ⬇️' : 'Voltage dropping ⬇️';
  String get deltaStable => isAr ? 'مستقر' : 'Stable';
  String get coolantLevel => isAr ? 'مستوى المياه' : 'Coolant Level';
  String get coolantReservoirInfo =>
      isAr ? 'حالة خزان الردييتر' : 'Coolant reservoir status';
  String get radiatorFan => isAr ? 'مروحة الردييتر' : 'Radiator Fan';
  String get fanShort => isAr ? 'المروحة' : 'Fan';
  String get fanSystemInfo =>
      isAr ? 'حالة مروحة التبريد' : 'Cooling system fan status';
  String fanOnAt(String temp) =>
      isAr ? 'تشغيل عند > $temp°م' : 'ON at > $temp°C';
  String get alternator => isAr ? 'الدينامو' : 'Alternator';
  String get charging => isAr ? 'يشحن' : 'Charging';
  String get notCharging => isAr ? 'لا يشحن' : 'Not charging';
  String chargingHealthy(String volt) => isAr
      ? 'نظام الشحن سليم ($volt فولت)'
      : 'Charging system healthy ($volt V)';
  String notChargingV(String volt) =>
      isAr ? 'لا يشحن ($volt فولت)' : 'Not charging ($volt V)';

  String get systemOk => isAr ? 'النظام يعمل' : 'System OK';
  String get demoCodeLabel => isAr ? 'كود وضع المحاكاة' : 'Demo mode code';
  String get wrongDemoCode => isAr ? 'الكود غير صحيح!' : 'Wrong code!';
  String get fullscreenGauges => isAr
      ? 'العدادات بالشاشة الكاملة'
      : 'Fullscreen gauges';
  String get close => isAr ? 'إغلاق' : 'Close';
  String get readingsAndCharts => isAr
      ? 'القراءات والرسوم البيانية'
      : 'Readings & charts';

  // ---------- OTA update ----------
  String get otaUpdate => isAr ? 'تحديث الجهاز (OTA)' : 'Update device (OTA)';
  String get otaInfo => isAr
      ? 'اختر ملف الفيرموير (.bin) الخاص بالجهاز وارفعه — أثناء التحديث لا تغلق التطبيق.'
      : 'Pick the module firmware file (.bin) and upload it — keep the app open during the update.';
  String get otaCodeLabel => isAr ? 'كود التحديث' : 'Update code';
  String get enterOtaCode => isAr
      ? 'أدخل كود التحديث للمتابعة.'
      : 'Enter the update code to continue.';
  String get selectFirmware => isAr
      ? 'اختيار ملف الفيرموير' : 'Select firmware file';
  String get noFileSelected => isAr ? 'لم يتم اختيار ملف' : 'No file selected';
  String get uploadAndFlash => isAr ? 'رفع وتحديث الجهاز' : 'Upload & flash';
  String get uploading => isAr ? 'جاري رفع الفيرموير...' : 'Uploading firmware…';
  String get otaPickFirst => isAr
      ? 'اختر ملف الفيرموير أولاً.' : 'Pick the firmware file first.';
  String get otaInvalidFile => isAr
      ? 'الملف لازم يكون بامتداد .bin' : 'The file must have a .bin extension.';
  String get otaSuccess => isAr
      ? 'تم التحديث! الجهاز بيعيد التشغيل خلال ثوانٍ.'
      : 'Updated! The module is rebooting in a few seconds.';
  String get otaFailed => isAr
      ? 'فشل التحديث — تأكد من الملف والاتصال بالجهاز.'
      : 'Update failed — check the file and the connection.';

  // ---------- Module limits / sync ----------
  String get moduleLimits => isAr ? 'حدود الإنذار على الجهاز' : 'Module alarm limits';
  String get moduleLimitsInfo => isAr
      ? 'كما هي محفوظة على الوحدة نفسها.'
      : 'As stored on the module itself.';
  String get notReported => isAr
      ? 'الجهاز لم يبلغ عنها بعد.'
      : 'Not reported by the module yet.';
  String get alarmTempShort => isAr ? 'درجة الإنذار' : 'Alarm temp';
  String get fanOnShort => isAr ? 'تشغيل المروحة' : 'Fan ON';
  String get minVoltShort => isAr ? 'أقل جهد' : 'Min volt';
  String get maxVoltShort => isAr ? 'أقصى جهد' : 'Max volt';
  String get moduleAlarmActive =>
      isAr ? 'إنذار الجهاز شغال الآن!' : 'Module alarm is firing!';
  String get moduleMuted => isAr ? 'صفارة الجهاز مكتومة' : 'Module buzzer muted';
  String valueOutOfRange(String label) =>
      isAr ? '$label خارج النطاق المسموح من الجهاز.' : '$label is outside the range allowed by the module.';
  String get wifiLoadFailed => isAr
      ? 'تعذر قراءة إعدادات الواي فاي من الجهاز.'
      : 'Could not load Wi-Fi settings from the module.';

  // ---------- Style picker ----------
  String get dashboardStyle => isAr ? 'شكل الداشبورد' : 'Dashboard style';
  String get styleCards => isAr ? 'كروت كلاسيك' : 'Classic cards';
  String get styleRacing => isAr ? 'سباق' : 'Racing';
  String get styleSporty => isAr ? 'سبورت' : 'Sporty gauges';
  String get styleSegments => isAr ? 'أعمدة مجزأة' : 'Segmented bars';
  String get styleSweeper => isAr ? 'عداد أودي' : 'Audi sweeper';
  String get styleRing => isAr ? 'نيون دائري' : 'Neon ring';
  String get styleLed => isAr ? 'شريط LED' : 'LED strip';
  String get styleNeedle => isAr ? 'عداد إبرة' : 'Needle meter';
  String get styleOrb => isAr ? 'كرة سائلة' : 'Liquid orb';
  String get styleCombo => isAr ? 'كلستر رقمي' : 'Digital cluster';

  // ---------- Device controls ----------
  String get deviceControls => isAr ? 'تحكم في الجهاز' : 'Device Controls';
  String get sendCommandsInfo => isAr
      ? 'أوامر مباشرة للجهاز'
      : 'Send commands straight to the module';
  String get disabledInDemo =>
      isAr ? 'معطل أثناء الوضع التجريبي' : 'Disabled while demo mode is running';
  String get muteAlarm => isAr ? '🔇 كتم الإنذار' : '🔇 Mute alarm';
  String get enableAlarm => isAr ? '🔊 تشغيل الإنذار' : '🔊 Enable alarm';
  String get testFan => isAr ? 'تجربة المروحة' : 'Test fan';
  String get restartDevice => isAr ? 'إعادة تشغيل الجهاز' : 'Restart device';
  String get moduleSettings => isAr ? 'إعدادات الجهاز' : 'Module settings';
  String get deviceConnection => isAr ? 'الاتصال بالجهاز' : 'Device connection';
  String get deviceAddressLabel => isAr ? 'عنوان الجهاز (IP)' : 'Device address (IP)';
  String get deviceAddressInfo => isAr
      ? 'الافتراضي 192.168.4.1 لما الموبايل بيشبك على شبكة الجهاز مباشرة. غيّره بس لو الجهاز اتنقل لشبكة تانية (زي هوتسبوت الموبايل).'
      : 'Default 192.168.4.1 when the phone joins the module Wi-Fi directly. Change it only if the module joined another network (like the phone hotspot).';
  String get applyAndReconnect =>
      isAr ? 'حفظ وإعادة الاتصال' : 'Save & reconnect';
  String get directPairTitle => isAr
      ? 'اتصال مباشر + إنترنت 4G'
      : 'Direct link + 4G internet';
  String get directPairInfo => isAr
      ? 'اتصال خاص بالتطبيق بشبكة الجهاز من غير ما أندرويد يعتبرها شبكة الإنترنت — الموبايل يفضل على بيانات 4G.'
      : 'An app-only link to the module Wi-Fi, so Android keeps the phone on 4G internet.';
  String get pairingAction => isAr ? 'وصّل دلوقتي' : 'Connect now';
  String get pairingStarted => isAr
      ? 'وافق على نافذة أندرويد اللي طلعت (Pair) — التطبيق هيوصل بالجهاز من غير ما النت يفصل.'
      : 'Approve the Android pairing sheet — the app stays linked while 4G keeps internet.';
  String get pairingDenied => isAr
      ? 'محتاجين إذن "الأجهزة القريبة" عشان نوصل مباشرة.'
      : 'We need the "Nearby devices" permission to pair directly.';
  String get pairingUnsupported => isAr
      ? 'الميزة دي محتاجة أندرويد 10 أو أحدث.'
      : 'This needs Android 10 or newer.';
  String get pairingNeedsGps => isAr
      ? 'شغّل خدمة الموقع (GPS) الأول — أندرويد مش بيسمح بالاتصال المباشر وهي مقفولة.'
      : 'Turn on Location services first — Android blocks direct pairing while they are off.';
  String get buzzerMuted =>
      isAr ? 'تم كتم الصفارة على الجهاز' : 'Buzzer muted on the module';
  String get fanTestStarted =>
      isAr ? 'بدأت تجربة المروحة' : 'Fan test started';
  String get deviceRestarting =>
      isAr ? 'الجهاز يعيد التشغيل...' : 'Device is restarting...';
  String get commandFailed =>
      isAr ? 'فشل الأمر — هل الجهاز متصل؟' : 'Command failed — device reachable?';

  // ---------- Background monitoring ----------
  String get backgroundSection =>
      isAr ? 'المراقبة في الخلفية' : 'Background monitoring';
  String get backgroundSectionInfo => isAr
      ? 'تفحص القراءات والتطبيق في الخلفية أو الشاشة مقفولة (أندرويد).'
      : 'Keeps watching readings while the app is in the background or the screen is off (Android).';
  String get backgroundToggle =>
      isAr ? 'تشغيل في الخلفية' : 'Run in background';
  String get backgroundToggleInfo => isAr
      ? 'إشعار دائم بالقراءة الحالية + تشغيل تلقائي بعد إعادة تشغيل الموبايل.'
      : 'Persistent notification with live readings + auto-start after phone reboot.';
  String get serviceStarted =>
      isAr ? 'بدأت المراقبة في الخلفية' : 'Background monitoring started';
  String get serviceStopped =>
      isAr ? 'توقفت المراقبة في الخلفية' : 'Background monitoring stopped';
  String get notificationsRequired => isAr
      ? 'إذن الإشعارات مطلوب لتنبيهات الخلفية — فعّله من إعدادات النظام.'
      : 'Notifications permission is required for background alerts — enable it from system settings.';
  String get serviceStartFailed => isAr
      ? 'تعذر تشغيل الخدمة — جرّب تاني.'
      : 'Could not start the service — try again.';

  // ---------- Alerts ----------
  String get connectionLostTitle => isAr ? 'انقطع الاتصال' : 'Connection lost';
  String get connectionLostMessage => isAr
      ? 'جهاز الحارس لم يعد متاحاً.'
      : 'The Car Guard device is no longer reachable.';
  String get engineOverheatTitle =>
      isAr ? 'حرارة المحرك مرتفعة جداً!' : 'Engine overheating!';
  String engineOverheatMessage(String temp) => isAr
      ? 'حرارة المحرك $temp°م. توقف بأمان وافحص نظام التبريد.'
      : 'Engine temperature is $temp °C. Stop safely and check the cooling system.';
  String get engineTempHighTitle =>
      isAr ? 'حرارة المحرك مرتفعة' : 'Engine temperature high';
  String engineTempHighMessage(String temp) => isAr
      ? 'حرارة المحرك $temp°م. راقب العداد.'
      : 'Engine temperature is $temp °C. Keep an eye on the gauge.';
  String get batteryLowTitle =>
      isAr ? 'جهد البطارية منخفض' : 'Battery voltage low';
  String batteryLowMessage(String volt, String min) => isAr
      ? 'البطارية عند $volt فولت، أقل من الحد $min فولت.'
      : 'Battery is at $volt V, below the configured minimum of $min V.';
  String get batteryHighTitle =>
      isAr ? 'جهد البطارية مرتفع' : 'Battery voltage high';
  String batteryHighMessage(String volt, String max) => isAr
      ? 'جهد الشحن $volt فولت أعلى من الحد $max فولت. افحص الدينامو والمنظم.'
      : 'Charging voltage is $volt V — above the maximum of $max V. Have the alternator and regulator checked.';
  String get coolantLowTitle =>
      isAr ? 'مياه الردييتر ناقصة' : 'Coolant level low';
  String get coolantLowMessage =>
      isAr ? 'خزان الردييتر يحتاج تعبئة.' : 'The coolant reservoir needs a top-up.';
  String moreAlerts(int count) => isAr
      ? '+$count تنبيه إضافي'
      : '+$count more alert${count > 1 ? 's' : ''}';

  // ---------- Settings page ----------
  String get settings => isAr ? 'الإعدادات' : 'Settings';
  String get advancedModuleSettings =>
      isAr ? 'الإعدادات المتقدمة للجهاز' : 'Advanced module settings';
  String get appearance => isAr ? 'المظهر' : 'Appearance';
  String get chooseLook =>
      isAr ? 'اختر شكل التطبيق.' : 'Choose how the app looks.';
  String get auto => isAr ? 'تلقائي' : 'Auto';
  String get light => isAr ? 'نهاري' : 'Light';
  String get dark => isAr ? 'ليلي' : 'Dark';
  String get language => isAr ? 'اللغة' : 'Language';
  String get demoMode => isAr ? 'الوضع التجريبي' : 'Demo mode';
  String get demoModeInfo => isAr
      ? 'محاكاة جهاز كامل لتجربة التطبيق بدون الهاردوير.'
      : 'Simulate a Car Guard device to explore the app without hardware.';
  String get simulatedDevice => isAr ? 'جهاز محاكى' : 'Simulated device';
  String get simulatedDeviceInfo => isAr
      ? 'قراءات واقعية للكروت والعدادات والتنبيهات بدون الجهاز.'
      : 'Feeds realistic readings so cards, charts and alerts work without the module.';
  String get alertsSection => isAr ? 'التنبيهات' : 'Alerts';
  String get alertsSectionInfo => isAr
      ? 'الحدود التي تشغل تحذيرات الداشبورد والإشعارات.'
      : 'Thresholds that trigger dashboard warnings and notifications.';
  String get alertsEnabled => isAr ? 'التنبيهات مفعلة' : 'Alerts enabled';
  String get alertsEnabledInfo => isAr
      ? 'المفتاح الرئيسي لكل الإشعارات.'
      : 'Master switch for all notifications.';
  String get moduleLimitsNote => isAr
      ? 'تنبيهات الحرارة وجهد البطارية بتتبع حدود الإنذار المحفوظة على الوحدة نفسها (قسم إعدادات الجهاز فوق).'
      : 'Temperature and voltage alerts follow the alarm limits saved on the module itself (Module settings above).';
  String get coolantAlerts => isAr ? 'تنبيهات المياه' : 'Coolant alerts';
  String get coolantAlertsInfo =>
      isAr ? 'تنبيه عند نقص مياه الردييتر.' : 'Notify when the coolant level is low.';
  String get connectionAlerts =>
      isAr ? 'تنبيهات الاتصال' : 'Connection alerts';
  String get connectionAlertsInfo =>
      isAr ? 'تنبيه عند قطع اتصال الجهاز.' : 'Notify when the device connection drops.';
  String get resetToDefaults =>
      isAr ? 'إرجاع الإعدادات الافتراضية' : 'Reset to defaults';
  String get settingsSaved =>
      isAr ? 'تم حفظ الإعدادات' : 'Settings saved';

  // ---------- Connection page ----------

  // ---------- Module settings page ----------
  String get moduleInfo => isAr ? 'بيانات الجهاز' : 'Module info';
  String get reportedByFirmware =>
      isAr ? 'من الفيرموير مباشرة.' : 'Reported by the firmware.';
  String get serialLabel => isAr ? 'الرقم التسلسلي' : 'Serial';
  String get installedLabel => isAr ? 'تاريخ التشغيل' : 'Installed';
  String get unknownDate => isAr ? 'غير محدد' : 'unknown';
  String get alarmLimits => isAr ? 'حدود الإنذار' : 'Alarm limits';
  String get savedOnModuleInfo =>
      isAr ? 'تُحفظ على الجهاز مباشرة.' : 'Saved directly on the module.';
  String get fanOnTempLabel =>
      isAr ? 'درجة تشغيل المروحة (°م)' : 'Fan ON temperature (°C)';
  String get alarmTempLabel =>
      isAr ? 'درجة الإنذار (°م)' : 'Alarm temperature (°C)';
  String get minVoltLabel => isAr ? 'أقل جهد للبطارية (فولت)' : 'Minimum battery voltage (V)';
  String get maxVoltLabel => isAr ? 'أعلى جهد للبطارية (فولت)' : 'Maximum battery voltage (V)';
  String get saveToModule => isAr ? 'حفظ على الجهاز' : 'Save to module';
  String get testFan5s => isAr ? 'تجربة المروحة (5 ثوان)' : 'Test fan (5s)';
  String get restartModule => isAr ? 'إعادة تشغيل الجهاز' : 'Restart module';
  String get savedToModule =>
      isAr ? 'تم حفظ الإعدادات على الجهاز' : 'Settings saved to the module';
  String get failedReachable =>
      isAr ? 'فشل — هل الجهاز متصل؟' : 'Failed — device reachable?';
  String get restartMsg =>
      isAr ? 'الجهاز يعيد التشغيل...' : 'Module is restarting...';
  String get restartFailed =>
      isAr ? 'فشل أمر إعادة التشغيل' : 'Restart command failed';
  String get moduleWifi => isAr ? 'واي فاي الجهاز' : 'Module Wi-Fi';
  String get moduleWifiInfo => isAr
      ? 'الجهاز سيعيد تشغيل الشبكة بعد الحفظ.'
      : 'The module will restart its network after saving.';
  String get ssidLabel => isAr ? 'اسم الشبكة (SSID)' : 'Network name (SSID)';
  String get passwordLabel => isAr ? 'كلمة السر' : 'Password';
  String get saveWifi => isAr ? 'حفظ الواي فاي' : 'Save Wi-Fi';
  String wifiSent(String ssid) => isAr
      ? 'تم إرسال إعدادات الواي فاي — اتصل بـ "$ssid" لو الجهاز أعاد التشغيل.'
      : 'Wi-Fi settings sent — connect to "$ssid" if the module restarted.';
  String get cantReadModule => isAr
      ? 'تعذر قراءة إعدادات الجهاز. تأكد أن التطبيق متصل بجهاز الحارس.'
      : 'Could not read the module settings. Make sure the app is connected to the Car Guard device.';
  String mustBeNumber(String label) =>
      isAr ? '$label يجب أن يكون رقماً.' : '$label must be a number.';
  String get fanLowerThanAlarm => isAr
      ? 'درجة المروحة يجب أن تكون أقل من درجة الإنذار.'
      : 'Fan temperature must be lower than the alarm temperature.';
  String get minLowerThanMax => isAr
      ? 'أقل جهد يجب أن يكون أقل من أقصى جهد.'
      : 'Minimum voltage must be lower than the maximum voltage.';
  String get ssidTooShort => isAr
      ? 'اسم الشبكة يجب أن يكون 4 أحرف على الأقل.'
      : 'Network name must be at least 4 characters.';
  String get passwordTooShort => isAr
      ? 'كلمة السر يجب أن تكون 8 أحرف على الأقل.'
      : 'Password must be at least 8 characters.';
  String get advancedSection => isAr ? 'متقدم' : 'Advanced';
  String get advancedSectionInfo =>
      isAr ? 'أدوات معايرة محمية بكلمة سر.' : 'Password-protected calibration tools.';

  // ---------- Advanced calibration page ----------
  String get calibration => isAr ? 'المعايرة' : 'Calibration';
  String get enterCodeToContinue => isAr
      ? 'أدخل كود المعايرة للمتابعة.'
      : 'Enter the calibration code to continue.';
  String get calibrationCodeLabel =>
      isAr ? 'كود المعايرة' : 'Calibration code';
  String get unlock => isAr ? 'دخول' : 'Unlock';
  String get wrongCode =>
      isAr ? 'كود المعايرة غير صحيح!' : 'Wrong calibration code!';
  String get readingCalibration =>
      isAr ? 'معايرة القراءات' : 'Reading calibration';
  String get readingCalibrationInfo =>
      isAr ? 'ضبط دقيق لما يبلّغه الجهاز.' : 'Fine-tune what the module reports.';
  String get tempOffsetLabel =>
      isAr ? 'إزاحة الحرارة (±°م)' : 'Temperature offset (±°C)';
  String get voltCalibLabel =>
      isAr ? 'معامل معايرة الجهد' : 'Voltage calibration factor';
  String get voltageWizard => isAr ? 'معالج معايرة الجهد' : 'Voltage wizard';
  String get voltageWizardInfo => isAr
      ? 'قس البطارية بالملتيميتر وادخل القيمة الحقيقية — الجهاز يعيد حساب المعامل.'
      : 'Measure the battery with a multimeter and enter the real value — the module recalculates its factor.';
  String get realVoltageLabel =>
      isAr ? 'الجهد المقاس فعلياً (فولت)' : 'Real measured voltage (V)';
  String get calibrateNow => isAr ? 'معايرة الجهد الآن' : 'Calibrate voltage now';
  String get dividerAndSensor =>
      isAr ? 'مقسم الجهد والحساس' : 'Voltage divider & sensor';
  String get dividerAndSensorInfo =>
      isAr ? 'قيم الهاردوير بتاعة الجهاز.' : 'Hardware values of your module.';
  String get r1Label => isAr ? 'مقاومة R1 (أوم)' : 'R1 resistance (ohm)';
  String get r2Label => isAr ? 'مقاومة R2 (أوم)' : 'R2 resistance (ohm)';
  String get pullUpLabel =>
      isAr ? 'مقاومة الرفع Pull-up (أوم)' : 'Sensor pull-up resistance (ohm)';
  String get installDateLabel =>
      isAr ? 'تاريخ التشغيل' : 'Install date (yyyy-mm-dd)';
  String get saveCalibration => isAr ? 'حفظ المعايرة' : 'Save calibration';
  String get reloadFromModule =>
      isAr ? 'إعادة القراءة من الجهاز' : 'Reload from module';
  String get calibrationSaved =>
      isAr ? 'تم حفظ المعايرة' : 'Calibration saved';
  String newFactor(String factor) => isAr
      ? 'تمت المعايرة! المعامل الجديد: $factor'
      : 'Calibrated! New factor: $factor';
  String get voltageRangeError =>
      isAr ? 'أدخل جهد بين 8 و 18 فولت.' : 'Enter a voltage between 8 and 18 V.';
  String get calibrationFailed => isAr
      ? 'فشلت المعايرة — تأكد من الاتصال وقيمة الجهد.'
      : 'Calibration failed — check the connection and the voltage value.';
  String get restartModuleQ => isAr ? 'إعادة تشغيل الجهاز؟' : 'Restart module?';
  String get restartConfirmBody => isAr
      ? 'الجهاز هيعيد التشغيل والاتصال هيقطع لثواني.'
      : 'The module will reboot and the connection will drop for a few seconds.';
  String get restart => isAr ? 'إعادة تشغيل' : 'Restart';
}

/// Exposes the current translations, rebuilt whenever the language changes.
final l10nProvider = Provider<AppL10n>((ref) {
  final languageName =
      ref.watch(settingsProvider).value?.languageName ?? 'en';

  return AppL10n(languageName);
});
