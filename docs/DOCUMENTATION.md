# Focus24 — Project Documentation

A full-featured task-management mobile application built with **Flutter + Firebase**.

**GitHub Repository:** https://github.com/MaiSoklyna/ToDoListAppV01

---

## Team Members & Roles

The work is divided into six areas that map directly to the app's modules, so every member owns a clear part of the codebase and the collaboration is easy to demonstrate.

| # | Member | Role | Key Responsibilities |
|---|--------|------|----------------------|
| 1 | Mai Soklyna | Team Lead & Backend (Firebase) | Project coordination and GitHub/branch management; Firebase setup; Cloud Firestore data models and `firestore.rules`; offline cache & sync (Hive, connectivity_plus). |
| 2 | Young Soklong | Authentication & User Profile | Email/password sign-up, sign-in and password reset; biometric app lock; user profile; onboarding & splash screens. |
| 3 | Roeun Monorom | Core Task Management | Task create/edit/complete/delete; subtasks; recurring tasks; reminders and local notifications; projects, labels & categories. |
| 4 | Po Ratana | Collaboration / Shared Lists | Shared lists; invite/share codes; roles & permissions; task assignment; comments; activity feed. |
| 5 | Rin Monyroth | Productivity & Analytics | Calendar view; Kanban board; Pomodoro timer; statistics dashboard, charts & completion streaks; search. |
| 6 | Nuv Singju | UI/UX, Localization & QA | App theme/design system; English & Khmer localization; notes feature; PDF export & share; help/settings; testing & documentation. |

> Members are matched to areas as a sensible starting point — adjust them to reflect who actually built what before you submit.

---

## 1. Problem Statement

People juggle many responsibilities — study deadlines, work tasks, personal errands, and group projects — across different tools and notebooks. This makes it easy to **forget deadlines, lose track of priorities, and fail to coordinate shared work** with teammates.

**Focus24** solves this by providing a single, organized place to capture, schedule, prioritize, and track tasks. It adds reminders so nothing is forgotten, shared lists so groups can collaborate in real time, and works **offline** so users can keep working without an internet connection and have their changes synced automatically once they reconnect.

---

## 2. Features List

**Account & Security**
- Email/password sign-up, sign-in, and password reset (Firebase Authentication)
- Editable user profile (display name, avatar)
- Biometric app lock (fingerprint / face) using device authentication

**Task Management**
- Create, edit, complete, and delete tasks
- Task details: description, due date, priority (Low/Medium/High), color, emoji, estimated time, and a completion note
- Subtasks (checklists within a task)
- Recurring tasks (daily/weekly/monthly recurrence rules)
- Categories, custom labels, and projects for organization
- Multiple reminders per task with local push notifications

**Views & Productivity**
- Home / task list with filtering
- Calendar view (see tasks by date)
- Kanban board (drag tasks across columns)
- Search across tasks and notes
- Notes (separate quick-note feature)
- Pomodoro focus timer
- Statistics dashboard with charts and a completion streak (gamified with confetti)

**Collaboration (Shared Lists)**
- Create shared lists and invite members via a share code
- Role-based permissions (owner / editor / member)
- Assign tasks to specific members
- Comment on shared tasks
- Immutable activity feed (audit log) of who did what

**Platform & Experience**
- Offline-first: works without internet; changes queue and auto-sync on reconnect
- Multi-language support (English & Khmer) with localized fonts
- Light/dark theming
- Export tasks to PDF and share them
- Onboarding flow and in-app help screen

---

## 3. User Stories

*Format: As a [user], I want to [do something] so that [reason].*

**Authentication**
- As a user, I want to register with my email and password so that I can have my own private account.
- As a user, I want to reset my password so that I can regain access if I forget it.
- As a user, I want to lock the app with my fingerprint so that my tasks stay private.

**Task Management**
- As a user, I want to add a task with a title and due date so that I remember what to do and when.
- As a user, I want to set a priority on a task so that I focus on the most important work first.
- As a user, I want to break a task into subtasks so that I can track progress on larger work.
- As a user, I want to set a task to repeat daily/weekly so that I don't have to recreate routine tasks.
- As a user, I want to receive a reminder notification so that I don't miss a deadline.
- As a user, I want to organize tasks into projects, categories, and labels so that I can find them easily.

**Views & Productivity**
- As a user, I want to see my tasks on a calendar so that I can plan my week visually.
- As a user, I want to move tasks across a Kanban board so that I can see what is to-do, in-progress, and done.
- As a user, I want to search my tasks and notes so that I can quickly find a specific item.
- As a user, I want to use a Pomodoro timer so that I can focus in timed work sessions.
- As a user, I want to view statistics and a completion streak so that I stay motivated.

