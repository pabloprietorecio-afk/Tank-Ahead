# Informe del AAB

Fichero: `ATankStory-PRUEBA-NO-SUBIR.aab` — 52M

## Manifiesto
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android" android:compileSdkVersion="36" android:compileSdkVersionCodename="16" android:installLocation="0" android:versionCode="2" android:versionName="0.2.2" package="com.pabloprieto.tankahead" platformBuildVersionCode="36" platformBuildVersionName="16">
      
  <uses-sdk android:minSdkVersion="29" android:targetSdkVersion="36"/>
      
  <supports-screens android:largeScreens="true" android:normalScreens="true" android:smallScreens="true" android:xlargeScreens="true"/>
      
  <uses-feature android:glEsVersion="0x00030000" android:required="true"/>
      
  <uses-permission android:name="android.permission.INTERNET"/>
      
  <uses-feature android:name="android.hardware.vulkan.level" android:required="false" android:version="1"/>
      
  <uses-feature android:name="android.hardware.vulkan.version" android:required="false" android:version="0x00401000"/>
      
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
              
    </activity-alias>
            
    <profileable android:enabled="true" android:shell="true"/>
     
        
    <meta-data android:name="org.godotengine.library.version" android:value="4.7.2.stable"/>
            
    <activity android:exported="false" android:name="org.godotengine.godot.utils.ProcessPhoenix" android:process=":phoenix" android:theme="@android:style/Theme.Translucent.NoTitleBar"/>
            
    <provider android:authorities="com.pabloprieto.tankahead.fileprovider" android:exported="false" android:grantUriPermissions="true" android:name="androidx.core.content.FileProvider">
                  
      <meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/godot_provider_paths"/>
              
    </provider>
            
    <provider android:authorities="com.pabloprieto.tankahead.androidx-startup" android:exported="false" android:name="androidx.startup.InitializationProvider">
                  
      <meta-data android:name="androidx.profileinstaller.ProfileInstallerInitializer" android:value="androidx.startup"/>
              
    </provider>
            
    <receiver android:directBootAware="false" android:enabled="true" android:exported="true" android:name="androidx.profileinstaller.ProfileInstallReceiver" android:permission="android.permission.DUMP">
                  
      <intent-filter>
                        
```

## Comprobaciones
- ✅ package="com.pabloprieto.tankahead", minSdk=29
- ✅ targetSdk=36 (Google Play exige 36 o más)
- ✅ No es depurable
- Permisos declarados: android.permission.INTERNET 
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
tools/aab/inspect_aab.sh: line 56: echo: write error: Broken pipe
- ❌ El AAB no está firmado o la firma no es válida
- Huella SHA-256 del certificado de subida: `35:65:39:C1:AF:32:36:30:3D:6C:56:DD:04:E4:69:B2:C9:6B:E5:3D:A1:FC:FA:FD:96:CB:3C:33:45:AC:2A:12`
- ✅ Coincide con la huella esperada

**Resultado: HAY PROBLEMAS**
