# Navigation Architecture Diagram

## 🗺️ COMPLETE NAVIGATION FLOW

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            WELCOME SCREEN                                     │
│                          (Entry Point)                                        │
└────────────────────┬───────────────────────────┬──────────────────────────────┘
                     │                           │
        ┌────────────▼─────────────┐  ┌─────────▼──────────┐
        │     LOGIN SCREEN         │  │  REGISTER SCREEN    │
        │  (Navigator.push)        │  │  (Navigator.push)   │
        └────────────┬─────────────┘  └─────────┬──────────┘
                     │                           │
                     │ pushReplacement           │ pushReplacement
                     │ (no back to login)        │ (no back to register)
                     │                           │
        ┌────────────▼─────────────┐  ┌─────────▼──────────┐
        │   ADMIN HOME SCREEN      │  │    MAP SCREEN       │
        │  (if role = MDRRMO)      │  │  (if role = Resident)│
        └────────────┬─────────────┘  └─────────┬──────────┘
                     │                           │
                     │                           │
┌────────────────────┴────────────┐              │
│   ADMIN BOTTOM NAVIGATION       │              │
│   (BottomNavigationBar)         │              │
│                                 │              │
│  ┌──────────────────────────┐  │              │
│  │  Dashboard (Tab 0)       │──┼──────────────┼────────────┐
│  │  [NO BACK BUTTON] ✅     │  │              │            │
│  └──────────────────────────┘  │              │            │
│                                 │              │            │
│  ┌──────────────────────────┐  │              │            │
│  │  Reports (Tab 1)         │──┼──────────────┼────────┐   │
│  │  [NO BACK BUTTON] ✅     │  │              │        │   │
│  └──────────────────────────┘  │              │        │   │
│                                 │              │        │   │
│  ┌──────────────────────────┐  │              │        │   │
│  │  Map Monitor (Tab 2)     │──┼──────────────┼───┐    │   │
│  │  [NO BACK BUTTON] ✅     │  │              │   │    │   │
│  └──────────────────────────┘  │              │   │    │   │
│                                 │              │   │    │   │
│  ┌──────────────────────────┐  │              │   │    │   │
│  │  Centers (Tab 3)         │──┼──────────────┼─┐ │    │   │
│  │  [NO BACK BUTTON] ✅     │  │              │ │ │    │   │
│  └──────────────────────────┘  │              │ │ │    │   │
│                                 │              │ │ │    │   │
│  ┌──────────────────────────┐  │              │ │ │    │   │
│  │  Analytics (Tab 4)       │──┼──────────────┼─┼─┼─┐  │   │
│  │  [NO BACK BUTTON] ✅     │  │              │ │ │ │  │   │
│  └──────────────────────────┘  │              │ │ │ │  │   │
│                                 │              │ │ │ │  │   │
│  ┌──────────────────────────┐  │              │ │ │ │  │   │
│  │  Settings (Tab 5)        │──┼──────────────┼─┼─┼─┼──┼─┐ │
│  │  [NO BACK BUTTON] ✅     │  │              │ │ │ │  │ │ │
│  └──────────────────────────┘  │              │ │ │ │  │ │ │
└─────────────────────────────────┘              │ │ │ │  │ │ │
                                                 │ │ │ │  │ │ │
