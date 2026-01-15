// Conditional export for different platforms
export 'ad_manager_web.dart'
    if (dart.library.io) 'ad_manager_mobile.dart';