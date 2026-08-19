# Windows 11: WSL + Docker Desktop for Sprout

This guide is for a **Windows 11 PC that does not have WSL**. It gets Ubuntu (WSL 2) installed, Docker Desktop talking to that distro, and Sprout serving at [http://localhost:3000](http://localhost:3000). 

[Install WSL](https://learn.microsoft.com/en-us/windows/wsl/install)  
[Install Docker Desktop on Windows](https://docs.docker.com/desktop/setup/install/windows-install/)  
[WSL 2 backend](https://docs.docker.com/desktop/features/wsl/)

## 1. Confirm virtualization

1. Open **Task Manager** (`Ctrl+Shift+Esc`) → **Performance** → **CPU**.
2. Confirm **Virtualization** is **Enabled**.

## 2. Install WSL

1. Open **PowerShell as Administrator**.
2. Run:

```powershell
wsl --install
```

1. Restart when Windows asks you to.

After reboot:

1. Run `wsl` in PowerShell.
2. Wait for first-boot file extraction.
3. Create a Linux username and password when prompted. That password is for `sudo` inside Ubuntu, not your Windows password.

Check from **Windows PowerShell** (not admin):

```powershell
wsl --version
wsl --list --verbose
```

You should see something like:  

```text
  NAME              STATE           VERSION

* Ubuntu            Running         2

  docker-desktop    Running         2
```

`docker-desktop` appears **after** Docker Desktop is installed and running. Right after `wsl --install`, you should only see Ubuntu (or whichever distro you chose). New installs default to WSL 2. If a distro is version 1:

```powershell
wsl --set-version Ubuntu 2
wsl --set-default-version 2
```

Note that Docker Desktop requires **WSL 2.1.5 or later.**

3. Install Docker Desktop

 [Docker’s Windows install](https://docs.docker.com/desktop/setup/install/windows-install/)

Then in Docker Desktop:

1. **Settings** → **General**: **Use WSL 2 based engine** should be on. Docker says that if the machine only supports WSL 2, this control may already be on and hidden.
2. **Settings** → **Resources** → **WSL Integration**: enable integration for **Ubuntu** (the default distro). On this PC `settings-store.json` contains `"IntegratedWslDistros": ["Ubuntu"]`.
3. **Apply**.

Confirm the engine from PowerShell:

```powershell
docker version
docker compose version
```

## 4. Use Docker from Ubuntu

Open Ubuntu (Start menu) or `wsl` from PowerShell, then:

```bash
docker --version
docker info
```

## 5. Boot Sprout on localhost

First start by cloning and cding into the repo.

1. Start **Docker Desktop** and wait until it is running.
2. In Ubuntu, run:

```bash
bin/dev-docker
```

`bin/dev-docker` checks that `docker` exists and that the daemon is up, then runs `docker compose up`. Compose starts three services from `docker-compose.yml`:


| Service      | Role                                | Host URL / port                                |
| ------------ | ----------------------------------- | ---------------------------------------------- |
| `web`        | Rails (image from `Dockerfile.dev`) | [http://localhost:3000](http://localhost:3000) |
| `db`         | PostgreSQL 16                       | `localhost:5432`                               |
| `localstack` | AWS emulator                        | [http://localhost:4566](http://localhost:4566) |


On first start, Docker builds the Rails image (Ruby 3.4.5, `bundle install`, etc). This can take several minutes.

When the `web` container starts, `bin/docker-entrypoint-dev` (not `db:seed`) does:

- `bundle check` / `bundle install` if gems are missing
- `bin/rails db:create` if the database does not exist
- `bin/rails db:migrate`
- `bin/rails tailwindcss:build`
- `bin/rails server -b 0.0.0.0`

After a few minutes, [localhost](http://localhost) should be good to use, and you can navigate the app locally!

