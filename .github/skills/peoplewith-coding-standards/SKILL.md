---
name: peoplewith-coding-standards
description: "PeopleWith .NET MAUI coding standards, conventions, and architecture reference. Load this skill before writing, reviewing, or planning code for the PeopleWith mobile app."
---

# PeopleWith Health App — AI Coding Instructions

## 1. Overview

This is a **.NET MAUI** cross-platform health tracking app for patients with chronic conditions. It uses a **code-behind pattern** (no MVVM ViewModels), Syncfusion commercial UI controls, and a centralized REST API layer. The app targets Android (SDK 26–34), iOS (15.0+), and macOS Catalyst (15.1+).

The project lives at: `peoplewith-health-2026/PeopleWith/`

---

## 2. Tech Stack Summary

| Layer | Technology | Version |
|-------|-----------|---------|
| **Language** | C# (.NET 9) + XAML | — |
| **Framework** | .NET MAUI | 9.0.61 |
| **UI Controls** | Syncfusion.Maui.* | 29.1.37 |
| **Toolkit** | CommunityToolkit.Maui | 11.2.0 |
| **Messaging** | CommunityToolkit.Mvvm | 8.3.0 |
| **Graphics** | SkiaSharp.Views.Maui | 3.116.1 |
| **Popups** | Mopups | 1.3.1 |
| **Tabs** | Sharpnado.Tabs.Maui | 4.0.0 |
| **Notifications** | Plugin.LocalNotification | 12.0.2 |
| **Push** | Plugin.Firebase.CloudMessaging + Azure NotificationHubs | 3.1.2 / 4.2.0 |
| **Biometrics** | Plugin.Maui.Biometric + Plugin.Fingerprint | 0.0.6 / 2.1.5 |
| **Health Data** | Plugin.Maui.Health | — |
| **Storage** | Azure.Storage.Blobs | 12.22.0 |
| **Crash Reporting** | Sentry.Maui | 5.14.1 |
| **Serialization** | Newtonsoft.Json (API) + System.Text.Json (local) | — |
| **Caching** | Microsoft.Extensions.Caching.Memory | 6.0.2 |

**Key architectural choices:**
- **Code-behind pattern** — all logic in `.xaml.cs`, no ViewModel layer
- **Single centralized API class** — `APICalls.cs` handles all HTTP calls
- **Preferences-based session** — no JWT/OAuth tokens; session stored in `Preferences`
- **CommunityToolkit.Mvvm Messaging** — pub/sub with `ValueChangedMessage<T>` subclasses
- **Culture forced to `en-GB`** — no i18n/localization
- **Platform-conditional code** — `#if ANDROID` / `#if IOS` for platform differences

---

## 3. File Category Reference

### 3.1 App Infrastructure
**What:** Core application bootstrap — App.xaml, AppShell, MauiProgram, MainPage, .csproj.
**Examples:** `App.xaml.cs`, `MauiProgram.cs`
**Conventions:**
- iOS uses `NavigationPage(new MainPage())`; Android uses `AppShell`
- Syncfusion license registered in App constructor
- Culture set to `en-GB` in `MauiProgram.CreateMauiApp()`
- All plugins chained on the builder (`.UseMauiCommunityToolkit()`, `.UseLocalNotification()`, etc.)

### 3.2 Configuration
**What:** App constants and settings persistence.
**Examples:** `Constants.cs`, `Helpers/Settings.cs`
**Conventions:**
- `Constants.cs` holds Azure Notification Hub connection strings (hardcoded)
- `Helpers/Settings.cs` is a static class wrapping `Preferences.Get`/`Set` for each setting
- Each setting follows: private const key name → static readonly default → public static property
- Environment toggle via `APICalls.DevEnvironment` string constant (`"Production"` or `"Debug"`)

