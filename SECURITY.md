# Security Policy

This repository is the Sanctum marketing site (<https://sanctum.haus>). It ships
static brand content, not runtime code, so the surface is small — but it is
public, it is a first impression, and it can still leak.

## Reporting

**Do not open a public GitHub issue.** Use either:

- **GitHub Security Advisories** — preferred. Draft one at
  <https://github.com/ogilthorp3/sanctum-haus/security/advisories/new>.
- **Email** — `security@sanctum.run`.

## Especially welcome

- Anything in the built site that exposes real infrastructure: an IP, a
  hostname, a tailnet name, an email address, or a credential of any kind.
- A form, link, or analytics call that sends visitor data somewhere the page
  does not disclose.
- Anything that would let someone else publish to this domain.

## What to Expect

Acknowledgement within 3 business days. For a live exposure we remove the
content first and discuss second — and we will say plainly that removal does not
undo publication.

Note on licensing: the brand content here is proprietary (see
[NOTICE.md](./NOTICE.md)). That is a licensing statement, not a security
boundary — please still report anything you find.
