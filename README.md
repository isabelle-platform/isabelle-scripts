# isabelle-scripts
Isabelle scripts

## Configure for Equestrian

	./scripts/configure.sh --pub-fqdn isabelle-staging.test.com --pub-url https://isabelle-staging.test.com --cert-owner "info+isabelledemo@test.com" --machine-type droplet

## Configure for Intranet

	./scripts/configure.sh --pub-fqdn intranet.test.com --pub-url https://intranet.test.com --cert-owner "info+intranet@test.com"

## Configure for other

	./scripts/configure.sh --pub-fqdn localhost.com:8480 --pub-url http://localhost.com:8480 --db "none" --no-cert 1 --no-fw 1
	
## Configure for Midair

	./scripts/configure.sh --pub-fqdn midair.test.com --pub-url http://midair.test.com --cert-own "info+midair@test.com"

## Deploy

	./scripts/deploy.sh

## Release signature verification

`update.sh` downloads `<release>.tar.xz.asc` next to the release and checks
it against `isabelle-release-pubkey.asc` from this repo before it stops the
service or unpacks anything. A bad signature aborts the update and leaves
the running installation untouched.

	Isabelle Release Signing <signing@interpretica.io>
	66C2 5C72 A855 C4AF CD68  1735 C161 003C B406 0BF4

The trusted key comes from the *installed* scripts, i.e. from the previous
already-verified release — never from the tarball being installed. Rotating
the key therefore means shipping the new public key in a release still
signed with the old one, and only then switching the signer.

`--no-verify` skips the check. It exists for emergency recovery (e.g. a
release published before signing was wired up); it is not for routine use.