### 3.3 API Calls
**What:** Single monolithic class (`APICalls.cs`) handling all REST communication.
**Examples:** `APICalls.cs`
**Conventions:**
- Static `HttpClient` shared across all instances, configured with `X-MS-CLIENT-PRINCIPAL` and `X-MS-API-ROLE` headers
- Endpoint URLs defined as static string properties with OData-style `$filter`/`$select`
- GET methods return `ObservableCollection<T>` via `ApiResponse{Entity}` wrapper deserialization
- POST/PUT/PATCH use `StringContent` with JSON serialization
- Network exceptions caught and reported via `CrashDetected`
- No repository pattern, no interface, no DI for API access

### 3.4 Message Classes
**What:** Pub/sub message types for cross-component communication.
**Examples:** `NavigateTo.cs`, `UpdateCarerDash.cs`, `SendItemMessage.cs`
**Conventions:**
- Most inherit `ValueChangedMessage<T>` (usually `<object>` or `<string>`)
- Some are plain POCO classes with multiple properties (when more than one value needed)
- Named with action prefixes: `Update*`, `Add*`, `Send*`, `Navigate*`
- All live in project root (flat `PeopleWith` namespace) — not in a `Messages/` folder
- Composite payloads use a companion class in the same file (e.g., `ProgressPayload`)

### 3.5 Models
**What:** Data transfer objects matching API JSON contracts.
**Examples:** `Models/user.cs`, `Models/symptom.cs`, `Models/usersymptom.cs`
**Conventions:**
- **All-lowercase class names**: `user`, `symptom`, `medication`, `userfeedback`
- **All-lowercase property names**: `userid`, `symptomid`, `title`, `deleted`
- **Two-tier pattern**: reference entity (`symptom`) + user entity (`usersymptom`)
- **`[System.Text.Json.Serialization.JsonIgnore]`** (full namespace) marks UI-only properties
- **`ApiResponse{Entity}`** wrapper class at bottom of each file with `ObservableCollection<T> Value` property
- INotifyPropertyChanged on user-entities only (not catalog entities)
- A few newer models use PascalCase (`ChipItem`, `RegistrationRoot`, `MedSuppFeedback`)

### 3.6 Converters
**What:** Newtonsoft.Json `JsonConverter` subclasses that parse embedded JSON strings from the API.
**Examples:** `Helpers/FeedbackConverter.cs`, `Helpers/QuestionnaireQuestionConverter.cs`
**Conventions:**
- Parse API fields where a JSON array is stored as an escaped string
- Use manual string-splitting (not nested `JsonConvert.DeserializeObject`)
- Return `ObservableCollection<T>`; return `null` on error
- `WriteJson` is always passthrough via `JToken.FromObject`
- Located in `Helpers/` directory (not a separate `Converters/` folder)

### 3.7 Custom Controls
**What:** Extended MAUI/Syncfusion controls with added bindable properties.
**Examples:** `Helpers/ExtendedEntry.cs`, `Helpers/ExtendedCheckbox.cs`
**Conventions:**
- `Extended` prefix naming pattern
- Common bindable properties: `IDValue`, `IDRecord`, `questionid` (lowercase)
- All `BindableProperty` declarations use `TwoWay` mode with `string.Empty` default
- Checkboxes/radios/sliders extend Syncfusion base classes; Entry/Label/Editor/Image extend MAUI base
- Located in `Helpers/` directory, flat `PeopleWith` namespace

### 3.8 Services
**What:** Infrastructure services (connectivity, notifications, health data).
**Examples:** `Helpers/ConnectivityService.cs`, `Helpers/MedSuppNotifications.cs`, `Helpers/PWNotificationService.cs`
**Conventions:**
- No DI — instantiated directly where needed (`new MedSuppNotifications()`)
- `CrashDetected` is a universal crash handler instantiated per-page
- Domain-specific notification classes: `MedSuppNotifications`, `ActivityNotifications`, `AppointmentNotifications`
- Push registration via `PWNotificationService` using Azure Notification Hub `Installation` objects

### 3.9 Helpers
**What:** Catch-all directory for base classes, template selectors, utilities, popups.
**Examples:** `Helpers/BaseNotify.cs`, `Helpers/RegistrationTemplateSelector.cs`, `Helpers/logout.cs`
**Conventions:**
- `BaseNotify` provides `SetProperty<T>` (used by registration models only)
- `RegistrationTemplateSelector` maps JSON `Type` field to DataTemplates
- `Logout` class performs account cleanup via constructor action parameter
- All in `Helpers/` with flat `PeopleWith` namespace

