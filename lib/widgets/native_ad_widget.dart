// Conditional export for different platforms
export 'native_ad_widget_web.dart'
    if (dart.library.io) 'native_ad_widget_mobile.dart';
