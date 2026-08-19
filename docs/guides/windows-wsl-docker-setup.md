# Windows 11: WSL + Docker Desktop for Sprout

This guide is for a **Windows 11 PC that does not have WSL**. It gets Ubuntu (WSL 2) installed, Docker Desktop talking to the Ubuntu distro, then Sprout running on localhost. 

Prerequistes:
- [Install WSL](https://learn.microsoft.com/en-us/windows/wsl/install)  
- [Install Docker Desktop on Windows](https://docs.docker.com/desktop/setup/install/windows-install/)  
- [WSL 2 backend](https://docs.docker.com/desktop/features/wsl/)
- The OAuth secrets for [`sprout_startup.ps1`](./sprout_startup.ps1)

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
> [!NOTE]
> If Ubuntu is not set as default, run  `wsl --set-default Ubuntu` on Powershell.

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

First restart Docker Desktop, then open `wsl` from PowerShell. From there:

```bash
docker --version
docker info
```

## 5. Boot Sprout on localhost

From Powershell at the root level, run

```
powershell -ExecutionPolicy Bypass -File .\sprout_startup.ps1 -Reset
```

> [!NOTE]
> The -Reset flag tells the script to start Sprout with: `./bin/dev-docker --reset`, which recreates Docker volumes and gives you a clean local environment.

> [!IMPORTANT]
> You will need the OAuth secrets for `sprout_startup.ps1`. This file contains information. You can also run the script from any folder. Use the full path to `sprout_startup.ps1` if you’re not in the same directory as the script.

After a few minutes, localhost should be good to use, and you can navigate the app locally!