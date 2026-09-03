class DeviceEndpoints {
  static const dashboard = '/data';
  static const getAllSettings = '/getallsettings';
  static const saveAllSettings = '/saveallsettings';
  static const saveAdvancedSettings = '/saveadvancedsettings';
  static const calibrateVoltage = '/calibratevoltage';
  static const getWifiSettings = '/getwifisettings';
  static const saveWifiSettings = '/savewifi';
  static const joinWifi = '/joinwifi';
  static const factoryReset = '/factoryreset';
  static const restart = '/restart';
  static const mute = '/mute';
  static const testFan = '/testfan';

  /// Keeps the radiator fan running regardless of the automatic algorithm.
  static const fanForce = '/fanforce';

  /// Hands the fan back to the automatic temperature algorithm.
  static const fanRelease = '/fanrelease';
  static const otaUpdate = '/update';
}
