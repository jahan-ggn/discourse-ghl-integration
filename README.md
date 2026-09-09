# Discourse GHL Integration

A Discourse plugin that integrates GoHighLevel (GHL) contacts and tags with Discourse users, groups, and invitations.

## Overview

GoHighLevel remains responsible for CRM, subscriptions, payments, and access decisions, while Discourse manages community accounts and permissions.

GHL tags are mapped to Discourse groups:

```text
mail_club_active → mail_club
premium_member → premium
vip_member → vip
```

A single tag can also grant multiple groups:

```text
mail_club_active → mail_club
mail_club_active → paid_members
```

When an entitlement tag is added or removed in GHL, the plugin synchronizes the corresponding Discourse group access.

If the contact does not yet have a Discourse account, an invitation is created with the appropriate group access.

## Features

- GHL OAuth 2.0 integration
- Discourse user → GHL contact synchronization
- GHL contact → Discourse user linking
- Configurable GHL tag → Discourse group mappings
- One-to-many and overlapping group mappings
- Automatic group access granting and revocation
- Invitations for contacts without Discourse accounts
- Pending invitation access reconciliation
- Signed GHL webhook verification
- Asynchronous webhook processing and duplicate protection
- Automatic OAuth token refresh

## Flow

```text
GHL subscription/payment state
        ↓
GHL workflow
        ↓
Add/remove entitlement tag
        ↓
ContactTagUpdate webhook
        ↓
Discourse GHL Integration
        ↓
Discourse group access
```

GHL determines when access should be granted or revoked. The plugin does not manage payment or subscription rules itself.

When a user joins Discourse first, the plugin finds or creates their GHL contact, links the accounts, and adds the configured community member tag.

## Configuration

Configure these settings in Discourse Admin:

- `discourse_ghl_integration_enabled`
- `ghl_client_id`
- `ghl_client_secret`
- `ghl_community_member_tag`
- `ghl_tag_group_mappings`

Tag/group mappings use:

```text
<GHL_TAG>:<DISCOURSE_GROUP>
```

Example:

```text
mail_club_active:mail_club
mail_club_active:paid_members
vip_member:vip
```

The configured Discourse groups must already exist.

## GoHighLevel Setup

Configure the Marketplace app with:

**OAuth callback**

```text
https://<DISCOURSE_HOST>/crm/oauth/callback
```

**Webhook endpoint**

```text
https://<DISCOURSE_HOST>/crm/webhooks
```

GHL workflows should add entitlement tags when access becomes active and remove them when access ends.

Example:

```text
Subscription Active
→ Add mail_club_active

Subscription Canceled / Expired
→ Remove mail_club_active
```

Failed payments, grace periods, paused subscriptions, and similar rules should remain configured in GHL according to the required access policy.

## Installation

Add the plugin to `/var/discourse/containers/app.yml`:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/jahan-ggn/discourse-ghl-integration.git
```

Rebuild Discourse:

```bash
cd /var/discourse
./launcher rebuild app
```

Then configure the plugin settings, complete the GHL OAuth connection, configure the required GHL workflows, and test access granting and revocation.