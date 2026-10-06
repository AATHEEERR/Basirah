# استعادة بصيرة وتشغيلها على أي جهاز

هذا الدليل يرافق النسخة الاحتياطية التي يصنعها `tool/backup.ps1`. يمكن بها إصلاح المشروع بعد أي عطل، أو تشغيله على جهاز آخر.

## ما في النسخة الاحتياطية

| الملف | ما فيه |
|---|---|
| `basirah.bundle` | مستودع git كاملاً بكل تاريخه |
| `basirah_files.zip` | ملفات المشروع كما هي لحظة النسخ، ومعها أي تعديل لم يُحفظ في git بعد |
| `runtime_data.zip` | `server/data` (نص المصحف المجهّز) و`server/cache` (التفسير والأحاديث وروابط التلاوة والترجمات والإجابات المحفوظة وأرقام «لوحة الأثر») |
| `secrets/server.env` | مفاتيح الذكاء الاصطناعي. **سرّي:** لا يُرفع إلى GitHub ولا يُرسل في محادثة |
| `project_documents.zip` | الملفات المرجعية، والعرض التقديمي، ووصف المشروع، والصور |
| `tools/cloudflared.exe` | أداة Cloudflare الرسمية للرابط العام |
| `SHA256SUMS.txt` | بصمة كل ملف للتأكد من سلامته |

## الحالة 1: تلف أو حذف في المشروع على نفس الجهاز

```powershell
# من داخل مجلد IslamicAI
git clone "backups\Basirah_Backup_<التاريخ>\basirah.bundle" basirah_restored
```

ثم انسخ `secrets\server.env` إلى `basirah_restored\server\.env`، وفك `runtime_data.zip` داخل `basirah_restored\server\`.

## الحالة 2: جهاز جديد (ويندوز)

1. **ثبّت الأدوات:**
   - Git: <https://git-scm.com/download/win>
   - Flutter **3.41.9** (معه Dart 3.11.5): <https://docs.flutter.dev/install/archive>، وفكّه في `C:\src\flutter`
   - Google Chrome
2. **استرجع المشروع:**
   ```powershell
   git clone <مسار النسخة>\basirah.bundle basirah
   cd basirah
   ```
3. **أعد الملفات غير المحفوظة في git:**
   - انسخ `secrets\server.env` إلى `basirah\server\.env`.
   - فك `runtime_data.zip` داخل `basirah\server\`، فيظهر `server\data` و`server\cache`.
4. **تأكد أن كل شيء سليم:**
   ```powershell
   flutter pub get
   cd server; dart pub get; dart test; cd ..
   flutter test
   ```
5. **شغّل الرابط الحي:**
   ```powershell
   powershell -ExecutionPolicy Bypass -File tool\start_live.ps1
   ```
   يبني الموقع، ويشغّل الخادم، ويطبع رابطاً عاماً بالشكل `https://….trycloudflare.com`. أبقِ النافذتين مفتوحتين. الرابط يتغير في كل تشغيل.

## الحالة 3: رابط دائم (Render)

1. ارفع المستودع إلى GitHub:
   ```powershell
   git remote add origin https://github.com/<الحساب>/basirah.git
   git push -u origin main
   ```
2. في render.com: New ← Blueprint ← اختر المستودع. يقرأ Render ملف `render.yaml` ويطلب `ANTHROPIC_API_KEY` و`GEMINI_API_KEY` و`SPECIALIST_ACCOUNTS` (حسابات المختصين: سطر لكل حساب تصنعه الأداة `server/tool/specialist_account.dart`، وتفصل بينها «;»؛ وهو نفسه في `server/.env`). الصقها هناك فقط.
3. قبل كل نشر جديد ابنِ نسخة الموقع: `powershell -File tool\build_web_for_deploy.ps1`، ثم اعمل commit وpush.

## ملاحظات

- **مجلد OneDrive:** مجلد `IslamicAI` كله داخل OneDrive، فالنسخ الاحتياطية في `IslamicAI\backups` تُرفع إلى السحابة تلقائياً. ولأن `server.env` بداخلها، لا تشارك مجلد النسخ مع أحد.
- **نسخة جديدة:** شغّل `powershell -ExecutionPolicy Bypass -File tool\backup.ps1` بعد أي عمل مهم.
- **التحقق من سلامة النسخة:** `git bundle verify basirah.bundle`، وقارن البصمات في `SHA256SUMS.txt` بأمر `Get-FileHash`.
