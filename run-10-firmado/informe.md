# Informe del AAB

Fichero: `ATankStory-0.2.10.aab` — 53M

## Manifiesto
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android" android:compileSdkVersion="36" android:compileSdkVersionCodename="16" android:installLocation="0" android:versionCode="10" android:versionName="0.2.10" package="com.pabloprieto.tankahead" platformBuildVersionCode="36" platformBuildVersionName="16">
      
  <uses-sdk android:minSdkVersion="29" android:targetSdkVersion="36"/>
      
  <supports-screens android:largeScreens="true" android:normalScreens="true" android:smallScreens="true" android:xlargeScreens="true"/>
      
  <uses-feature android:glEsVersion="0x00030000" android:required="true"/>
      
  <uses-permission android:name="android.permission.INTERNET"/>
      
  <uses-feature android:name="android.hardware.vulkan.level" android:required="false" android:version="1"/>
      
  <uses-feature android:name="android.hardware.vulkan.version" android:required="false" android:version="0x00401000"/>
      
  <uses-permission android:name="com.android.vending.BILLING"/>
      
  <queries>
            
    <intent>
                  
      <action android:name="com.android.vending.billing.InAppBillingService.BIND"/>
              
    </intent>
            
    <intent>
                  
      <action android:name="com.google.android.apps.play.billingtestcompanion.BillingOverrideService.BIND"/>
              
    </intent>
        
  </queries>
      
  <permission android:name="com.pabloprieto.tankahead.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION" android:protectionLevel="0x00000002"/>
      
  <uses-permission android:name="com.pabloprieto.tankahead.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"/>
   
    
    
  <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
      
  <application android:allowBackup="false" android:appCategory="0" android:appComponentFactory="androidx.core.app.CoreComponentFactory" android:extractNativeLibs="false" android:hasFragileUserData="false" android:icon="@mipmap/icon" android:isGame="true" android:label="@string/godot_project_name_string" android:requestLegacyExternalStorage="false">
            
    <meta-data android:name="org.godotengine.rendering.method" android:value="mobile"/>
            
    <meta-data android:name="org.godotengine.editor.version" android:value="4.7.2.stable"/>
            
    <activity android:configChanges="0x00003ff4" android:excludeFromRecents="false" android:exported="false" android:launchMode="4" android:name="com.godot.game.GodotApp" android:resizeableActivity="true" android:screenOrientation="0" android:supportsPictureInPicture="true" android:theme="@style/GodotAppSplashTheme" android:windowSoftInputMode="0x00000010">
        </activity>
            
    <activity-alias android:exported="true" android:name="com.godot.game.GodotAppLauncher" android:targetActivity="com.godot.game.GodotApp">
                  
      <intent-filter>
                        
        <action android:name="android.intent.action.MAIN"/>
                        
        <category android:name="android.intent.category.DEFAULT"/>
                        
        <category android:name="android.intent.category.LAUNCHER"/>
                    
      </intent-filter>
```

## Comprobaciones
- ✅ package="com.pabloprieto.tankahead", minSdk=29
- ✅ targetSdk=36 (Google Play exige 36 o más)
- ✅ No es depurable
- Permisos declarados: android.permission.ACCESS_NETWORK_STATE android.permission.INTERNET com.android.vending.BILLING 
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
