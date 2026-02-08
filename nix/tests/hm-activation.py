start_all()

machine.wait_until_succeeds(
    "systemctl show -p Result home-manager-alice.service | grep -q 'Result=success'"
)

machine.wait_until_succeeds("test -f /home/alice/.openclaw/openclaw.json")

# Verify skill library integration
with subtest("Skill library: drv skill installed"):
    machine.succeed("test -f /home/alice/.openclaw/workspace/skills/hm-test-skill/SKILL.md")

with subtest("Skill library: inline skill installed"):
    machine.succeed("test -f /home/alice/.openclaw/workspace/skills/inline-test/SKILL.md")
    machine.succeed("grep -q 'Inline Test' /home/alice/.openclaw/workspace/skills/inline-test/SKILL.md")

with subtest("Skill library: state dir created"):
    machine.succeed("test -d /home/alice/.openclaw/workspace/.skill-state/hm-test-state")

uid = machine.succeed("id -u alice").strip()
machine.succeed("loginctl enable-linger alice")
machine.succeed(f"systemctl start user@{uid}.service")
machine.wait_for_unit(f"user@{uid}.service")

machine.wait_until_succeeds("test -S /run/user/1000/bus")

machine.succeed("mkdir -p /tmp/openclaw")
machine.succeed("chmod 1777 /tmp/openclaw")

user_env = "XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
machine.succeed(f"su - alice -c '{user_env} systemctl --user daemon-reload'")

# Extract the wrapper script path from ExecStart and verify its contents
wrapper_path = machine.succeed(
    f"su - alice -c '{user_env} systemctl --user show openclaw-gateway.service -p ExecStart'"
    " | sed 's/.*path=//;s/ ;.*//'"
).strip()

with subtest("Skill library: gateway wrapper has jq on PATH"):
    machine.succeed(f"grep -q jq {wrapper_path}")

with subtest("Skill library: gateway wrapper exports skill env"):
    machine.succeed(f"grep -q TEST_SKILL_VAR {wrapper_path}")

machine.succeed(f"su - alice -c '{user_env} systemctl --user start openclaw-gateway.service'")
machine.wait_for_unit("openclaw-gateway.service", user="alice")

try:
    machine.wait_for_open_port(18999)
except Exception:
    machine.succeed(
        f"su - alice -c '{user_env} systemctl --user status openclaw-gateway.service --no-pager -n 200 > /tmp/openclaw/systemctl-status.txt 2>&1' || true"
    )
    machine.succeed(
        f"su - alice -c '{user_env} journalctl --user -u openclaw-gateway.service --no-pager -n 200 -o cat > /tmp/openclaw/journalctl.txt 2>&1' || true"
    )
    machine.succeed("coredumpctl info --no-pager | tail -n 200 >&2 || true")
    machine.succeed("ls -la /tmp/openclaw 1>&2 || true")
    machine.succeed("ls -la /tmp/openclaw/node-report* 1>&2 || true")
    machine.succeed(
        f"su - alice -c '{user_env} systemctl --user show openclaw-gateway.service --no-pager -p Environment > /tmp/openclaw/systemctl-env.txt 2>&1' || true"
    )
    machine.succeed("sed -n '1,200p' /tmp/openclaw/systemctl-env.txt >&2 || true")
    machine.succeed("wc -c /tmp/openclaw/systemctl-env.txt >&2 || true")
    machine.succeed(
        f"su - alice -c '{user_env} systemctl --user cat openclaw-gateway.service --no-pager > /tmp/openclaw/systemctl-unit.txt 2>&1' || true"
    )
    machine.succeed("sed -n '1,200p' /tmp/openclaw/systemctl-unit.txt >&2 || true")
    machine.succeed("wc -c /tmp/openclaw/systemctl-unit.txt >&2 || true")
    machine.succeed("tail -n 40 /tmp/openclaw/systemctl-status.txt >&2 || true")
    machine.succeed("tail -n 40 /tmp/openclaw/journalctl.txt >&2 || true")
    raise
