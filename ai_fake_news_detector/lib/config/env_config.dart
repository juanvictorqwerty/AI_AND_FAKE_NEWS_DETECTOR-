class EnvConfig {
  static const String baseUrlNode = String.fromEnvironment(
    'BASE_URL_NODE',
    defaultValue: 'http://192.168.1.152:4000',
  );

  static const String baseUrlFastApi = String.fromEnvironment(
    'BASE_URL_FASTAPI',
    defaultValue: 'http://192.168.1.152:8000',
  );

  static const String nativeFactCheckUrl = String.fromEnvironment(
    'NATIVE_FACT_CHECK_URL',
    defaultValue: 'http://192.168.1.152:4000',
  );

  static const String nativeMediaUploadUrl = String.fromEnvironment(
    'NATIVE_MEDIA_UPLOAD_URL',
    defaultValue: 'http://192.168.1.152:8000',
  );

  static const String customScheme = String.fromEnvironment(
    'CUSTOM_SCHEME',
    defaultValue: 'afnd',
  );
}
