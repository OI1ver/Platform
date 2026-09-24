# Privacy

Platform is designed to work without user accounts, analytics, advertising or
cross-app tracking.

## Stored on the Mac

- Favourite stations and the selected default station
- Display, refresh, update and launch-at-login preferences
- The most recent successful departure board for offline/stale presentation
- An anonymous random installation identifier stored in Keychain

Platform does not collect a name, email address, payment information or travel
history. Removing favourites and cached application data removes the related
local selections; the Keychain identifier can be removed separately through
Keychain Access.

## Sent over the network

The app requests departures and service details from the project's Cloudflare
Worker. Requests include the station or service being viewed and the anonymous
installation identifier used for best-effort rate limiting. Cloudflare and the
upstream National Rail service may process ordinary connection metadata such as
IP addresses as part of operating their services.

No Rail Data Marketplace credential is present in the application. The Worker
holds those credentials as encrypted deployment secrets.

## Source and reporting

The client and relay source are public so their behaviour can be inspected.
Report privacy or security vulnerabilities privately using
[SECURITY.md](../SECURITY.md).
