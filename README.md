# Discourse GHL Integration

A Discourse plugin that integrates GoHighLevel (GHL) contacts and tags with Discourse users, groups, and invitations.

## Overview

This plugin keeps GoHighLevel responsible for CRM, subscriptions, payments, and access decisions, while Discourse manages community accounts and permissions.

GHL tags can be mapped to Discourse groups through configurable tag-to-group mappings. This allows different GHL tags to control access to different areas of the Discourse community.

For example:

```text
mail_club_active → mail_club
premium_member → premium
vip_member → vip
```

When a GHL contact has a configured tag, the corresponding Discourse user is added to the mapped Discourse group.

When that tag is removed, the user is removed from the corresponding group while their Discourse account and any unrelated community access remain active.

The mappings are configurable, so the integration is not limited to any specific GHL tag or Discourse group.