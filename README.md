# isabelle-scripts
Isabelle scripts

## Configure for Equestrian

	./scripts/configure.sh --pub-fqdn isabelle-staging.test.com --pub-url https://isabelle-staging.test.com --cert-owner "info+isabelledemo@test.com" --machine-type droplet

## Configure for Intranet

	./scripts/configure.sh --pub-fqdn intranet.test.com --pub-url https://intranet.test.com --cert-owner "info+intranet@test.com"

## Configure for other

	./scripts/configure.sh --pub-fqdn localhost.com:8480 --pub-url http://localhost.com:8480 --db "none" --no-cert 1 --no-fw 1
	
## Configure for Midair

	./scripts/configure.sh --pub-fqdn midair.test.com --pub-url http://midair.test.com --cert-own "info+midair@test.com" --features-file ./midair-features.js

## CORS

The core answers cross-origin requests only from the origin in `--pub-url`.
A site elsewhere whose pages call this installation — say, contact and
waitlist forms on a public website posting to the intranet — needs its origin
listed, or the browser refuses to read the response and the form reports a
failure even though the server handled the request:

	./scripts/configure.sh --cors-origin https://interpretica.io --cors-origin https://www.interpretica.io

Repeat the flag for several origins. Each run that passes `--cors-origin`
replaces the stored list, so pass all of them every time; `--cors-origin ""`
clears it. Restart the service to apply. The core logs
`CORS: allowing origin …` for each one at startup.

## Features

`--features-file` takes the path to a `features.js` document saying what this
installation is allowed to do. `deploy.sh` and `update.sh` copy it into
`data/raw/`, where the core reads it once at startup and never writes it;
there is no endpoint that edits it, so no session and no token can widen it
from inside the running server.

It belongs to the installation rather than to the release: two hosts running
the same tarball may be entitled to different things, so it is not shipped in
the tarball, and re-installing it is part of every update.

The document is a JSON object of feature name to descriptor. These scripts
check that shape and nothing else — which names exist and what their
descriptors mean is the flavour's business, so see the flavour's own
documentation for the list it understands.

	{
	    "some_feature": true,
	    "another_feature": { "limit": 10 }
	}

Passing no `--features-file` writes nothing at all, which leaves an existing
installation with whatever `features.js` it already has: `tar` overwrites
only the files a release actually carries.

## Configure for Zine

	./scripts/configure.sh --pub-fqdn zine.test.com --pub-url https://zine.test.com --cert-owner "info+zine@test.com"

## Deploy

	./scripts/deploy.sh

## Hardening

`deploy.sh`, and `service.sh` on every start, run `harden.sh`, which puts in
place what every machine on the internet needs:

* security updates, applied unattended (no automatic reboot);
* sshd: keys only, and root by key only — as a drop-in, so `Match` blocks a
  flavour adds for its own users keep working;
* fail2ban on sshd, plus `recidive` for addresses that keep coming back;
* the ports Docker publishes kept off the network. Docker's rules come
  before ufw's, so without this a published container port is open to the
  world whatever ufw says.

It never opens or closes a ufw port. Running it again changes nothing unless a
release changed it, which is how a change reaches the hosts already running.
What it did last is in `/var/lib/isabelle-harden/state`.

`--no-harden 1` leaves the host alone, and `--no-fw 1` implies it. Outside a
release, on a host that runs no Isabelle, the script works on its own:

	sudo ./harden.sh [--trust <address or CIDR>]...

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
