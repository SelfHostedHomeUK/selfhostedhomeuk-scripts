# backups/

Backup scripts for Docker volumes and Postgres databases to network-mounted storage, with safeguards against the mount silently failing and being written to as an ordinary local directory instead.

Background on why this matters: [The Blog Died. Pt3: The Backups That Worked but Hadn't](https://selfhostedhome.co.uk/the-blog-died-pt3-the-backups-that-had-worked-but-hadnt/)

## 📜 Scripts

- **`backup-docker-stack.sh`** — stops a named service briefly, archives its Docker volumes and its compose project directory, restarts the service. Good fit for anything storing state in named volumes.
- **`backup-postgres-container.sh`** — takes a `pg_dump` from a running Postgres container without stopping anything, plus archives the project directory. Better fit than stop-and-tar for a database that can be dumped live.

## 🛡 Safety pattern

Both scripts share the same approach:

1. Check the backup destination is actually mounted (`findmnt`) before writing anything, rather than trusting the path is real.
2. `set -euo pipefail` plus an `ERR` trap, so any failure writes a clear `❌ FAIL` to a status file rather than leaving it stale on an old success.
3. Everything archives to a temp directory first, only copied to the real destination once every step succeeds.
4. Retention cleanup so the destination doesn't grow forever.

## ⚙️ Setup

1. Copy whichever script(s) you need and edit the configuration block at the top — paths, volume names, container names, retention. Nothing further down should need touching.
2. Confirm your network mount's fstab entry actually waits for the network properly:

```
your-server:/path /mnt/backups nfs defaults,_netdev,x-systemd.requires=network-online.target,x-systemd.after=network-online.target 0 0
```

`_netdev` alone isn't enough on its own, it only waits for networking to start initialising, not for it to actually be usable. Same principle applies to SMB/CIFS mounts, just swap the fstab syntax for `mount.cifs`.

3. Add to cron, staggered a few minutes apart if running more than one:

```
0 3 * * * /path/to/backup-docker-stack.sh >> /path/to/docker-stack-backup.log 2>&1
5 3 * * * /path/to/backup-postgres-container.sh >> /path/to/postgres-backup.log 2>&1
```

4. Add a line to `~/.bashrc` for each script so its result shows on every login, rather than sitting unread in a log:

```bash
echo "App backup:       $(cat /home/ubuntu/.my-app-backup-status 2>/dev/null || echo 'never run')"
echo "Postgres backup:  $(cat /home/ubuntu/.my-postgres-app-backup-status 2>/dev/null || echo 'never run')"
```

Deliberately just printing the status file's contents directly, nothing cleverer than that. A backup script that succeeds silently in a log nobody reads is the exact trap this exists to avoid — and a banner that tries to be smarter than "show what the script actually said" is how that trap got built in the first place.

## 🚫 What these don't do

- Manage the network mount itself, only check it's there.
- Handle off-box replication — a copy on a second physical disk is a start, not the whole story.
- Replace a proper backup framework. For retention policies more sophisticated than "delete anything older than N days," encryption, or dedup, look at restic or borg instead.

