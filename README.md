# AnyPair

**Version 1.3.0**

[**Download IPA · v1.3.0**](https://github.com/mohdiu/AnyPair/releases/download/v1.3.0/AnyPair-1.3.0.ipa)

[English](#english) · [العربية](#العربية)

## English

AnyPair does one thing: it creates an **RPPairing file** on your iPhone (iOS 27+, no computer) and lets you share it or save it to Files, so you can import it into other apps.

### Features

- Pair from the phone itself: AnyPair shows up in **Settings → Privacy & Security → Developer Mode → Other Devices**.
- **Random values for each pairing** (on by default): a new name, serial number, MAC address and identifier every time — instead of the fixed `AAAAAAAAAAAA` / `11:22:33:44:55:66` — and never the same values as the previous pairing.
- After pairing it asks whether to **share** the file or **save it to Files**. Every file is also kept in the app and in Files → On My iPhone → AnyPair.
- Random, editable name (🎲 makes a new one each tap), so every pairing shows up separately in Developer Mode.
- The 6-digit code arrives as a notification while you are in Settings.
- Background keep-alive (silent audio / location) so the code still arrives while you are in Settings.
- Arabic and English interface.

> **Tip:** use a different pairing file for each app. If two apps share one file and you pair again with the same identity, the iPhone can replace the old record and the other app stops working.

### Requirements

- iPhone or iPad on **iOS 27** or later, with Developer Mode on
- A signing app to install the IPA
- Wi‑Fi

### Use

1. Open AnyPair → **Pair**, and allow Notifications and Local Network.
2. Open **Settings → Privacy & Security → Developer Mode**, and under **Other Devices** tap **Pair with …** (the name shown in AnyPair).
3. Enter your passcode, then the 6-digit code from AnyPair (also sent as a notification).
4. Choose **Share** or **Save to Files**.

### How it works

AnyPair uses the open-source [idevice](https://github.com/jkcoxson/idevice) library's pairable-host (device-initiated pairing) flow. `patches/idevice-random-identity.patch` adds `pairable_host_prepare_custom`, which lets the app set the identifier, serial number, MAC and UDID the iPhone stores for each pairing. CI builds idevice from source at a pinned commit with that patch (`scripts/build-idevice.sh`).

### Build from source

On a Mac with Xcode and Rust:

```bash
./scripts/build-idevice.sh
xcodegen generate
xcodebuild -project AnyPair.xcodeproj -scheme AnyPair -configuration Release \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

<div dir="rtl">

## العربية

تطبيق مخصص للإقران فقط: يُنشئ **ملف إقران (RPPairing)** من الآيفون نفسه (iOS 27 وأحدث، بدون كمبيوتر)، وبعدها تشاركه أو تحفظه في الملفات وتستخدمه في تطبيقات ثانية.

### المميزات

- الإقران من الجوال نفسه: يظهر <span dir="ltr">AnyPair</span> في **الإعدادات ← الخصوصية والأمن ← نمط المطور ← الأجهزة الأخرى**.
- **قيم عشوائية لكل إقران** (مفعّلة افتراضيًا): اسم ورقم تسلسلي وعنوان <span dir="ltr">MAC</span> ومعرّف جديد في كل مرة بدل القيم الثابتة <span dir="ltr">`AAAAAAAAAAAA`</span> — ولا تتكرر قيم الإقران السابق.
- بعد الإقران يسألك: تبي **تشارك** الملف أو **تحفظه في الملفات**؟ وكل ملف محفوظ أيضًا داخل التطبيق وفي تطبيق الملفات ← على الآيفون ← <span dir="ltr">AnyPair</span>.
- اسم عشوائي تقدر تعدّله (🎲 يولّد اسم جديد كل ضغطة)، عشان كل إقران يظهر باسم مختلف في نمط المطور.
- الرمز المكوّن من 6 أرقام يوصلك كإشعار وأنت في الإعدادات.
- البقاء في الخلفية (صوت صامت / الموقع) عشان يوصل الرمز وأنت في الإعدادات.
- واجهة عربي وإنجليزي.

> **نصيحة:** استخدم ملف إقران مختلف لكل تطبيق. إذا تطبيقين يستخدمون نفس الملف وسويت إقران جديد بنفس الهوية، ممكن الآيفون يستبدل القديم ويتوقف التطبيق الثاني.

### المتطلبات

- آيفون أو آيباد بنظام <strong dir="ltr">iOS 27</strong> أو أحدث، ونمط المطور مفعّل
- تطبيق توقيع لتثبيت ملف <span dir="ltr">IPA</span>
- واي فاي

### الاستخدام

1. افتح <span dir="ltr">AnyPair</span> ← **إقران**، ووافق على الإشعارات والشبكة المحلية.
2. افتح **الإعدادات ← الخصوصية والأمن ← نمط المطور**، وتحت **الأجهزة الأخرى** اضغط **<span dir="ltr">Pair with …</span>** (الاسم الظاهر في التطبيق).
3. أدخل رمز قفل الجهاز، ثم الرمز المكوّن من 6 أرقام من <span dir="ltr">AnyPair</span> (يوصلك كإشعار بعد).
4. اختر **مشاركة** أو **حفظ في الملفات**.

### كيف يعمل

يستخدم مكتبة <a dir="ltr" href="https://github.com/jkcoxson/idevice">idevice</a> مفتوحة المصدر (الإقران اللي يبدأ من الجهاز). التعديل في <span dir="ltr">`patches/idevice-random-identity.patch`</span> يضيف دالة تسمح للتطبيق يحدد المعرّف والرقم التسلسلي والـ <span dir="ltr">MAC</span> والـ <span dir="ltr">UDID</span> لكل إقران.

</div>

## License

[MIT](LICENSE). Uses the MIT-licensed [idevice](https://github.com/jkcoxson/idevice).
