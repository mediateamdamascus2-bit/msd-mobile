# تطبيق إدارة الخدمات الطبية

- [تحميل APK](https://github.com/mediateamdamascus2-bit/msd-mobile/releases/download/v1.0.0/msd-mobile-v1.0.0.apk)
- كود الخادم: https://github.com/mediateamdamascus2-bit/msd-api
- قائمة الاختبار اليدوي: [docs/migration/mobile.md](docs/migration/mobile.md)

تطبيق جوال **أصلي قابل للتثبيت** — منفصل تماماً عن موقع الويب.

| الموقع (`site/`) | التطبيق (`apps/mobile/`) |
|---|---|
| متصفح / GitHub Pages | APK يُثبَّت على الجوال |
| واجهة ويب | شاشات Flutter أصلية |
| بدون إشعارات جهاز | إشعارات محلية + إعدادات |

## ما يشمله الآن

- دخول JWT عبر `/api/auth/login` (نفس حسابات الموقع)
- الرئيسية: منشآت من `/api/facilities`
- الأحداث: `/api/facilities/{id}/events`
- الإعدادات: عنوان الخادم + فحص `/health` + إشعارات محلية

### عنوان الخادم في التطبيق

| البيئة | API Base |
|---|---|
| محاكي أندرويد | `http://10.0.2.2:5148` |
| جوال حقيقي على نفس الشبكة | `http://IP-الجهاز-المضيف:5148` |
| ويندوز/سطح المكتب | `http://127.0.0.1:5148` |

شغّل الخادم أولاً:

```bash
cd src/MedicalServices.Web
dotnet run --urls http://0.0.0.0:5148
```

## بناء APK

```bash
cd apps/mobile
flutter pub get
flutter build apk --release
```

الملف:

`build/app/outputs/flutter-apk/app-release.apk`

انقله للجوال وثبّته (فعّل مصادر غير معروفة إن لزم).

## تشغيل للتطوير

```bash
cd apps/mobile
flutter pub get
flutter run
```

يلزم جهاز أندرويد متصل أو محاكي.
