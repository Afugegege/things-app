# things

a minimalist personal organizer and life os built with flutter. 

designed for people who care about how their tools look and feel — dark mode, frosted glass surfaces, modular widgets, and zero visual clutter.

---

### why

most productivity apps are either bloated databases or look like they were built in 2012. 

things is a single space for daily focus: quick capture notes, gesture-driven task lists, customizable dashboard widgets, and a clean spending tracker that keeps finances grounded.

### what's inside

- **dashboard & widget studio**: modular layout for quick glance metrics, habits, counters, and personal widgets.
- **notes & brain dumps**: fast writing surface with markdown formatting and rich editing.
- **tasks & gestures**: fluid swipe actions, priorities, and clean lists without the friction.
- **money tracker**: spending groups, account balances, and simple category budgets.
- **smart actions**: lightweight assistant integration for quick summaries and actions.

### stack

- **framework**: flutter (dart)
- **state**: provider
- **backend**: supabase
- **charts & ui**: fl_chart, flutter_staggered_grid_view

### run locally

prerequisites: flutter sdk (3.2.0+) and dart.

1. clone the repo:
```bash
git clone https://github.com/Afugegege/things-app.git
cd things-app
```

2. install dependencies:
```bash
flutter pub get
```

3. configure environment variables:
create a `.env` file in the root directory:
```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

4. launch:
```bash
flutter run
```

---

license: mit
