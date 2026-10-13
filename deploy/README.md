# Putting GardenFlow online

Everything runs with Docker Compose on one Linux machine, a small PC at home or a VPS :

```
phone ──HTTPS──▶ Caddy ──▶ gardenflow-api ──▶ MySQL
                  │                              (shared by all the apps)
                  └──▶ other apps later (one block in the Caddyfile)
```

- **Server at home** : the requests arrive through a **Cloudflare tunnel** (the `cloudflared` container connects to Cloudflare, no port to open on the box). Cloudflare does the HTTPS. Needs a domain name managed by Cloudflare.
- **VPS** : the requests arrive directly, **Caddy gets the HTTPS certificate** itself (Let's Encrypt). Ports 80 and 443 open. A free subdomain (DuckDNS) is enough to start.

The same files work in both cases : only `COMPOSE_PROFILES` and `SITE_PREFIX` change in `deploy/.env`.

| File | Role |
| --- | --- |
| `docker-compose.yml` | the containers : Caddy, cloudflared (home only), MySQL, the API |
| `Caddyfile` | which address goes to which app |
| `.env.example` | the settings, to copy to `.env` (passwords : never committed) |
| `backup.sh` / `restore.sh` | nightly backup, and putting a backup back |
| `../backend/Dockerfile` | the image of the API (the migrations are applied at each start) |

---

## 1. The machine

**At home** : a mini PC or a small office PC with 4 GB of RAM or more, an SSD, plugged to the box **with a cable**. In its BIOS, set **"Restore on AC power loss" to "Power on"** : it restarts by itself after a power cut.

**VPS** : 2 GB of RAM is enough for GardenFlow (the whole server uses about 250 MB) plus a few small apps. Prefer a datacenter in Europe (personal data of the users).

## 2. Linux

Install **Ubuntu Server** (the latest LTS version). On a PC at home : write the image on a USB stick (Rufus or balenaEtcher), boot on it, and during the installation **tick "Install OpenSSH server"**. A VPS comes with Ubuntu already installed.

Then everything is done from your PC, in a terminal : `ssh <user>@<address of the server>` (at home, the address is shown by the box ; give the server a fixed address in the box settings, "DHCP reservation").

```bash
# security updates installed automatically
sudo apt update && sudo apt upgrade -y
sudo apt install -y unattended-upgrades git
sudo dpkg-reconfigure -plow unattended-upgrades   # answer Yes

# firewall : SSH only (+ 80 and 443 on a VPS)
sudo ufw allow OpenSSH
sudo ufw allow 80,443/tcp      # VPS only
sudo ufw enable
```

## 3. Docker

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER      # then log out and back in (exit, ssh again)
docker run --rm hello-world        # check
```

## 4. The code

```bash
cd ~
git clone https://github.com/Taglhydz/GardenFlow.git
cd GardenFlow
```

If the repository is private, GitHub asks for a username and a **personal access token** as password (GitHub > Settings > Developer settings > Fine-grained tokens, read access to this repository only).

## 5. The address of the API

### A. Server at home : Cloudflare tunnel

1. Buy a domain name (about 10 € a year) and add it to a free Cloudflare account (Cloudflare tells which "nameservers" to set at the registrar ; it takes up to a few hours).
2. In the Cloudflare dashboard : **Zero Trust > Networks > Tunnels > Create a tunnel**, type **Cloudflared**, name `server`. Copy the **token** shown in the install command (the long string after `--token`) : it goes in `TUNNEL_TOKEN`.
3. In the tunnel, add a **public hostname** : subdomain `api`, your domain, service type **HTTP**, URL **`caddy:80`**.

The address of the API is then `api.<your domain>`.

### B. VPS

Point the address to the IP of the VPS : a DNS record of type **A** at the registrar of your domain, or a free subdomain on [duckdns.org](https://www.duckdns.org) (e.g. `gardenflow.duckdns.org`). Caddy gets the certificate at the first start.

## 6. The settings

```bash
cd ~/GardenFlow/deploy
cp .env.example .env
chmod 600 .env
openssl rand -hex 32    # run it once per password / secret to fill in
nano .env
```

- Server at home : keep `COMPOSE_PROFILES=tunnel` and `SITE_PREFIX=http://`, fill in `TUNNEL_TOKEN`.
- VPS : empty `COMPOSE_PROFILES=` and `SITE_PREFIX=`.
- `GARDENFLOW_DOMAIN` : the address of step 5, without `https://`.
- `MYSQL_ROOT_PASSWORD`, `GARDENFLOW_DB_PASSWORD`, `GARDENFLOW_JWT_SECRET` : random values. **Keep a copy of `.env` in your password manager** : the backups can't be used without these passwords.
- `SMTP_*` : the email service (until it is set, the emails are only written in the logs : `docker compose logs gardenflow-api`).

## 7. Start

```bash
cd ~/GardenFlow/deploy
docker compose up -d --build
docker compose ps                       # everything "Up", the API and MySQL "(healthy)" after a minute
docker compose logs -f gardenflow-api   # Ctrl+C to quit
```

From your phone or your PC : `https://<GARDENFLOW_DOMAIN>/api/health` answers `{"status":"ok"}`.

The containers restart by themselves after a crash or a reboot of the machine.

**Admin account** : create your account in the app, then

```bash
docker compose exec gardenflow-api node scripts/set-role.js <your email> admin
```

## 8. The app

In `frontend/config/prod.json` (see the main README, "Release build") : `"API_BASE_URL": "https://<GARDENFLOW_DOMAIN>/api"`, then build the app.

## 9. Updates

```bash
cd ~/GardenFlow
git pull
cd deploy
docker compose up -d --build    # the new migrations are applied when the API starts
```

Make a backup first (`bash backup.sh`) when the update has a new migration.

## 10. Backups

`backup.sh` saves every database of the apps (`mysqldump`) and the photos of GardenFlow in `deploy/backups/<date>`, keeps them `BACKUP_KEEP_DAYS` days, and copies them to `BACKUP_REMOTE` with [rclone](https://rclone.org) : **another place than the server**, e.g. your Google Drive.

```bash
sudo apt install -y rclone
rclone config
#   n (new remote), name : gdrive, storage : drive, leave client_id / secret empty, scope : 1 (full access)
#   "Use web browser to automatically authenticate?" -> n (the server has no browser) :
#   install rclone on your PC too, run the command it shows there, paste the result back
```

The backups contain the data of the users : they are **encrypted** before leaving the server, with a second remote of type `crypt` (Google only sees unreadable files) :

```bash
rclone config
#   n (new remote), name : backups, storage : crypt, remote : gdrive:gardenflow-backups
#   filename_encryption : standard, directory_name_encryption : true
#   password : g (generate) -> keep it in your password manager, with the second one (salt) :
#   without them, the backups can never be read again
```

In `.env` : `BACKUP_REMOTE=backups:` (the encrypted remote, not `gdrive:`). To read a backup from another machine : the same `rclone config` with the same two passwords. Then :

```bash
bash ~/GardenFlow/deploy/backup.sh     # by hand once : "✅ Backup ..." and "✅ Copied to ..."
crontab -e                             # then add this line : every night at 3:30
30 3 * * * bash ~/GardenFlow/deploy/backup.sh >> ~/GardenFlow/deploy/backups/backup.log 2>&1
```

**Test a restore at least once** (a backup that was never restored is not a backup) :

```bash
bash ~/GardenFlow/deploy/restore.sh ~/GardenFlow/deploy/backups/<date>
```

It replaces the databases and the photos by the backup (what changed since is lost) : do it right after a backup, or on a test server. After a disaster (new machine) : steps 2 to 7 with the **same `.env`**, copy a backup back from the remote (`rclone copy backups:<date> ~/restore`, after the same `rclone config` as above), then `restore.sh ~/restore`.

## 11. Another app on the same server

1. Its service in `docker-compose.yml` (without `ports` : Caddy is the only entry).
2. Its database, if it needs one : `docker compose exec mysql mysql -uroot -p` then
   `CREATE DATABASE blog; CREATE USER 'blog'@'%' IDENTIFIED BY '<password>'; GRANT ALL ON blog.* TO 'blog'@'%';`
   (`backup.sh` saves it automatically ; the MySQL users are not in the backups : write them down).
3. A block in the `Caddyfile` : `{$SITE_PREFIX}blog.example.com { reverse_proxy blog:8080 }`.
4. At home : one more public hostname in the tunnel (`blog` → `caddy:80`). On a VPS : the DNS record.
5. `docker compose up -d`.

## Useful commands

All from `~/GardenFlow/deploy` :

| Command | |
| --- | --- |
| `docker compose ps` | state of the containers |
| `docker compose logs -f --tail 100 gardenflow-api` | logs of the API |
| `docker compose restart gardenflow-api` | restart the API |
| `docker compose exec gardenflow-api node scripts/migrate.js status` | migrations |
| `docker compose exec mysql mysql -uroot -p gardenflow` | MySQL console |
| `docker stats` | memory and CPU of each container |
