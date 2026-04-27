# NeuroLit AI

NeuroLit AI is a Windows desktop application for literature search, article selection, AI-assisted review writing, layman explanation generation, and PPT support.

It supports two parallel workflows:

- Medical mode
- Engineering mode

The app is designed for clinicians, researchers, teachers, and advanced learners who want to collect literature, review abstracts, save collections, generate professional summaries, create teaching material, and organize outputs locally on their own computer.

## What NeuroLit AI Does

NeuroLit AI helps you:

- search literature
- read abstracts
- identify free full text or downloadable PDF links where available
- save selected articles into collections
- generate AI summaries from selected literature
- generate teaching synopsis content
- produce layman-friendly explanations
- save session outputs to local folders
- generate slide/PPT support files
- track token usage across supported AI providers

## Supported Modes

### Medical Mode

Medical mode uses the existing medical literature workflow and is intended for PubMed-style searches and article review.

### Engineering Mode

Engineering mode provides a parallel literature workflow intended for engineering and technical literature. It keeps its saved content separate from Medical mode.

## Installation

### Recommended installation

1. Download `NeuroLit_Setup.exe` from the GitHub Release page.
2. Double-click the installer.
3. Accept the default install location unless you have a reason to change it.
4. Allow the installer to create:
   - a Desktop shortcut
   - a Start Menu entry
5. Launch NeuroLit AI from the shortcut after installation completes.

### Upgrade installation

If you are upgrading from an older version:

1. Close NeuroLit AI completely before running the new installer.
2. Wait a few seconds so the hidden engineering backend also closes.
3. Run the new installer.

Version `v1.1.1` improves upgrade safety by asking Windows to close the main app process and the bundled engineering backend before files are replaced.

## First Launch Setup

On first launch:

1. Open `Settings`.
2. Review the `NeuroLit Data Folder`.
3. Add at least one AI provider profile if you want AI summarization.

## AI Provider / API Key Setup

Open `Settings` and use the `AI Providers` section.

You can:

- add a provider
- choose OpenAI, Gemini, or Sarvam
- enter the API key
- choose the model
- test the connection
- set a provider as active

The app stores provider metadata locally and stores provider secrets locally on the machine.

## Where Files Are Saved

By default, NeuroLit AI stores local working files under:

`Documents\NeuroLit`

From `v1.1.1` onward, you can override this root folder in `Settings`.

### Data folder behavior

- If no custom folder is selected, the default remains `Documents\NeuroLit`
- If `Documents` is redirected to OneDrive or Dropbox, the app will follow that Windows location unless you choose another folder
- If you choose a custom folder, all future NeuroLit storage uses that folder

## NeuroLit Data Folder Setting

In `Settings`, there is now a `NeuroLit Data Folder` section.

It shows:

- the active folder path
- the default folder path

Buttons:

- `Choose Folder`
- `Open Folder`
- `Reset to Default`

Use this if:

- your Documents folder is redirected to OneDrive
- your hospital or university machine uses a managed Documents location
- you want all NeuroLit outputs stored somewhere else

## Folder Structure

NeuroLit AI separates Medical and Engineering outputs.

Typical structure:

```text
NeuroLit
├── Medical
│   ├── Collections
│   ├── Exports
│   └── FullText
└── Engineering
    ├── Collections
    ├── Exports
    └── FullText
```

Within each mode, topic/date folders may contain:

- `summaries`
- `PPTx`
- `fulltext`

Other app-level files may also be stored in the NeuroLit root, such as token usage data and provider secret metadata files.

## Medical Mode Guide

### How to search

1. Switch to `Medical`.
2. Enter a query in the search box.
3. Press Enter or click Search.

### How to filter

Use the left panel to adjust:

- date filter
- text availability
- article type
- expansion behavior

### How to select articles

Tick the checkboxes beside the articles you want.

### How to view abstracts

Click an article entry to open the abstract/details modal.

### How to save abstracts or session text

The app writes session-related files into the NeuroLit data folder under the mode-specific structure.

### How to generate AI reviews

