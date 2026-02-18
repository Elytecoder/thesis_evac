# 🔧 Quick Fix: "No pubspec.yaml file found"

## ❌ Problem
```
Error: No pubspec.yaml file found.
This command should be run from the root of your flutter project
```

## ✅ Solution

You're running `flutter run` from the wrong directory. You need to be in the `mobile` folder.

### Run this command:

```bash
cd c:\Users\elyth\thesis_evac\mobile
```

Then run:

```bash
flutter run
```

---

## 📁 Directory Structure

Your project structure:
```
c:\Users\elyth\thesis_evac\
├── backend\          ← Django backend
├── mobile\           ← Flutter app (YOU NEED TO BE HERE!)
│   ├── lib\
│   ├── android\
│   └── pubspec.yaml  ← Flutter looks for this file
└── ...
```

The `flutter run` command must be run from the `mobile` folder where `pubspec.yaml` is located.

---

**Quick Fix:** Just run `cd c:\Users\elyth\thesis_evac\mobile` then `flutter run` again! 🚀
