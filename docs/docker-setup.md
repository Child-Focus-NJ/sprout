# Docker Development Setup

This guide walks you through setting up the Sprout development environment using Docker. Docker ensures everyone on the team has identical development environments regardless of their operating system.

## What is Docker?

Docker runs your application in isolated "containers" - think of them as lightweight virtual machines. Instead of installing Ruby, PostgreSQL, and other dependencies directly on your computer, everything runs inside containers with pre-configured versions.

**Benefits:**
- Everyone has the exact same environment
- No "works on my machine" problems
- Easy to reset if something breaks
- No need to install Ruby, PostgreSQL, etc. on your machine

## Prerequisites

### 1. Install Docker Desktop

Download and install Docker Desktop for your operating system:

| OS | Download Link |
|----|---------------|
| **macOS** | https://docs.docker.com/desktop/install/mac-install/ |
| **Windows** | https://docs.docker.com/desktop/install/windows-install/ |
| **Linux** | https://docs.docker.com/desktop/install/linux-install/ |

After installation:
1. Launch Docker Desktop
2. Wait for it to start (you'll see the whale icon in your menu bar/system tray)
3. Verify it's running by opening a terminal and typing:
   ```bash
   docker --version
   ```
   You should see something like `Docker version 24.x.x`

### 2. Clone the Repository

```bash
git clone <repository-url>
cd sprout
```

## Quick Start

Once Docker Desktop is running, start the development environment:

```bash
docker compose up --build
```

**First time:** This downloads images and builds containers. It may take 5-10 minutes.

**What happens:**
1. PostgreSQL database starts
2. Rails app container builds
3. Database is created and migrations run
4. Rails server starts on http://localhost:3000

Open http://localhost:3000 in your browser to see the app.

## Common Commands

### Starting and Stopping

```bash
# Start everything (with logs visible)
docker compose up

# Start in background (detached mode)
docker compose up -d

# Stop everything
docker compose down

# Stop and remove database data (fresh start)
docker compose down -v
```

### Viewing Logs

```bash
# All services
docker compose logs -f

# Just the Rails app
docker compose logs -f web

# Just the database
docker compose logs -f db
```

### Running Rails Commands

Run commands inside the web container using `docker compose exec web`:

```bash
# Rails console
docker compose exec web bin/rails console

# Run migrations
docker compose exec web bin/rails db:migrate

# Run tests
docker compose exec web bin/rails test

# Seed the database
docker compose exec web bin/rails db:seed

# Generate a model
docker compose exec web bin/rails generate model User name:string email:string

# Install new gems after updating Gemfile
docker compose exec web bundle install
```

### Database Access

```bash
# PostgreSQL console
docker compose exec db psql -U sprout -d sprout_development

# Reset database (drop, create, migrate, seed)
docker compose exec web bin/rails db:reset
```

## Project Structure

```
sprout (Docker project name)
├── web        → Rails application (port 3000)
└── db         → PostgreSQL database (port 5432)
```

## Troubleshooting

### "Cannot connect to Docker daemon"

Docker Desktop isn't running. Launch it from your Applications folder (Mac) or Start menu (Windows).

### "Port 3000 already in use"

Something else is using port 3000. Either:
- Stop the other application, or
- Change the port in `docker-compose.yml`:
  ```yaml
  ports:
    - "3001:3000"  # Use localhost:3001 instead
  ```

### "Port 5432 already in use"

You have PostgreSQL running locally. Either:
- Stop local PostgreSQL: `brew services stop postgresql` (Mac)
- Change the port in `docker-compose.yml`:
  ```yaml
  db:
    ports:
      - "5433:5432"
  ```

### Build fails with credential errors

If you see `docker-credential-desktop: executable file not found`, edit `~/.docker/config.json` and remove the `"credsStore"` line:

```bash
# Quick fix (Mac/Linux)
sed -i '' '/"credsStore"/d' ~/.docker/config.json

# Then retry
docker compose up --build
```

### Container won't start / database errors

Try a fresh start:

```bash
docker compose down -v
docker compose up --build
```

### Changes to Gemfile not reflected

After editing the Gemfile:

```bash
docker compose exec web bundle install
docker compose restart web
```

### Need to completely reset everything

```bash
# Stop containers, remove volumes, rebuild from scratch
docker compose down -v
docker compose build --no-cache
docker compose up
```

## Tips for New Docker Users

1. **Docker Desktop must be running** before you can use any `docker` commands

2. **Your code is mounted** - changes you make to files are immediately reflected in the container (no rebuild needed for code changes)

3. **Database persists** - your data survives restarts. Use `docker compose down -v` to wipe it

4. **Rebuild after Dockerfile changes** - if you modify `Dockerfile.dev`, run `docker compose up --build`

5. **Use `exec` for one-off commands** - `docker compose exec web <command>` runs inside the existing container

6. **Use `run` to start a new container** - `docker compose run --rm web <command>` starts a fresh container (useful if the app isn't running)

## Environment Variables

The Docker setup uses these defaults (defined in `docker-compose.yml`):

| Variable | Value | Description |
|----------|-------|-------------|
| `DATABASE_URL` | `postgres://sprout:sprout@db:5432/sprout_development` | Database connection |
| `RAILS_ENV` | `development` | Rails environment |

To customize, create a `.env` file in the project root (it's gitignored).

## Getting Help

- Docker documentation: https://docs.docker.com/
- Docker Compose documentation: https://docs.docker.com/compose/
- Rails on Docker guide: https://docs.docker.com/samples/rails/
