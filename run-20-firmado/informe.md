# Informe del AAB

Fichero: `ATankStory-0.2.20.aab` — 58M

## Manifiesto
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android" android:compileSdkVersion="36" android:compileSdkVersionCodename="16" android:installLocation="0" android:versionCode="20" android:versionName="0.2.20" package="com.pabloprieto.tankahead" platformBuildVersionCode="36" platformBuildVersionName="16">
      
  <uses-sdk android:minSdkVersion="29" android:targetSdkVersion="36"/>
      
  <supports-screens android:largeScreens="true" android:normalScreens="true" android:smallScreens="true" android:xlargeScreens="true"/>
      
  <uses-feature android:glEsVersion="0x00030000" android:required="true"/>
      
  <uses-permission android:name="android.permission.INTERNET"/>
      
  <uses-feature android:name="android.hardware.vulkan.level" android:required="false" android:version="1"/>
      
  <uses-feature android:name="android.hardware.vulkan.version" android:required="false" android:version="0x00401000"/>
      
  <uses-permission android:name="android.permission.AD_ID"/>
      
  <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
      
  <uses-permission android:name="com.google.android.gms.permission.AD_ID"/>
      
  <uses-permission android:name="android.permission.ACCESS_ADSERVICES_AD_ID"/>
      
  <uses-permission android:name="android.permission.ACCESS_ADSERVICES_ATTRIBUTION"/>
      
  <uses-permission android:name="android.permission.ACCESS_ADSERVICES_TOPICS"/>
   
    
  <queries>
            
        
    <intent>
                  
      <action android:name="android.intent.action.VIEW"/>
                  
      <category android:name="android.intent.category.BROWSABLE"/>
                  
      <data android:scheme="https"/>
              
    </intent>
            
        
        
    <intent>
                  
      <action android:name="android.support.customtabs.action.CustomTabsService"/>
              
    </intent>
            
        
        
    <intent>
                  
      <action android:name="android.intent.action.INSERT"/>
                  
      <data android:mimeType="vnd.android.cursor.dir/event"/>
              
    </intent>
            
    <intent>
                  
```

## Comprobaciones
- ✅ package="com.pabloprieto.tankahead", minSdk=29
- ✅ targetSdk=36 (Google Play exige 36 o más)
- ✅ No es depurable
- Permisos declarados: android.permission.ACCESS_ADSERVICES_AD_ID android.permission.ACCESS_ADSERVICES_ATTRIBUTION android.permission.ACCESS_ADSERVICES_TOPICS android.permission.ACCESS_NETWORK_STATE android.permission.AD_ID android.permission.FOREGROUND_SERVICE android.permission.INTERNET android.permission.WAKE_LOCK com.android.vending.BILLING com.google.android.gms.permission.AD_ID 
- ✅ Solo permisos previstos

## Librerías nativas (alineación 16 KB)
- ✅ base/lib/arm64-v8a/libgodot_android.so alineación: 0x4000 
- ✅ base/lib/arm64-v8a/libc++_shared.so alineación: 0x4000 

## Configuración del bundle
    {
      "bundletool": {
        "version": "1.16.0"
      },
      "optimizations": {
        "splitsConfig": {
        },
        "uncompressNativeLibraries": {
          "enabled": true,
          "alignment": "PAGE_ALIGNMENT_16K"
        },
        "storeArchive": {
          "enabled": true
        }
      },
      "compression": {
        "uncompressedGlob": ["**.3[gG]2", "**.3[gG][pP]", "**.3[gG][pP][pP]", "**.3[gG][pP][pP]2", "**.[aA][aA][cC]", "**.[aA][mM][rR]", "**.[aA][wW][bB]", "**.[gG][iI][fF]", "**.[iI][mM][yY]", "**.[jJ][eE][tT]", "**.[jJ][pP][eE][gG]", "**.[jJ][pP][gG]", "**.[mM]4[aA]", "**.[mM]4[vV]", "**.[mM][iI][dD]", "**.[mM][iI][dD][iI]", "**.[mM][kK][vV]", "**.[mM][pP]2", "**.[mM][pP]3", "**.[mM][pP]4", "**.[mM][pP][eE][gG]", "**.[mM][pP][gG]", "**.[oO][gG][gG]", "**.[oO][pP][uU][sS]", "**.[pP][nN][gG]", "**.[rR][tT][tT][tT][lL]", "**.[sS][mM][fF]", "**.[tT][fF][lL][iI][tT][eE]", "**.[wW][aA][vV]", "**.[wW][eE][bB][mM]", "**.[wW][eE][bB][pP]", "**.[wW][mM][aA]", "**.[wW][mM][vV]", "**.[xX][mM][fF]"]
      }
    }

## Firma
- ✅ Firma verificada
- Huella SHA-256 del certificado de subida: `A4:C7:3B:06:1A:B3:C2:51:9A:82:FA:69:30:FF:69:FE:2F:F9:A3:16:63:CA:51:D1:33:5B:81:42:75:A8:9B:80`
- ✅ Coincide con la huella esperada

**Resultado: correcto**
