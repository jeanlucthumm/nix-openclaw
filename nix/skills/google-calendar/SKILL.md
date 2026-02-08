---
name: google-calendar
description: Google Calendar via gcalcli — view, create, edit, and delete events from the command line.
---

# google-calendar

Use `gcalcli` for Google Calendar operations. Always pass `--config-folder workspace/.skill-state/gcalcli/` so tokens persist in the writable state directory.

## Authentication

If any gcalcli command fails with an authentication or credentials error, tell the user they need to run the one-time OAuth setup on the server:

```
sudo -u openclaw gcalcli --config-folder /var/lib/openclaw/workspace/.skill-state/gcalcli/ init
```

This prints an OAuth URL to open in a browser. After authorizing, gcalcli stores the refresh token in the state directory and all subsequent commands will work.

Do not attempt to run `gcalcli init` yourself — it requires interactive browser-based authorization.

## Common commands

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

- Detailed event info: `gcalcli --config-folder workspace/.skill-state/gcalcli/ agenda --details all`
- Filter by calendar: `gcalcli --config-folder workspace/.skill-state/gcalcli/ agenda --calendar "Work"`
- Tab-separated output: append `--tsv`

## Notes

- Confirm before creating, editing, or deleting events.
- The `--config-folder` path is relative to the workspace root.
- gcalcli self-manages OAuth tokens in the state directory — no manual secret management needed after initial setup.
- Use `quick` for fast event creation with natural language; use `add` when you need precise control over fields.
