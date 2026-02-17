import 'dart:ui_web' as ui_web;
import 'dart:js_interop'; // Required for .toJS
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Registers the AdSense HTML view factory.
/// This allows us to use HtmlElementView to render an <iframe> or <ins> tag.
/// Migrated to package:web for WASM compatibility.
void registerAdSenseFactory() {
  if (!kIsWeb) return;

  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(
    'ad-sense-view',
    (int viewId) {
      // package:web 0.5.x: createElement takes simple string in some versions, but returns JSAny?
      // Casting to HTMLDivElement is correct for standard elements.
      final element = web.document.createElement('div') as web.HTMLDivElement;
      
      // We insert the <ins> tag dynamically
      // innerHTML expects JSAny / JSString in strict interop
      element.innerHTML = '''
        <ins class="adsbygoogle"
             style="display:block"
             data-ad-client="ca-pub-7236930031419838"
             data-ad-slot="1234567890"
             data-ad-format="auto"
             data-full-width-responsive="true"></ins>
        <script>
             (adsbygoogle = window.adsbygoogle || []).push({});
        </script>
      '''.toJS;
      
      return element;
    },
  );
}