### 3.10 XAML Popups
**What:** Modal popup pages using Mopups library.
**Examples:** `Helpers/PopupPageHelper.xaml`, `Helpers/ActivityCalendar.xaml`
**Conventions:**
- Inherit from `Mopups.Pages.PopupPage`
- Scale animation: `DurationIn="200"`, `EasingIn="SinOut"`, `PositionIn="Center"`
- Return values via `TaskCompletionSource<string>` passed in constructor
- Shown with `await MopupService.Instance.PushAsync(new Popup(tcs))`
- Dismissed with `await MopupService.Instance.PopAsync()`
- `PopupPageHelper` is multi-purpose (loading, success, confirmation) via constructor overloads

### 3.11 XAML Pages
**What:** ContentPage XAML definitions for all app screens.
**Examples:** `Views/Symptoms/AddSymptom.xaml`, `Views/Dashboard/MainDashboard.xaml`
**Conventions:**
- `BackgroundColor="White"` and `HideSoftInputOnTapped="True"` on all pages
- Flat namespace: `x:Class="PeopleWith.{PageName}"` (no sub-namespaces)
- Layout: `ScrollView > StackLayout` with `Grid` for content
- Typography: HankenGrotesk font family exclusively (Bold for titles at 26px, Regular for body at 12px)
- Colors are **inline** (not resource keys): `#031926` primary, Orange/Teal/Blue per domain
- `Border` used as card container (not `Frame`)
- Syncfusion xmlns prefixes: `syncfusion:`, `chip:`, `inputLayout:`, `popup:`, `chart:`

### 3.12 Code-Behind
**What:** `.xaml.cs` files containing ALL page logic, state, and event handlers.
**Examples:** `Views/Symptoms/AddSymptom.xaml.cs`, `Views/Dashboard/MainDashboard.xaml.cs`
**Conventions:**
- File-scoped namespace: `namespace PeopleWith;`
- Class-level field declarations (public fields, not properties)
- **Every page** has `CrashDetected crashHandler` + `NotasyncMethod(Exception)` boilerplate
- **Every page** declares `public event EventHandler<bool> ConnectivityChanged;`
- Constructor wraps `InitializeComponent()` in try/catch calling `NotasyncMethod`
- `APICalls` instantiated per-page: `APICalls database = new APICalls();`
- `BindingContext = this;` set in constructor
- Data passed via constructor parameters (collections, models, strings)

### 3.13 Resources — Styles
**What:** XAML resource dictionaries for colors and styles.
**Examples:** `Resources/Styles/Colors.xaml`, `Resources/Styles/Styles.xaml`
**Conventions:**
- Minimal color resources defined (`Primary=#031926`, `Secondary=#DFD8F7`, `Tertiary=#2B0B98`)
- Named styles exist only for registration flow (`RegTitleStyle`, `RegInputLayout`)
- Domain colors are hardcoded inline per feature (not in resource dictionaries)
- `RegistrationTemplates.xaml` resource dictionary for JSON-driven form templates

### 3.14 Resources — Fonts
**What:** Custom font files.
**Conventions:**
- Primary: HankenGrotesk (Bold, Regular, SemiBold, Light)
- Legacy OpenSans registered but unused in views
- Referenced by alias: `FontFamily="HankenGroteskBold"`
- No icon font — PNG images used for all icons

### 3.15 Resources — Images
**What:** PNG/SVG image assets.
**Conventions:**
- All flat in Images directory (no subfolders)
- Lowercase compound names without separators: `searchorange.png`, `dashiconactive.png`
- Referenced by filename only in XAML: `<Image Source="searchorange.png" />`

### 3.16 Resources — Raw
**What:** Embedded raw assets (sounds, animations).
**Conventions:**
- `pwjingo.mp3` — notification sound (Android: `"pwjingo"`, iOS: `"pwjingo.aiff"`)
- `profileswitchsound.mp3` — played via hidden MediaElement
- `success.json` — Lottie animation for success states

