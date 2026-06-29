# Router Dr.COM Auto Login

This directory contains a BusyBox-compatible shell implementation for Dr.COM / EPortal campus auto-login on SSH-unlocked stock routers.

It is useful when the campus network session belongs to the router and you do not want to keep a Windows laptop running just to submit the portal login.

## Files

- `drcom-router-login.sh` — router-side login script.
- `router-config.example` — sanitized config template.

## Install

Copy files to the router:

```sh
mkdir -p /data/campus-login
cp drcom-router-login.sh /data/campus-login/login.sh
cp router-config.example /data/campus-login/config
chmod 700 /data/campus-login/login.sh
chmod 600 /data/campus-login/config
```

Edit `/data/campus-login/config` and fill:

- `PORTAL_PAGE`
- `LOGIN_BASE`
- `USERNAME`
- `PASSWORD`
- `ISP`

Then add cron:

```sh
echo '*/1 * * * * /data/campus-login/login.sh >/dev/null 2>&1' >> /etc/crontabs/root
/etc/init.d/cron restart 2>/dev/null || /etc/init.d/crond restart
```

## Behavior

Every minute the script:

1. Checks `CHECK_URL`.
2. If online, exits without submitting credentials.
3. If offline, fetches the portal page and extracts client IP/MAC hints.
4. Sends the Dr.COM JSONP login request.
5. Writes diagnostic logs to `/data/campus-login/campus-login.log`.

The password is not written to the log and curl uses a temporary config file so the password is not exposed in process arguments.

## How to adapt to your campus

Use browser DevTools → Network → Preserve log, log in once manually, and find the request similar to:

```text
/eportal/portal/login?callback=...&login_method=1&user_account=...&user_password=...
```

Match the observed values in `router-config.example`, especially:

- `LOGIN_BASE`
- `ACCOUNT_PREFIX`
- `ISP`
- `JS_VERSION`
