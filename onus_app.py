"""
Bail Onus Finder - Streamlit app.

A questionnaire that determines whether bail is CROWN ONUS or REVERSE ONUS.
If reverse onus, the triggering section numbers (only) are shown in a copyable
box (click the copy icon in its top-right corner).

Reads the same editable rule file as the AutoHotkey version:  OnusRules.txt
(kept in the same folder as this script). Edit that file to change the
questionnaire - no code changes needed.

Run with:   streamlit run onus_app.py
"""

from pathlib import Path

import streamlit as st

CONFIG_PATH = Path(__file__).parent / "OnusRules.txt"


def load_rules(path: Path):
    """Parse OnusRules.txt into two ordered lists of (description, section).

    Mirrors the AutoHotkey loader:
      [ALWAYS]      -> group A (apply regardless of classification)
      [INDICTABLE]  -> group B (indictable / hybrid-not-summary track only)
      "section | description" per line; ';' lines are comments.
    """
    group_a, group_b = [], []
    target = None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            name = line[1:-1].strip().upper()
            target = {"ALWAYS": "A", "INDICTABLE": "B"}.get(name)
            continue
        if "|" not in line or target is None:
            continue
        section, _, desc = line.partition("|")
        section, desc = section.strip(), desc.strip()
        if not section or not desc:
            continue
        (group_a if target == "A" else group_b).append((desc, section))
    return group_a, group_b


def dedupe(seq):
    """Return items in order, dropping later duplicates."""
    seen, out = set(), []
    for item in seq:
        if item not in seen:
            seen.add(item)
            out.append(item)
    return out


st.set_page_config(page_title="Bail Onus Finder", page_icon="⚖️")
st.title("⚖️ Bail Onus Finder")
st.caption("Rules as of July 18, 2026. Determination is only as good as OnusRules.txt.")

if not CONFIG_PATH.exists():
    st.error(f"Configuration file not found:\n\n{CONFIG_PATH}\n\n"
             "OnusRules.txt must sit in the same folder as this script.")
    st.stop()

group_a, group_b = load_rules(CONFIG_PATH)
if not group_a and not group_b:
    st.error("No rules were loaded. Check that OnusRules.txt contains "
             "[ALWAYS] / [INDICTABLE] sections with 'section | description' lines.")
    st.stop()

# --- Step 1: Youth vs Adult --------------------------------------------------
matter = st.radio(
    "Is this a youth matter or an adult matter?",
    ["Adult", "Youth (YCJA)"],
    index=0,
)

if matter.startswith("Youth"):
    st.divider()
    st.subheader("Result: CROWN ONUS")
    st.write("Onus for youth matters is always Crown Onus (YCJA).")
    st.stop()

# --- Step 2: Checklist A (applies regardless of classification) --------------
st.divider()
st.subheader("Do any of these apply?")
st.caption("These trigger reverse onus regardless of offence classification.")
picked = []
for i, (desc, section) in enumerate(group_a):
    if st.checkbox(desc, key=f"a{i}"):
        picked.append((desc, section))

# --- Step 3: Indictable gate -------------------------------------------------
st.divider()
st.subheader("Offence classification")
indictable = st.radio(
    "Is the offence a straight indictable offence, OR a hybrid offence for "
    "which the Crown has NOT elected to proceed summarily?",
    ["No", "Yes"],
    index=0,
)

# --- Step 4: Checklist B (only on the indictable / not-summary track) --------
if indictable == "Yes":
    st.divider()
    st.subheader("Do any of these apply?")
    st.caption("Straight indictable / hybrid-not-summary track only.")
    for i, (desc, section) in enumerate(group_b):
        if st.checkbox(desc, key=f"b{i}"):
            picked.append((desc, section))

# --- Result ------------------------------------------------------------------
st.divider()
if not picked:
    st.subheader("Result: CROWN ONUS")
    st.write("None of the reverse-onus conditions apply.")
else:
    sections = dedupe(section for _desc, section in picked)
    st.subheader("Result: REVERSE ONUS")
    st.write("**Section numbers** (click the copy icon to copy):")
    st.code(", ".join(sections), language=None)
    st.write("**Reasons:**")
    for desc, section in picked:
        st.markdown(f"- {desc} → **{section}**")