1. Select at least one article.
2. Open the `Professional Output` tab.
3. Click `Generate AI Summary`.

### How to generate teaching synopsis

Change the output mode if needed, then generate the AI output from selected articles.

### How to generate slides / PPT

1. Generate a review first.
2. Click `Generate Slides`.
3. Use the resulting folder or PPT tools as provided in the app.

### How to use Layman mode

1. Open the `Layman Output` tab.
2. Select the layman mode you want.
3. Generate the output.

## Engineering Mode Guide

Engineering mode uses the parallel engineering literature pipeline and keeps its outputs separate from Medical mode.

### What it does

It lets you:

- search engineering literature
- review abstracts
- identify full-text/PDF links where available
- save engineering collections
- generate engineering-focused summaries using the same AI pipeline

### How it differs from Medical mode

- the literature source pipeline is different
- outputs are stored under `Engineering`
- engineering collections are separate from medical collections
- the search wording and source indicators differ

### How to use it

1. Switch to `Engineering`.
2. Search for engineering literature.
3. Select articles.
4. Use `Professional Output` or `Layman Output`.

## Collections

Collections are stored separately by mode.

### Save collection

Use the selection manager or collection controls after selecting articles.

### Load collection

Use the collection manager in the same mode where the collection belongs.

### Update collection

Load the collection, change the selection, and use update mode.

### Merge collections

Use the collection manager merge workflow where available.

### Delete or rename collection

Use the collection management actions from the collection manager.

## Output Folders

NeuroLit AI stores generated outputs locally.

Common folders include:

- Collections
- Summaries
- PPTx
- Exports
- Full text

These are located inside the active NeuroLit data folder, separated by mode.

## Token Usage Panel

The token usage panel shows:

- last run
- today total
- current week total
- current month total

It also shows provider-level usage so you can monitor which provider is consuming tokens.

## Troubleshooting

### Installer cannot replace files

Cause:

- NeuroLit AI or its bundled backend is still running

What to do:

1. Close NeuroLit AI.
2. Wait a few seconds.
3. Re-run the installer.
4. If needed, check Task Manager for:
   - `neurolit_review_app.exe`
   - `neurolit_backend.exe`

Version `v1.1.1` improves this by asking Windows to close both processes during install.

### App cannot open a saved file

Possible causes:

- the file path is in a redirected Documents folder
- the file was saved under a custom NeuroLit folder you are not currently checking

Fix:

1. Open `Settings`
2. Check the `NeuroLit Data Folder`
3. Use `Open Folder`

### OneDrive or Dropbox Documents folder issue

This is exactly why the custom data folder setting exists.

Choose a dedicated folder such as:

`D:\NeuroLitData`

or

`C:\NeuroLitData`

if you do not want NeuroLit AI tied to redirected Documents.

### API key missing

Open `Settings` and update the relevant AI provider profile.

### PPT generation failure

Possible causes:

- no review was generated first
- the Python/PPT helper environment is missing
- the target files were moved manually

Check that the review was generated and that the expected output folder exists.

### Collection not loading

Check:

- you are in the correct mode
- the collection belongs to that mode
- the active data folder is the same folder where the collection was originally saved

## Upgrade Instructions

For each new version:

1. Download the latest installer from GitHub Releases.
2. Close the current app.
3. Run the new installer.
4. Reopen NeuroLit AI.

If the update system is configured, you can also use the in-app update check from `Settings`.

## Privacy and Data Notes

NeuroLit AI stores working data locally on your computer.

Local data includes:

- saved collections
- exported summaries
- session files
- provider metadata
- token usage records

AI provider requests send prompt content to the selected external AI service when you explicitly run AI generation.

## Version Notes for v1.1.1

Version `v1.1.1` includes:

- safer Windows installer upgrade behavior
- cleaner ignore rules for build/cache/generated output
- configurable NeuroLit data folder override
- improved handling for OneDrive/Dropbox Documents redirection
- updated release automation scripts
- expanded user documentation

## Developer / Release Notes

Source releases are managed via GitHub, and installers are intended to be distributed through GitHub Releases rather than committed into the repository tree.