### 3.17 JSON Data
**What:** JSON files driving registration/onboarding flows.
**Examples:** `Helpers/NormalWalkthrough.json`, `Views/Test/Registration.json`
**Conventions:**
- `regFields` array with `Type`, `Label`, `Required`, `Order`, `Options`
- `Type` maps to DataTemplate via `RegistrationTemplateSelector`
- Deserialized into `RegistrationRoot` model at runtime
- Located in `Helpers/` or `Views/Test/` (no dedicated data folder)

### 3.18 Log Files
**What:** Committed debug output files (development artifacts).
**Examples:** `crash_report.txt`, `full_dump.txt`, `full_log.txt`
**Conventions:** Snake_case `.txt` files in project root. Not generated at runtime.

---

## 4. Feature Scaffold Guide

### How to determine which files to create

For a new health tracking feature (e.g., "Sleep Tracking"):

1. **Model files** (`Models/`):
   - Catalog entity: `Models/sleep.cs` (lowercase class name, all-lowercase properties)
   - User entity: `Models/usersleep.cs` (with INotifyPropertyChanged)
   - Add `ApiResponseSleep` and `ApiResponseUserSleep` wrapper classes

2. **API endpoints** (`APICalls.cs`):
   - Add static endpoint properties: `public static string usersleep => $"{ApplicationURL}usersleep";`
   - Add GET/POST/PUT/PATCH/DELETE methods following existing patterns

3. **XAML Pages** (`Views/Sleep/`):
   - `AddSleep.xaml` + `AddSleep.xaml.cs` — add/edit form
   - `AllSleep.xaml` + `AllSleep.xaml.cs` — list view
   - `SingleSleep.xaml` + `SingleSleep.xaml.cs` — detail view

4. **Message class** (project root):
   - `UpdateAllSleep.cs` — `ValueChangedMessage<object>` for list refresh

5. **Converter** (if API returns embedded JSON):
   - `Helpers/SleepFeedbackConverter.cs` — `JsonConverter` subclass

6. **Notifications** (if feature has reminders):
   - Add methods to existing notification classes or create `Helpers/SleepNotifications.cs`

### File placement rules

| File Type | Location |
|-----------|----------|
| Models | `Models/` |
| Views (XAML + code-behind) | `Views/{FeatureName}/` |
| Custom controls | `Helpers/` |
| Converters | `Helpers/` |
| Services | `Helpers/` |
| Popups | `Helpers/` |
| Message classes | Project root (`PeopleWith/`) |
| API methods | `APICalls.cs` (single file) |

### Naming conventions

- **Model classes**: all-lowercase (`sleep`, `usersleep`)
- **Page classes**: PascalCase (`AddSleep`, `AllSleep`, `SingleSleep`)
- **Message classes**: PascalCase with action prefix (`UpdateAllSleep`)
- **Custom controls**: `Extended` prefix (`ExtendedSleepSlider`)
- **View folder**: PascalCase singular (`Views/Sleep/`)
- **Properties on models**: all-lowercase (`sleepid`, `userid`, `duration`)

### Example: New "Sleep Tracking" feature files

```
Models/sleep.cs                          ← catalog entity
Models/usersleep.cs                      ← user tracking entity
Views/Sleep/AddSleep.xaml                ← add/edit page XAML
Views/Sleep/AddSleep.xaml.cs             ← code-behind with full boilerplate
Views/Sleep/AllSleep.xaml                ← list page XAML
Views/Sleep/AllSleep.xaml.cs             ← code-behind
Views/Sleep/SingleSleep.xaml             ← detail page XAML
Views/Sleep/SingleSleep.xaml.cs          ← code-behind
UpdateAllSleep.cs                        ← message class (project root)
```

Plus additions to `APICalls.cs` for endpoint methods.

---

## 5. Architectural Domain Rules

