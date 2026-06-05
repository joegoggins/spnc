# About

Collabornet is an app that hosts software intended to facilitate hyper-local, resilient, and collaborative economies.

# Technical Overview

## Domains + Subdomains

The development site will live under the japoofis.com domain, the production site will live at mspsolarpunk.com.

```
mspsolarpunk.com         # Home page: Just says, "If you have an account here, please [login](login link)."
login.mspsolarpunk.com   # Hosted Zitadel based login
*.sites.mspsolarpunk.com # Each collaborative site gets it's own subdomain with its own role based access control about who can do what.
```
## Database Schema

```
collab_sites
  id 123
  name Pleasant Ave Garden       # can change
  slug pleasant-ave-garden       # typically never changes
  subdomain pleasant-ave-garden  # typically never changes,
```