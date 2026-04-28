# Focus24 — Final Presentation & Demo (Slide Outline)

Use this as the script for your slide deck (PowerPoint / Google Slides / Canva). Each `## Slide` is one slide; bullets are the on-slide content and *Speaker notes* tell you what to say or show. Covers every rubric item: problem statement, features, technology stack, UI design, feature walkthrough, backend demo, and GitHub collaboration.

---

## Slide 1 — Title

- **Focus24** — Smart Task Management, Built with Flutter & Firebase
- Team members: Mai Soklyna, Young Soklong, Roeun Monorom, Po Ratana, Rin Monyroth, Nuv Singju
- GitHub: github.com/MaiSoklyna/ToDoListAppV01

*Speaker notes:* Introduce the team and one-line pitch.

---

## Slide 2 — Problem Statement

- People manage study, work, and personal tasks across scattered tools
- Easy to forget deadlines and lose track of priorities
- Hard to coordinate shared/group tasks
- Many apps don't work offline

*Speaker notes:* Explain the real pain point your app addresses.

---

## Slide 3 — Our Solution

- One organized app to capture, schedule, prioritize, and track tasks
- Reminders so nothing is forgotten
- Shared lists for real-time team collaboration
- Works offline and syncs automatically

*Speaker notes:* Bridge from the problem to Focus24.

---

## Slide 4 — Key Features

- Tasks: due dates, priority, subtasks, recurring, reminders, labels/projects
- Views: Calendar, Kanban board, Search, Notes
- Productivity: Pomodoro timer, statistics dashboard, completion streaks
- Collaboration: shared lists, roles, task assignment, comments, activity feed
- Offline-first, biometric lock, PDF export, English/Khmer

*Speaker notes:* Don't read every bullet — highlight the 3–4 most impressive.

---

## Slide 5 — Technology Stack

- **Frontend:** Flutter (Dart), Material Design
- **Architecture:** MVVM + Provider, go_router navigation
- **Backend:** Firebase Authentication + Cloud Firestore
- **Offline:** Hive local DB + connectivity_plus auto-sync
- **Extras:** local notifications, fl_chart, local_auth (biometrics), pdf export

*Speaker notes:* Mention why Flutter (one codebase, Android + iOS) and Firebase (managed, real-time, scales).

---

## Slide 6 — Architecture Overview

- **Views** (screens/widgets) -> **ViewModels** (Provider state) -> **Services** (Firebase/Hive) -> **Models** (data classes)
- Clean separation of UI, logic, and data
- Offline cache layer sits between services and Firestore

*Speaker notes:* Show a simple boxes-and-arrows diagram of the MVVM layers.

---

## Slide 7 — UI Design

- Show screenshots: Onboarding -> Login -> Home -> Add Task -> Calendar -> Kanban -> Statistics -> Shared List
- Consistent theme, light/dark mode
- Khmer + English localization

*Speaker notes:* Walk through the visual design and navigation flow.
**Action item:** paste 4–6 real screenshots from the running app here.

---

## Slide 8 — Backend & Data Model

- Firestore collections: `users`, `tasks` (+ `comments`), `sharedLists` (+ `activity`), `invites`, `projects`, `categories`, `labels`, `notes`
- Real-time sync between app and cloud
- Authentication via Firebase Auth (email/password + reset)

*Speaker notes:* Open the Firebase console to show live data updating.

---

## Slide 9 — Security & Permissions

- Firestore Security Rules enforce access server-side
- Personal data readable only by its owner
- Shared tasks: owner/editor can edit, members can view
- Activity feed is append-only (tamper-proof audit log)

*Speaker notes:* This demonstrates real backend integration, not just storage.

---

## Slide 10 — Offline & Sync (Demo highlight)

- Turn airplane mode ON -> add/edit a task -> it still works
- Turn connection back ON -> changes sync to Firestore automatically

*Speaker notes:* This is a strong live-demo moment — rehearse it.

---

## Slide 11 — Collaboration Demo (Shared Lists)

- Create a shared list -> generate invite code
- Second account joins -> assign a task -> add a comment
- Show the activity feed updating in real time

*Speaker notes:* If possible, use two devices/emulators side by side.

---

## Slide 12 — GitHub Collaboration

- Repo: github.com/MaiSoklyna/ToDoListAppV01
- Branching: `main` (stable) <- `dev` (integration) <- `feature/*` branches
- Pull Requests for review before merging
- Meaningful commit messages (feat / fix / docs / refactor)

*Speaker notes:* Open GitHub and show the branch list, a PR, and the commit history.

---

## Slide 13 — Live Demo Walkthrough

1. Sign in
2. Create a task with due date, priority, reminder, subtasks
3. Show Calendar + Kanban views
4. Trigger a reminder notification
5. Show statistics / streak
6. Collaboration + offline sync (Slides 10–11)

*Speaker notes:* Keep the demo to ~3–4 minutes. Have a backup video in case of WiFi issues.

---

## Slide 14 — Challenges & Learnings

- Offline-first sync and conflict handling
- Designing Firestore security rules for shared data
- Coordinating teamwork with Git branches

*Speaker notes:* Be honest — graders appreciate reflection.

---

## Slide 15 — Thank You / Q&A

- Thank you!
- GitHub: github.com/MaiSoklyna/ToDoListAppV01
- Questions?

*Speaker notes:* Invite questions; have the app running and ready.