┌────────────────────────────────────────────────┘ │ │ │  │ │ │
│ ADMIN DETAIL SCREENS (Navigator.push)           │ │ │  │ │ │
│ [ALL HAVE BACK BUTTONS] ✅                       │ │ │  │ │ │
│                                                  │ │ │  │ │ │
│  ┌─────────────────────────────────────┐        │ │ │  │ │ │
│  │  Report Detail Screen               │◄───────┘ │ │  │ │ │
│  │  • AppBar with back button          │          │ │  │ │ │
│  │  • Navigator.pop() returns          │          │ │  │ │ │
│  └─────────────────────────────────────┘          │ │  │ │ │
│                                                    │ │  │ │ │
│  ┌─────────────────────────────────────┐          │ │  │ │ │
│  │  Evacuation Center Detail           │◄─────────┴─┘  │ │ │
│  │  • AppBar with back button          │                │ │ │
│  │  • Navigator.pop() returns          │                │ │ │
│  └────────────┬────────────────────────┘                │ │ │
│               │                                          │ │ │
│               │ Navigator.push                           │ │ │
│               ▼                                          │ │ │
│  ┌─────────────────────────────────────┐                │ │ │
│  │  Edit Center Screen                 │                │ │ │
│  │  • AppBar with back button          │                │ │ │
│  │  • Returns to Center Detail         │                │ │ │
│  └────────────┬────────────────────────┘                │ │ │
│               │                                          │ │ │
│               │ Navigator.push                           │ │ │
│               ▼                                          │ │ │
│  ┌─────────────────────────────────────┐                │ │ │
│  │  Map Location Picker                │                │ │ │
│  │  • AppBar with back button          │                │ │ │
│  │  • Navigator.pop(location)          │                │ │ │
│  └─────────────────────────────────────┘                │ │ │
│                                                          │ │ │
│  ┌─────────────────────────────────────┐                │ │ │
│  │  Center Map View Screen             │                │ │ │
│  │  • AppBar with back button          │                │ │ │
│  │  • Returns to Center Detail         │                │ │ │
│  └─────────────────────────────────────┘                │ │ │
│                                                          │ │ │
│  ┌─────────────────────────────────────┐                │ │ │
│  │  Add Center Screen                  │◄───────────────┘ │ │
│  │  • AppBar with back button          │                  │ │
│  │  • Returns to Centers Management    │                  │ │
│  └─────────────────────────────────────┘                  │ │
│                                                            │ │
└────────────────────────────────────────────────────────────┘ │
                                                               │
┌──────────────────────────────────────────────────────────────┘
│ RESIDENT DETAIL SCREENS (Navigator.push)
│ [ALL HAVE BACK BUTTONS / CANCEL BUTTONS] ✅
│
│  ┌─────────────────────────────────────┐
│  │  Settings Screen                    │◄────────────┐
│  │  • AppBar with back button          │             │
│  │  • Returns to Map Screen            │             │
│  └────────────┬────────────────────────┘             │
│               │                                       │
│               │ Logout (pushAndRemoveUntil)          │
│               ▼                                       │
│            WELCOME SCREEN                             │
│            (Stack cleared)                            │
│                                                       │
│  ┌─────────────────────────────────────┐             │
│  │  Report Hazard Screen               │◄────────────┤
│  │  • AppBar with back button          │             │
│  │  • Returns to Map Screen            │             │
│  └─────────────────────────────────────┘             │
│                                                       │
│  ┌─────────────────────────────────────┐             │
│  │  Routes Selection Screen            │◄────────────┤
│  │  • AppBar with back button          │             │
│  │  • Returns to Map Screen            │             │
│  └────────────┬────────────────────────┘             │
│               │                                       │
│               │ Navigator.push                        │
│               ▼                                       │
│  ┌─────────────────────────────────────┐             │
│  │  Route Danger Details Screen        │             │
│  │  • AppBar with back button          │             │
│  │  • Returns to Routes Selection      │             │
│  └─────────────────────────────────────┘             │
│                                                       │
│  ┌─────────────────────────────────────┐             │
│  │  Live Navigation Screen             │             │
│  │  • Cancel button (Navigator.pop)    │             │
│  │  • Returns to Routes Selection      │             │
│  └─────────────────────────────────────┘             │
│                                                       │
└───────────────────────────────────────────────────────┘
```

---

## 🎯 KEY NAVIGATION PATTERNS

### Pattern 1: Login/Register (No Back)
```
WelcomeScreen
    ↓ Navigator.push
LoginScreen / RegisterScreen
    ↓ Navigator.pushReplacement (on success)
AdminHomeScreen / MapScreen
    ↙ (CANNOT go back to login)
```

**Why**: Using `pushReplacement` prevents users from accidentally going back to login after authentication.

---

### Pattern 2: Bottom Navigation (Tab Switching)
```
AdminHomeScreen (Container)
    ├─ Dashboard (setState currentIndex = 0)
    ├─ Reports (setState currentIndex = 1)
    ├─ Map Monitor (setState currentIndex = 2)
    ├─ Centers (setState currentIndex = 3)
    ├─ Analytics (setState currentIndex = 4)
    └─ Settings (setState currentIndex = 5)
```

**Why**: Tab switching is done via `setState`, not `Navigator.push`. This prevents navigation stack buildup.

**Back Button Behavior**: Main tabs have `automaticallyImplyLeading: false` to hide back buttons.

---

### Pattern 3: Detail Navigation (With Back)
```
ReportsManagementScreen
    ↓ Navigator.push
ReportDetailScreen
    ↙ Navigator.pop (back button)
