# PostgreSQL Application Connectivity (CloudNativePG)

**Purpose:** Connect a new application to the cluster's PostgreSQL, and debug an existing connection
**Cluster:** `postgres-cnpg` in namespace `data` - see [postgres-setup.md](postgres-setup.md)
**Rewritten:** 2026-09-28 for CloudNativePG. The Bitnami version (Story 5.5) is in git history.

---

## The one rule

**Connect to `postgres-cnpg-rw.data.svc.cluster.local:5432`.** It always points at the primary,
including after a switchover. Never use a pod name or pod IP, and never the old
`postgres-postgresql.data` - that service no longer exists.

---

## New application checklist

1. Create the role and database (below), one role per application.
2. Store the password in a Secret in the **application's** namespace.
3. Point the application at `postgres-cnpg-rw.data.svc.cluster.local`, port `5432`.
4. Put the non-secret settings (host, port, database, user) in the app's `values-homelab.yaml`,
   with a comment naming ADR-014. Only the password goes in the Secret.
5. Test from a pod in the app's namespace (below).
6. Add the database to the consumer table in [postgres-setup.md](postgres-setup.md) and
   [`applications/postgres-cnpg/README.md`](../../applications/postgres-cnpg/README.md).
7. Confirm the nightly `pg_dumpall` picks it up the next morning - it dumps every database, so no
   backup change is needed. See [postgres-backup.md](postgres-backup.md).

### Step 1: Create role and database

```bash
PRIMARY=$(kubectl --context default -n data get pod \
  -l cnpg.io/cluster=postgres-cnpg,cnpg.io/instanceRole=primary -o name)
kubectl --context default -n data exec -it $PRIMARY -c postgres -- psql -U postgres
```

```sql
-- Generate the password outside psql, e.g. `openssl rand -base64 24`
CREATE ROLE myapp LOGIN PASSWORD '<generated>';
CREATE DATABASE myapp OWNER myapp;
```

Making the application's role the **owner** gives it full rights in its own database and none in
anyone else's - no extra GRANTs needed. (`legacy_use` is set up this way. The older databases are
owned by `postgres`, carried over from the Bitnami import.)

Do not give an application the `postgres` superuser. LiteLLM still uses it; that is a known
follow-up, not a pattern to copy.

The role is created **by hand**, so it exists only in the database - it is not in `cluster.yaml`.
It survives switchovers (replication copies it) and is in the nightly dump.

### Step 2: Store the password

Create the Secret directly - there is nothing to overwrite yet:

```bash
kubectl --context default -n <app-namespace> create secret generic myapp-db \
  --from-literal=password='<generated>'
```

If the app has a `secret.yaml` template in the repo, keep its value **empty** there. To change the
password later, patch only that key:

```bash
kubectl --context default -n <app-namespace> patch secret myapp-db --type=merge \
  -p '{"stringData":{"password":"<new>"}}'
```

Never `kubectl apply` a secret template with empty placeholders over a live Secret.

### Step 3: Connection settings

| Setting | Value |
|---|---|
| Host | `postgres-cnpg-rw.data.svc.cluster.local` |
| Port | `5432` |
| Database / user | `myapp` / `myapp` |
| TLS | offered by the server; set `sslmode=require` |

The server accepts password logins (`scram-sha-256`) with **or without** TLS. Whether a client uses it
depends on the client, so set it explicitly. Since 2026-09-28 every consumer uses TLS: LiteLLM
and Legacy-Use by default, n8n (`DB_POSTGRESDB_SSL_ENABLED`) and Gitea (`SSL_MODE: require`) after
they were found connecting in plaintext. None verifies the certificate: `verify-full` needs the
cluster CA from secret `postgres-cnpg-ca`, and a copy in another namespace goes stale when CNPG
renews it. Check any time with the "who is connected" query below - every row should read `ssl = t`.

---

## Connection string examples

```bash
# URL form (LiteLLM, Legacy-Use, most ORMs)
postgresql://myapp:<password>@postgres-cnpg-rw.data.svc.cluster.local:5432/myapp?sslmode=require
```

```python
# Python (psycopg)
import os, psycopg
conn = psycopg.connect(
    host="postgres-cnpg-rw.data.svc.cluster.local", port=5432,
    dbname="myapp", user="myapp", password=os.environ["DB_PASSWORD"], sslmode="require",
)
```

```javascript
// Node.js (pg)
const { Pool } = require('pg')
const pool = new Pool({
  host: 'postgres-cnpg-rw.data.svc.cluster.local', port: 5432,
  database: 'myapp', user: 'myapp', password: process.env.DB_PASSWORD,
  ssl: { rejectUnauthorized: false }, // encrypt; verifying needs the postgres-cnpg-ca cert
})
```

```text
# JDBC
jdbc:postgresql://postgres-cnpg-rw.data.svc.cluster.local:5432/myapp?sslmode=require
```

**Reconnect on failure.** A switchover drops every connection once (about 8 seconds of refused
writes, measured 2026-09-28). Apps with a connection pool that retries recover by themselves;
n8n did in 7 seconds. An app that connects once at startup and never retries needs a restart.

---

## Test from the application's namespace

```bash
kubectl --context default -n <app-namespace> run pgtest --rm -it --restart=Never \
  --image=ghcr.io/cloudnative-pg/postgresql:18.6 -- \
  psql "host=postgres-cnpg-rw.data.svc.cluster.local dbname=myapp user=myapp sslmode=require" \
  -c 'select current_user, inet_server_addr(), ssl from pg_stat_ssl where pid = pg_backend_pid();'
# psql prompts for the password; expect one row with ssl = t
```

`inet_server_addr()` shows which pod answered. After a switchover it changes; the hostname does not.

---

## Troubleshooting

| Symptom | Likely cause | Check |
|---|---|---|
| `could not translate host name` | Typo, or the old `postgres-postgresql` name | `kubectl -n data get svc` |
| `connection refused` | No primary right now (switchover in progress, or cluster down) | `kubectl -n data get cluster postgres-cnpg`; see [postgres-setup.md](postgres-setup.md) |
| `password authentication failed for user` | Secret and database disagree | Reset with `ALTER ROLE myapp PASSWORD '...'` on the primary, then patch the Secret |
| `permission denied for schema public` | The database is owned by `postgres`, not the app role | `ALTER DATABASE myapp OWNER TO myapp;` or grant on schema `public` |
| `database "myapp" does not exist` | Step 1 skipped, or ran on the replica | Replicas are read-only; always exec into the pod labelled `primary` |
| `cannot execute ... in a read-only transaction` | Connected to `-ro` or `-r` | Use `-rw` |
| Errors for a few seconds, then fine | A switchover (drain, config change, minor upgrade) | Expected; check `kubectl -n data get events` |

Who is connected right now:

```bash
kubectl --context default -n data exec $PRIMARY -c postgres -- psql -U postgres -c \
  "select datname, usename, client_addr, ssl from pg_stat_activity
   join pg_stat_ssl using (pid) where backend_type = 'client backend';"
```

---

## Related

- [postgres-setup.md](postgres-setup.md) - cluster overview, health, maintenance, rebuild
- [postgres-backup.md](postgres-backup.md) / [postgres-restore.md](postgres-restore.md)
- [secret-rotation.md](secret-rotation.md) - rotating a database password
- [ADR-014](../adrs/ADR-014-postgres-off-bitnami.md)

## Change log

- 2026-01-06: Created for the Bitnami deployment (Story 5.5)
- 2026-09-28: Rewritten for CloudNativePG
