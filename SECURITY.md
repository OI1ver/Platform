# Security policy

Please report credential exposure, update-signing issues, relay bypasses or
other security problems through GitHub's private vulnerability-reporting form
rather than opening a public issue. If private reporting has not yet been
enabled on the repository, contact the repository owner privately.

The macOS client must never contain RDM credentials. The public relay is an
anonymous, rate-limited read-only service and cannot fully prevent determined
third-party use; operators should enable Cloudflare limits, KV bindings and
usage alerts and rotate upstream credentials if misuse is suspected.
