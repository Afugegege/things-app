# things

a personal workspace for daily focus — notes, tasks, widgets, and spending.

built with flutter because i wanted an app that looks quiet, feels fast, and doesn't get in the way. dark mode, subtle glass surfaces, and just what i actually use every day.

![Things app interface](flutter_01.png)

---

### overview

- **notes**: quick capture with rich text and markdown support
- **tasks**: swipe gestures, simple priorities, zero friction
- **dashboard**: modular widgets for habits, counters, and daily overview
- **money**: lightweight expense tracker, accounts, and category budgets
- **actions**: small automated helpers for quick summaries

### stack

- flutter & dart
- provider for state
- supabase for sync and storage
- fl_chart for visualizations

### setup

prerequisites: flutter 3.2.0+

1. clone the repo
```bash
git clone https://github.com/Afugegege/things-app.git
cd things-app
```

2. get dependencies
```bash
flutter pub get
```

3. env config
create a `.env` file in the project root:
```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_key
```

4. run
```bash
flutter run
```

### status

an active personal project. it currently has no hosted demo or release build.

---

license: mit
