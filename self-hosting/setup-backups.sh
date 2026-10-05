#!/bin/sh
#
# One-time setup for daily backups on this server. Run as root:
#
#   sh setup-backups.sh
#
# It schedules backup.sh to run every night, takes a first backup right
# away so you can see it work, and lists what's stored. Safe to re-run —
# it just rewrites the same schedule.
#
# What it sets up:
#   /etc/cron.d/gulf-spectrum-backup    the nightly schedule (02:15 UTC)
#   /var/backups/gulf-spectrum/         where archives are kept (root-only)
#   /var/log/gulf-spectrum-backup.log   a line or two per run
#
# It changes nothing else on this server, which is shared with other
# GoGMI projects.

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
CRON_FILE=/etc/cron.d/gulf-spectrum-backup
LOG_FILE=/var/log/gulf-spectrum-backup.log

[ "$(id -u)" -eq 0 ] || { echo "Run this as root."; exit 1; }
[ -f "$SCRIPT_DIR/backup.sh" ] || { echo "backup.sh not found next to this script."; exit 1; }
[ -d /etc/cron.d ] || { echo "/etc/cron.d not found — is cron installed? (apt-get install cron)"; exit 1; }

chmod 700 "$SCRIPT_DIR/backup.sh"

# cron.d entries need the user field (root) and a trailing newline, and the
# file must not be group/world-writable or cron ignores it.
cat > "$CRON_FILE" <<EOF
# Gulf Spectrum Journal — nightly backup. Written by setup-backups.sh.
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
15 2 * * * root sh $SCRIPT_DIR/backup.sh >> $LOG_FILE 2>&1
EOF
chmod 644 "$CRON_FILE"
echo "Scheduled: every night at 02:15 UTC ($CRON_FILE)."
echo ""

echo "Taking a first backup now…"
sh "$SCRIPT_DIR/backup.sh" 2>&1 | tee -a "$LOG_FILE"
echo ""

echo "Backups on this server:"
ls -lh /var/backups/gulf-spectrum/ 2>/dev/null | grep 'gulf-spectrum-' || echo "  (none — see the error above)"
echo ""
echo "Next: check that a backup can really be restored —  sh $SCRIPT_DIR/verify-backup.sh"
