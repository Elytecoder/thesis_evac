# Navigation Quick Reference Card

## 🚀 QUICK START GUIDE

### When to Show/Hide Back Button

```dart
// ❌ DON'T SHOW back button:
// Main tab screens in BottomNavigationBar

appBar: AppBar(
  title: const Text('Main Tab Screen'),
  automaticallyImplyLeading: false, // ← Add this!
)
```

```dart
// ✅ DO SHOW back button:
// Detail screens opened with Navigator.push

appBar: AppBar(
  title: const Text('Detail Screen'),
  // Default behavior - don't add anything!
)
```

---

## 🎯 NAVIGATION CHEAT SHEET

### Tab Switching (Bottom Navigation)
```dart
// Use setState, NOT Navigator.push
setState(() {
  _currentIndex = newIndex;
});
```

### Opening Detail Screen
```dart
// User can go back
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => DetailScreen(),
  ),
);
```

### Going Back
```dart
// Simple back
Navigator.pop(context);

// Back with return value
Navigator.pop(context, returnValue);
```

### Login Success
```dart
// Prevent back to login
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => HomeScreen(),
  ),
);
```

### Logout
```dart
// Clear entire stack
Navigator.pushAndRemoveUntil(
  context,
  MaterialPageRoute(
    builder: (context) => WelcomeScreen(),
  ),
  (route) => false, // Remove all routes
);
```

### Modal Dialog
```dart
// Show dialog
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    // ...
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Confirm'),
      ),
    ],
  ),
);
```

---

## 📱 SCREEN TYPES

### Main Tab Screen
- Part of `BottomNavigationBar`
- Users switch tabs, don't navigate
- **No back button**

**Examples**:
- Dashboard
- Reports Management
- Map Monitor
- Evacuation Centers
- Analytics
- Settings

**Code**:
```dart
appBar: AppBar(
  title: const Text('Tab Screen'),
  automaticallyImplyLeading: false,
)
```

---

### Detail Screen
- Opened via `Navigator.push`
- Users need to go back
- **Has back button**

**Examples**:
- Report Detail
- Center Detail
- Add/Edit screens
- Map picker
- Resident Settings

**Code**:
```dart
appBar: AppBar(
  title: const Text('Detail Screen'),
  // Default - don't add anything
)
```

---

### Full-Screen (No AppBar)
- No app bar at all
- Custom UI with floating buttons
- **No back button** (no AppBar)

**Examples**:
- Resident Map Screen
- Live Navigation Screen

**Code**:
```dart
Scaffold(
  body: Stack(
    children: [
      // Custom full-screen UI
    ],
  ),
)
```

---

## 🔍 DECISION FLOWCHART

```
Need to add/modify a screen?
│
├─ Is it a main tab?
│  └─ Add automaticallyImplyLeading: false
│
├─ Is it a detail screen?
│  └─ Use default AppBar (no changes)
│
└─ Is it full-screen?
   └─ Don't use AppBar
```

---

## ⚠️ COMMON MISTAKES

### ❌ DON'T DO THIS:

```dart
// Mistake 1: Using Navigator.push for tab switching
onTap: (index) {
  Navigator.push(context, MaterialPageRoute(...)); // ❌ WRONG
}

// Mistake 2: Adding automaticallyImplyLeading to detail screens
class DetailScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail'),
        automaticallyImplyLeading: false, // ❌ WRONG - removes back button
      ),
    );
  }
}

// Mistake 3: Using Navigator.push after login
void login() async {
  // ...
  Navigator.push( // ❌ WRONG - allows back to login
    context,
    MaterialPageRoute(builder: (context) => HomeScreen()),
  );
}

// Mistake 4: Not clearing stack on logout
void logout() async {
  Navigator.pushReplacement( // ❌ WRONG - doesn't clear stack
    context,
    MaterialPageRoute(builder: (context) => WelcomeScreen()),
  );
}
```

### ✅ DO THIS INSTEAD:

```dart
// Correct 1: Using setState for tab switching
onTap: (index) {
  setState(() {
    _currentIndex = index; // ✅ CORRECT
  });
}

// Correct 2: Default AppBar for detail screens
class DetailScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail'),
        // ✅ CORRECT - default back button
      ),
    );
  }
}

// Correct 3: Using pushReplacement after login
void login() async {
  // ...
  Navigator.pushReplacement( // ✅ CORRECT
    context,
    MaterialPageRoute(builder: (context) => HomeScreen()),
  );
}

// Correct 4: Clearing stack on logout
void logout() async {
  Navigator.pushAndRemoveUntil( // ✅ CORRECT
    context,
    MaterialPageRoute(builder: (context) => WelcomeScreen()),
    (route) => false,
  );
}
```

---

## 🐛 DEBUGGING

### Back button appears on main tab?
**Check**: Is `automaticallyImplyLeading: false` in AppBar?
```dart
appBar: AppBar(
  automaticallyImplyLeading: false, // Add this
)
```

### Back button missing on detail screen?
**Check**: Did you accidentally add `automaticallyImplyLeading: false`?
```dart
appBar: AppBar(
  // Remove automaticallyImplyLeading: false
)
```

### Can go back to login after success?
**Check**: Are you using `pushReplacement`?
```dart
Navigator.pushReplacement( // Should be this
  context,
  MaterialPageRoute(builder: (context) => HomeScreen()),
);
```

### Can go back to authenticated screens after logout?
**Check**: Are you using `pushAndRemoveUntil` with `(route) => false`?
```dart
Navigator.pushAndRemoveUntil(
  context,
  MaterialPageRoute(builder: (context) => WelcomeScreen()),
  (route) => false, // Important!
);
```

---

## 📚 REFERENCES

**Detailed Documentation**:
- `NAVIGATION_FIXES.md` - Technical implementation details
- `NAVIGATION_TESTING_GUIDE.md` - 32 test cases
- `NAVIGATION_ARCHITECTURE.md` - Visual diagrams
- `NAVIGATION_FIXES_SUMMARY.md` - Executive summary

**Flutter Documentation**:
- [AppBar class](https://api.flutter.dev/flutter/material/AppBar-class.html)
- [Navigator class](https://api.flutter.dev/flutter/widgets/Navigator-class.html)
- [BottomNavigationBar](https://api.flutter.dev/flutter/material/BottomNavigationBar-class.html)

---

## ✅ CHECKLIST FOR NEW SCREENS

- [ ] Determine screen type (Main Tab / Detail / Full-Screen)
- [ ] If Main Tab: Add `automaticallyImplyLeading: false`
- [ ] If Detail: Use default AppBar (no changes)
- [ ] If Full-Screen: No AppBar
- [ ] Test back button behavior
- [ ] Test browser/device back button
- [ ] Test navigation flow

---

**Version**: 1.0
**Last Updated**: 2026-02-08
**Keep This Card Handy!**
