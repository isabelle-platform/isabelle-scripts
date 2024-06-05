# isabelle-scripts
Isabelle scripts

## Configure for Equestrian

	./scripts/configure.sh --pub-fqdn isabelle-staging.test.com --pub-url https://isabelle-staging.test.com --cert-owner "info+isabelledemo@test.com" --machine-type droplet

## Configure for Intranet

	./scripts/configure.sh --pub-fqdn intranet.test.com --pub-url https://intranet.test.com --cert-owner "info+intranet@test.com"

## Deploy

	./scripts/deploy.sh