ReportsManagementScreen
```

**Why**: Detail screens are pushed onto the stack, allowing natural back navigation.

**Back Button Behavior**: Default AppBar behavior shows back button automatically.

---

### Pattern 4: Deep Navigation Stack
```
CentersManagementScreen
    ↓ Navigator.push
CenterDetailScreen
    ↓ Navigator.push
EditCenterScreen
    ↓ Navigator.push
MapLocationPicker
    ↙ Navigator.pop
EditCenterScreen
    ↙ Navigator.pop
CenterDetailScreen
    ↙ Navigator.pop
CentersManagementScreen
```

**Why**: Each `Navigator.push` adds to the stack. Each `Navigator.pop` removes from the stack. This creates a natural navigation hierarchy.

---

### Pattern 5: Logout (Complete Stack Clear)
```
AnyScreen
    ↓ Logout action
    ↓ Navigator.pushAndRemoveUntil(
    │     route: WelcomeScreen,
    │     predicate: (route) => false
    │ )
WelcomeScreen
    ↙ (CANNOT go back to authenticated screens)
```

**Why**: `pushAndRemoveUntil` with `(route) => false` removes all routes from the stack, ensuring complete logout.

---

### Pattern 6: Modal Dialogs
```
AnyScreen
    ↓ showDialog()
Dialog (Logout confirmation, etc.)
    ↓ Navigator.pop(context, value)
AnyScreen (with returned value)
```

**Why**: Dialogs are overlays, not navigation stack entries. They use `Navigator.pop` to close and optionally return values.

---

## 📊 NAVIGATION DECISION TREE

```
Need to navigate to a new screen?
│
├─ Is it a main tab in BottomNavigationBar?
│  └─ YES → Use setState to change tab index
│            Add automaticallyImplyLeading: false to AppBar
│
├─ Is it after successful login/register?
│  └─ YES → Use Navigator.pushReplacement
│            (prevents back to login)
│
├─ Is it a logout action?
│  └─ YES → Use Navigator.pushAndRemoveUntil(route, (r) => false)
│            (clears entire stack)
│
├─ Is it a detail/sub screen?
│  └─ YES → Use Navigator.push
│            (allows back navigation)
│            DO NOT add automaticallyImplyLeading: false
│
├─ Is it a modal dialog?
│  └─ YES → Use showDialog + Navigator.pop
│            (dialog overlay, not navigation)
│
└─ Returning from a screen?
   └─ Use Navigator.pop(context, optionalReturnValue)
```

---

## 🔍 TROUBLESHOOTING FLOWCHART

```
User reports: "Back button appears where it shouldn't"
│
├─ Is the screen a main tab?
│  ├─ YES → Check if automaticallyImplyLeading: false is set
│  │         If not, add it to AppBar
│  │
│  └─ NO → Back button should be there (it's a detail screen)
│
User reports: "Back button missing where it should be"
│
├─ Is the screen a detail/sub screen?
│  ├─ YES → Check if automaticallyImplyLeading: false is set
│  │         If yes, remove it
│  │
│  └─ NO → Check if AppBar exists
│           Check if screen is opened with Navigator.push
│
User reports: "Going back takes me to login"
│
├─ Check if login/register uses pushReplacement
│  └─ If using Navigator.push, change to pushReplacement
│
├─ Check if logout uses pushAndRemoveUntil
│  └─ If not, change to pushAndRemoveUntil
│
User reports: "Cannot go back after multiple navigations"
│
├─ Check if tab switching uses setState
│  └─ If using Navigator.push for tabs, change to setState
│
├─ Check for WillPopScope blocking back navigation
│  └─ If found, review logic or remove
```

---

## 💡 BEST PRACTICES CHECKLIST

- ✅ Main tab screens: `automaticallyImplyLeading: false`
- ✅ Detail screens: Default AppBar (no override)
- ✅ Login success: `Navigator.pushReplacement`
- ✅ Logout: `Navigator.pushAndRemoveUntil(route, (r) => false)`
- ✅ Tab switching: `setState` not `Navigator.push`
- ✅ Detail navigation: `Navigator.push`
- ✅ Modal dialogs: `showDialog` + `Navigator.pop`
- ✅ Screen returns: `Navigator.pop` with optional value
- ✅ No `WillPopScope` unless absolutely necessary
- ✅ No custom back button implementations (use default)

---

**Last Updated**: 2026-02-08
**Diagram Version**: 1.0
