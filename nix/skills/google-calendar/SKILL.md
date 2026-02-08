---
name: google-calendar
description: Google Calendar via gcalcli — view, create, edit, and delete events from the command line.
---

# google-calendar

Use `gcalcli` for Google Calendar operations. Requires one-time OAuth setup.

**Important:** Always pass `--config-folder workspace/.skill-state/gcalcli/` so tokens persist in the writable state directory.

## Setup (once)

Walk the user through initial OAuth authentication:

```bash
gcalcli --config-folder workspace/.skill-state/gcalcli/ init
```

This opens a browser URL for the OAuth consent flow. The user pastes the URL, authorizes, and gcalcli stores the refresh token in the state directory.

If a custom OAuth client ID is needed:

```bash
gcalcli --config-folder workspace/.skill-state/gcalcli/ --client-id=<CLIENT_ID> init
```

## Common commands

Always include `--config-folder workspace/.skill-state/gcalcli/` in every command.

### View events

- Agenda (next 7 days): `gcalcli --config-folder workspace/.skill-state/gcalcli/ agenda`
- Agenda (custom range): `gcalcli --config-folder workspace/.skill-state/gcalcli/ agenda "2025-03-01" "2025-03-07"`
- Weekly calendar view: `gcalcli --config-folder workspace/.skill-state/gcalcli/ calw`
- Monthly calendar view: `gcalcli --config-folder workspace/.skill-state/gcalcli/ calm`
- Search events: `gcalcli --config-folder workspace/.skill-state/gcalcli/ search "meeting"`
- List calendars: `gcalcli --config-folder workspace/.skill-state/gcalcli/ list`

### Create events

- Quick add (natural language): `gcalcli --config-folder workspace/.skill-state/gcalcli/ quick "Lunch with Alice tomorrow at noon"`
- Detailed add:
  ```bash
  gcalcli --config-folder workspace/.skill-state/gcalcli/ add \
    --title "Team standup" \
    --where "Conference Room A" \
    --when "2025-03-15 09:00" \
    --duration 30 \
    --description "Daily sync" \
    --calendar "Work"
  ```

### Edit and delete events

- Edit an event: `gcalcli --config-folder workspace/.skill-state/gcalcli/ edit "Team standup"`
- Delete an event: `gcalcli --config-folder workspace/.skill-state/gcalcli/ delete "Team standup"`

### Output formats

- JSON output for scripting: append `--tsv` for tab-separated values
- Detailed event info: `gcalcli --config-folder workspace/.skill-state/gcalcli/ agenda --details all`
- Filter by calendar: `gcalcli --config-folder workspace/.skill-state/gcalcli/ agenda --calendar "Work"`

## Notes

- Confirm before creating, editing, or deleting events.
- The `--config-folder` path is relative to the workspace root. The agent knows the workspace root.
- gcalcli self-manages OAuth tokens in the state directory — no manual secret management needed after initial setup.
- Use `quick` for fast event creation with natural language; use `add` when you need precise control over fields.