**Collaboration**
- As a team member, I want to create a shared list and invite others so that we can work together.
- As a list owner, I want to control who can edit so that only trusted members change tasks.
- As a team member, I want to assign a task to a teammate so that responsibilities are clear.
- As a team member, I want to comment on a task so that we can discuss it in context.
- As a team member, I want to see an activity feed so that I know what changed and who changed it.

**Platform**
- As a user, I want to add and edit tasks offline so that I can work without an internet connection.
- As a user, I want my offline changes to sync automatically so that my data is consistent across devices.
- As a user, I want to use the app in Khmer or English so that I can use my preferred language.
- As a user, I want to export my tasks to PDF so that I can save or share a record of them.

---

## 4. Backend Integration

The application is connected to **Firebase** as its backend.

### Services used
- **Firebase Authentication** — email/password accounts, registration, sign-in, and password-reset emails.
- **Cloud Firestore** — the primary cloud database storing all user data in real time.

### Firestore data model (collections)
| Collection | Purpose |
|-----------|---------|
| `users` | User profiles (display name, email, avatar) |
| `tasks` | All tasks (personal and shared); includes a `comments` subcollection |
| `sharedLists` | Shared lists with `memberIds` and `roles`; includes an immutable `activity` subcollection |
| `invites` | Share-code lookup table to join shared lists |
| `projects` | Personal projects for grouping tasks |
| `categories` | Personal task categories |
| `labels` | Personal labels |
| `notes` | Personal notes |

### Security rules
Access is enforced server-side with Firestore Security Rules (`firestore.rules`):
- Personal data (`projects`, `categories`, `labels`, `notes`) is readable/writable only by its owner (`userId == request.auth.uid`).
- Shared tasks are accessible to list members; only **owner/editor** roles can edit.
- The shared-list `activity` feed is **append-only and immutable** (a true audit log).
- Invite codes can be resolved by any authenticated user but only created/revoked by the list owner.

### Offline support & sync
- **Hive** local database caches data and stores a **pending-operations queue** when the device is offline.
- **connectivity_plus** detects when the connection is restored and triggers an automatic sync of queued changes to Firestore.

### Notifications
- **flutter_local_notifications** + **timezone** schedule task reminders as local device notifications.

### Technology stack (summary)
| Layer | Technology |
|-------|-----------|
| Language / SDK | Dart, Flutter 3.10+ |
| Architecture | MVVM (Models / Services / ViewModels / Views) |
| State management | Provider |
| Routing | go_router |
| Backend | Firebase Auth, Cloud Firestore |
| Local storage / offline | Hive, connectivity_plus |
| Notifications | flutter_local_notifications, timezone |
| UI / charts | Material Design, fl_chart, table_calendar, confetti |
| Security | local_auth (biometrics) |
| Export | pdf, path_provider, share_plus |
| Localization | flutter_localizations, intl, google_fonts (Battambang/Nokora for Khmer) |

---

## 5. GitHub Repository

**Repository:** https://github.com/MaiSoklyna/ToDoListAppV01
**Owner:** MaiSoklyna

### Branching strategy
The project uses a **main / dev + feature-branch** workflow:

- **`main`** — stable, production-ready code. Only reviewed, working code is merged here.
- **`dev`** — integration branch where completed features are combined and tested together before release.
- **`feature/<name>`** — one branch per feature (e.g. `feature/shared-lists`, `feature/pomodoro-timer`). Branched from `dev`, merged back via Pull Request.
- **`fix/<name>`** — branches for bug fixes.

**Workflow:** `feature/*` -> Pull Request -> review -> merge into `dev` -> test integration -> merge into `main` for release.

```
main ------------o-------------------o----------  (stable releases)
                  \                  /
dev --------o----o----o------o----------------    (integration)
             \    \    \
feature/...   o    o    o                          (one branch per feature)
```

### Commit message convention
Commits follow a clear, meaningful style (Conventional Commits):
- `feat: add recurring task support`
- `fix: correct reminder timezone offset`
- `docs: add project documentation`
- `refactor: extract task service`
- `style: update task card spacing`

Each message explains **what** changed and **why**, so the history is easy to follow.

---

## Getting Started (Run the app)

```
# 1. Install dependencies
flutter pub get

# 2. Make sure a Firebase project is configured (firebase_options.dart is included)

# 3. Run on a connected device or emulator
flutter run
```

Requirements: Flutter SDK 3.10+, an Android/iOS device or emulator, and internet access for the first login (offline mode works afterward).