### UI Domain
- **Code-behind pattern only** — no ViewModel classes, no MVVM separation
- Every page is a `ContentPage` with paired `.xaml` and `.xaml.cs`
- All state/logic lives in the `.xaml.cs` file with `BindingContext = this`
- Syncfusion controls for rich UI (SfListView, SfChart, SfCalendar, SfProgressBar, SfPopup)
- Custom `Extended*` controls for consistent styling across forms
- Every page has `CrashDetected crashHandler` + `NotasyncMethod(Exception Ex)` boilerplate
- Loading state via `loadingstack`/`LoadInd` with `IsVisible`/`IsRunning` toggle
- `ObservableCollection<T>` for all list bindings

### Navigation Domain
- **Shell on Android, NavigationPage on iOS** — set in `App.CreateWindow()`
- **All navigation is imperative**: `await Navigation.PushAsync(new Page(...), false)`
- Animation parameter always `false`
- Data passed via constructor parameters (collections, models, strings)
- No URI-based routing (`GoToAsync` is NOT used)
- Shell flyout explicitly disabled
- No centralized navigation service
- App-level page replacement: `await App.SetMainPage(new NavigationPage(new MainDashboard(...)))`
- Back button overridden on certain pages (`OnBackButtonPressed()` returns `true`)

### Data Layer Domain
- **All API calls through `APICalls.cs`** — single monolithic class
- Static `HttpClient` with Azure Data API Builder headers
- OData-style URL filtering (`$filter`, `$select`, `eq` operators)
- Newtonsoft.Json for API deserialization into `ApiResponse{Entity}` wrappers
- `Helpers.Settings` static class wraps `Preferences` for all local key-value storage
- Azure Blob Storage for image uploads (symptom photos)
- No repository pattern, no offline sync, no caching layer for API data
- Dual JSON serializers: Newtonsoft for API, System.Text.Json for some local operations

### Messaging Domain
- **CommunityToolkit.Mvvm.Messaging** with `WeakReferenceMessenger.Default`
- Messages registered in page constructors or init methods
- `WeakReferenceMessenger.Default.Register<T>(this, (r, m) => { ... })`
- `WeakReferenceMessenger.Default.Send(new MessageType(payload))`
- Two patterns coexist: `ValueChangedMessage<T>` subclasses AND plain POCO messages
- Legacy `MessagingCenter` also exists in older code

### Authentication Domain
- Email + password login (MD5 hashed via `PasswordEncryption` class)
- Biometric (fingerprint/face) via Plugin.Fingerprint + Plugin.Maui.Biometric
- PIN code fallback stored in Preferences
- Session persisted entirely in Preferences (userid, email, pincode, biometrics flag)
- No OAuth/OIDC, no JWT tokens, no refresh mechanism
- API auth via static `X-MS-CLIENT-PRINCIPAL` header (not per-user tokens)
- Multi-profile via `PrimaryUserID` preference for carer access

### Notifications Domain
- **Local**: Plugin.LocalNotification with `NotificationRequest` + `NotificationRequestSchedule`
- **Push**: Firebase Cloud Messaging (Android) + Azure Notification Hubs
- Notification IDs are integers managed manually
- Custom sound: `"pwjingo"` (Android) / `"pwjingo.aiff"` (iOS)
- Android channel: `"PeopleWithLocalNotifications"`
- Separate classes per domain: `MedSuppNotifications`, `ActivityNotifications`, `AppointmentNotifications`

### Health Tracking Domain
- Symptoms: severity slider (0–10), body map, episodes, image capture
- Medications/Supplements: dosage schedules, frequency, daily feedback
- Measurements: configurable units, historical visualization
- Mood, Diet, Exercise, Daily Activities: simple record + feedback
- Fitness integration: HealthKit/Google Fit via `Plugin.Maui.Health`
- `userfeedback` model aggregates all daily feedback as serialized JSON strings
- User-prefixed models (`usersymptom`, `usermedication`, etc.) for tracking data
- Each entity type has dedicated API endpoints

### Medical Coding Domain
- SNOMED CT stored as `SNOWMED` property (consistent typo — do not "fix")
- ICD-10, BNF codes, DMD product descriptions on medications
- All codes are simple string properties — no validation, no lookup
- Codes assigned server-side; client displays only

