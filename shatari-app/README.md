# Shatari App Containerization

This folder contains the Docker configuration for the Shatari application stack (Undermine Exchange).

## Architecture

- **Backend (`shatari`)**: A Node.js worker that fetches data from the Battle.net API and writes it to shared volumes.
- **Frontend (`shatari-front`)**: A Vite-based static site served by Nginx.
- **Data Sharing**: The backend writes to `/app/data` and `/app/realms`. These are shared with the frontend via Docker volumes and served under `/data/` and `/json/realms/`.

## Important Note: Content Security Policy (CSP)

The original `shatari-front` repository contains a very restrictive hardcoded CSP meta tag in `index.html` that only allows loading resources from `https://undermine.exchange`.

**During the Docker build process, this tag is automatically removed** to allow the application to run on any domain, IP, or port (e.g., `http://localhost:8080`).

### Re-adding CSP
If you want to deploy this to production and re-enable a strict CSP, we recommend doing so via Nginx headers rather than re-injecting the meta tag. This is cleaner and easier to maintain.

You can modify the `nginx.conf` file in this directory and uncomment or add the following line:

```nginx
add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline' https://wow.zamimg.com; img-src 'self' data: https://wow.zamimg.com; connect-src 'self' https://*.wowhead.com; font-src 'self' https://wow.zamimg.com;";
```

## Deployment

1. Set your credentials in an `.env` file:
   ```env
   BATTLE_NET_KEY=your_key
   BATTLE_NET_SECRET=your_secret
   ```
2. Run the stack:
   ```bash
   docker compose up -d
   ```

## Configuration

- **Nginx**: Modify `nginx.conf` to adjust headers, security settings, or routing.
- **Versions**: The GitHub Actions workflow tracks the latest commits of the 3 repositories and rebuilds the images automatically.
