# Bail Onus Finder

A questionnaire that determines whether bail is **Crown onus** or **reverse onus**
(rules as of July 18, 2026). If reverse onus, it produces the list of triggering
Criminal Code section numbers to copy.

Two front-ends share **one rule file**, `OnusRules.txt`:

- **`onus_app.py`** – Streamlit web app.
- **`BailOnusFinder.ahk`** – AutoHotkey v2 desktop wizard (Windows).

## Editing the rules

Open **`OnusRules.txt`** in any text editor. No programming needed.

```
[ALWAYS]
524(4)       | A s.524 application has been granted
...
[INDICTABLE]
515(6)(b)    | Accused not ordinarily resident in Canada
...
```

- `section number | description` — text before `|` is what gets copied; text
  after `|` is the checkbox label shown to the user.
- `[ALWAYS]` conditions trigger reverse onus regardless of classification.
- `[INDICTABLE]` conditions apply only where the offence is straight indictable,
  or hybrid and the Crown has **not** elected summarily.
- Lines starting with `;` are comments. Rule order is preserved.

## Running the Streamlit app

```powershell
uv run streamlit run onus_app.py
```

This launches a local server and opens the app in your browser.

## Running the AutoHotkey wizard

Double-click **`BailOnusFinder.ahk`** (requires AutoHotkey v2). `OnusRules.txt`
must be in the same folder.

## Determination logic

1. **Youth** matter → always Crown onus (YCJA).
2. Otherwise start from Crown onus; any ticked `[ALWAYS]` condition makes it reverse onus.
3. If the offence is straight indictable / hybrid-not-summary, any ticked
   `[INDICTABLE]` condition also makes it reverse onus.
4. Reverse onus → the distinct section numbers (in file order) are the reasons.

> Note: `rules.md` wrote `525(6)(c)` for the s.145(2)–(5) item; there is no
> s.525(6)(c). The correct provision, `515(6)(c)`, is used in `OnusRules.txt`.