### Questionnaire Domain
- JSON-driven question-answer flows with custom `JsonConverter` deserialization
- `questionanswerinfo` model defines question types, order, required flag, answers
- Targeted by signup code, medication, symptom, gender, age
- Platform-specific rendering pages (Android-specific questionnaire pages exist)
- Completion tracked via `userquestionnaire` with `completedatetime`

### Carer Support Domain
- `usercaregroup` model with nested `usercaredetails` collection (stored as JSON string)
- Status workflow: pending → approved → deleted
- Profile switching via `TaskCompletionSource<user>` pattern
- `PrimaryUserID` in Preferences distinguishes main account from carer-viewed profiles
- Profile colors assigned from `Genericlist.ProfileColors`

### Data Binding Domain
- `INotifyPropertyChanged` implemented directly on user-entity models
- `BaseNotify` abstract class with `SetProperty<T>` (used by registration models only)
- `ObservableCollection<T>` universally for list data sources
- No CommunityToolkit.Mvvm source generators (`[ObservableProperty]`, `[RelayCommand]` NOT used)
- Mixed approaches: some models use `BaseNotify`, most implement INPC inline

---

## 6. Integration Rules

These are **hard constraints** that prevent AI from generating non-compliant code:

1. **NO ViewModels** — Never create a separate ViewModel class. All logic goes in `.xaml.cs` code-behind.
2. **NO DI for API calls** — Always instantiate `APICalls` directly: `APICalls database = new APICalls();`
3. **NO URI routing** — Never use `Shell.GoToAsync()`. Always use `Navigation.PushAsync(new Page(...), false)`.
4. **NO resource key colors** — Use inline hex colors in XAML (e.g., `TextColor="#031926"`), not `{StaticResource}` references for domain colors.
5. **ALL model classes lowercase** — `public class sleeptracking`, not `public class SleepTracking`.
6. **ALL model properties lowercase** — `public string userid { get; set; }`, not `UserId`.
7. **ALWAYS include crash boilerplate** — Every new page must have `CrashDetected crashHandler` and `NotasyncMethod(Exception Ex)`.
8. **ALWAYS include ConnectivityChanged event** — `public event EventHandler<bool> ConnectivityChanged;` on every page.
9. **ALWAYS wrap constructor in try/catch** — Constructor catches Exception and calls `NotasyncMethod(Ex)`.
10. **NEVER use `[ObservableProperty]` or `[RelayCommand]`** — The project does not use source generators despite the package reference.
11. **ALWAYS use `[System.Text.Json.Serialization.JsonIgnore]`** (full namespace) for UI-only properties on models.
12. **ALWAYS add `ApiResponse{Entity}`** wrapper class with `ObservableCollection<T> Value` property.
13. **Navigation animation always disabled** — Second parameter of `PushAsync` is always `false`.
14. **Font is HankenGrotesk only** — Never reference OpenSans or other fonts in views.
15. **SNOMED property is `SNOWMED`** — Preserve the existing typo; do not rename.
16. **Message classes in project root** — Not in a `Messages/` subfolder.
17. **Popups use Mopups** — Not Syncfusion popup or MAUI Community Toolkit popup for modal popups.
18. **TaskCompletionSource for popup returns** — Popups return values via TCS passed in constructor.
19. **Platform conditionals** — Use `#if ANDROID` / `#if IOS` for platform-specific code, `DeviceInfo.Platform` for runtime checks.
20. **No sub-namespaces** — Everything is `namespace PeopleWith;` (file-scoped).

---

## 7. Example Prompt Usage

### User prompt:
> "Add a new Sleep Tracking feature where users can log sleep duration, quality (1-5 scale), and notes. Show all entries in a list and allow viewing individual records."

### Expected AI output:

**1. Model: `Models/sleep.cs`**
```csharp
namespace PeopleWith;

public class sleep
{
    public string sleepid { get; set; }
    public string title { get; set; }
    public string description { get; set; }
    public bool deleted { get; set; }
    public string userid { get; set; }
}

public class ApiResponseSleep
{
    public ObservableCollection<sleep> Value { get; set; }
}
```

