# `isabelle-scripts`

Isabelle scripts

## Configure

### for Equestrian

```bash
./scripts/configure.sh \
	--pub-fqdn isabelle-staging.test.com \
	--pub-url https://isabelle-staging.test.com \
	--cert-owner "info+isabelledemo@test.com" \
	--machine-type droplet
```

### for Intranet

```bash
./scripts/configure.sh \
	--pub-fqdn intranet.test.com \
	--pub-url https://intranet.test.com \
	--cert-owner "info+intranet@test.com"
```

### for Localhost

```bash
./scripts/configure.sh \
	--pub-fqdn localhost.com:8480 \
	--pub-url http://localhost.com:8480 \
	--db "none" \
	--no-cert 1 \
	--no-fw 1
```

## Deploy

```bash
./scripts/deploy.sh
```