**2. Model: `Models/usersleep.cs`**
```csharp
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace PeopleWith;

public class usersleep : INotifyPropertyChanged
{
    public string usersleepid { get; set; }
    public string userid { get; set; }
    public bool deleted { get; set; }
    public string duration { get; set; }
    public string quality { get; set; }
    public string notes { get; set; }
    public string date { get; set; }

    [System.Text.Json.Serialization.JsonIgnore]
    public string DisplayDate { get; set; }

    [System.Text.Json.Serialization.JsonIgnore]
    public Color QualityColour { get; set; }

    public event PropertyChangedEventHandler PropertyChanged;
    protected void OnPropertyChanged([CallerMemberName] string propertyName = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}

public class ApiResponseUserSleep
{
    public ObservableCollection<usersleep> Value { get; set; }
}
```

**3. Message: `UpdateAllSleep.cs`** (project root)
```csharp
using CommunityToolkit.Mvvm.Messaging.Messages;

namespace PeopleWith;

public class UpdateAllSleep : ValueChangedMessage<object>
{
    public UpdateAllSleep(object value) : base(value) { }
}
```

**4. Code-behind: `Views/Sleep/AllSleep.xaml.cs`** (structure)
```csharp
namespace PeopleWith;

public partial class AllSleep : ContentPage
{
    ObservableCollection<usersleep> AllUserSleep = new ObservableCollection<usersleep>();
    APICalls database = new APICalls();
    CrashDetected crashHandler = new CrashDetected();

    public event EventHandler<bool> ConnectivityChanged;

    async public void NotasyncMethod(Exception Ex)
    {
        try
        {
            await crashHandler.SentryCrashDetected(Ex);
            await Navigation.PushAsync(new ErrorPage("Sleep", Ex), false);
        }
        catch (Exception ex) { }
    }

    public AllSleep(userfeedback userfeedbacklist)
    {
        try
        {
            InitializeComponent();
            BindingContext = this;
            GetUserSleep();
        }
        catch (Exception Ex)
        {
            NotasyncMethod(Ex);
        }
    }

    private async void GetUserSleep()
    {
        // Load data from API via APICalls
    }

    private async void AddSleep_Clicked(object sender, EventArgs e)
    {
        await Navigation.PushAsync(new AddSleep(AllUserSleep), false);
    }
}
```

**5. API additions in `APICalls.cs`:**
```csharp
public static string usersleep => $"{ApplicationURL}usersleep";

public async Task<ObservableCollection<usersleep>> GetUserSleep()
{
    try
    {
        var USERID = Helpers.Settings.UserKey;
        var url = $"{usersleep}?$filter=userid%20eq%20'{USERID}'%20and%20deleted%20eq%20false";
        var configuredClient = GetClient();
        HttpResponseMessage response = await configuredClient.GetAsync(url);

        if (response.IsSuccessStatusCode)
        {
            string content = await response.Content.ReadAsStringAsync();
            var parsed = JsonConvert.DeserializeObject<ApiResponseUserSleep>(content);
            return parsed.Value;
        }
        return null;
    }
    catch (Exception ex)
    {
        await crashHandler.SentryCrashDetected(ex);
        return null;
    }
}
```

---

## Domain Color Reference

When creating UI for a specific feature domain, use these inline colors:

| Domain | Background | Accent Color |
|--------|-----------|-------------|
| Symptoms | `#fff7ea` | Orange |
| Medications | `#e5f9f4` | Teal |
| Supplements | `#f9f4e5` | Gold/Amber |
| Measurements | `#e5f0fb` | Blue |
| Diagnosis | `#E6E6FA` | Lavender |
| Mood | `#FFF8DC` | Cornsilk |
| Questionnaires | `#fff9ec` | Warm cream |
| Profile/Care | `#CCEBF9` | Sky blue |
| Primary text | — | `#031926` |
| Secondary text | — | Gray / DarkGray |
| Borders | — | `#dedede` |
