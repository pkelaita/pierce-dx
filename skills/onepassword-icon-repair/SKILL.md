---
name: onepassword-icon-repair
description: Repair missing custom icons for 1Password vault items by backing up and verifying the vault, researching official site assets, preparing square transparent PNGs and a report, and optionally uploading them through the desktop UI after explicit permission. Use for 1Password missing-icon audits or bulk icon restoration; not for general favicon scraping.
---

# 1Password Icon Repair

Treat vault contents as secrets. Never print credentials, put plaintext backups in the deliverable, expose auth tokens, or give subagents item IDs, titles, full URLs, or private fields. The root agent owns every `op` call; subagents may receive only public domains or neutral research keys.

## Permissions and phases

Split the work into preparation and upload phases:

1. Preparation uses the 1Password CLI and public web research. It does not require desktop control.
2. Upload uses the 1Password desktop UI because the CLI does not support custom-icon upload. Obtain explicit permission first and tell the user that automated mouse/keyboard activity can interfere with their foreground work. The user must grant macOS Accessibility access themselves; never enable it automatically.

If upload happens in a later session, make a fresh vault backup immediately before changing anything.

## One-auth session

Run all secret-bearing CLI work in one persistent shell or PTY so biometric approval occurs once:

```bash
set +x
export OP_BIOMETRIC_UNLOCK_ENABLED=true
eval "$(op signin)"
```

Keep the session token only in that shell's environment. Never print it, save it, pass it on a command line, or share it with a subagent. Keep the same shell alive for the operation, check it with `op whoami`, and sign out when finished. If the session expires, stop and ask the user to authenticate again; do not work around authentication.

## Prepare and back up

1. Confirm the target vault, defaulting to `Personal` only when that is the user's stated target.
2. Create a mode-700 temporary directory with `mktemp -d`; keep it outside the final Desktop folder.
3. Record active and archived item lists, then fetch every item with `op item get --reveal --format=json`. Download Document contents and FILE-field attachments when accessible. Store checksums and an inventory without displaying secret values.
4. Record the baseline item count and ID set. A CLI snapshot is a working recovery record, not a guaranteed bit-for-bit 1Password export: custom icons, passkeys, and history may not be fully represented.

Do not mutate the vault during preparation.

## Find candidates

The CLI does not expose whether an item has a custom icon. Build a candidate list from each item's first login website and the 1Password rich-icon endpoint:

`https://c.1password.com/richicons/images/login/large/<domain>.png`

A missing response is only a candidate signal, not proof that the item lacks an icon. Keep separate report sections for candidates, domains already served by 1Password, and items without a usable website. Before upload, visually confirm each candidate in the desktop app and skip anything that already has an appropriate custom icon.

## Research and prepare icons

Parallelize public research when useful, but give subagents only domains or neutral keys. For each candidate:

1. Prefer an official site, web manifest, brand/press kit, or official repository.
2. Choose the highest-resolution native square PNG with transparency. If only an official SVG exists, render it to a 1024x1024 transparent PNG.
3. Pad non-square artwork on a transparent square canvas without stretching or cropping it. Preserve larger native PNGs. Disclose low-resolution sources, upscaling, unofficial fallbacks, ambiguous branding, or unusual padding.
4. Do not invent logos with image generation or use screenshots as icons.
5. Validate every output: PNG MIME/type, equal width and height, alpha channel, at least one actually transparent pixel, and SHA-256 hash. Make contact sheets and visually inspect them for clipped, tiny, wrong, or duplicate marks.

Create `~/Desktop/Personal Vault Icons - YYYY-MM-DD/` containing:

- `icons/*.png`
- `icons/SHA256SUMS.txt`
- `report.md`

The report must map each item or neutral key to its domain, source URL, source/output dimensions, research or conversion notes, and status. Include unresolved sites, no-site items, rich-icon-present items, skipped existing icons, and upload status. State that CLI-based candidate detection is provisional until UI confirmation.

## Upload

After explicit desktop-control permission:

1. Make the fresh baseline backup and verify its inventory.
2. Restrict UI automation to 1Password and the file picker. Process active items by default; skip archived items unless the user requests them.
3. For each candidate, open the exact item, visually confirm the icon is missing, upload the mapped PNG, save, and log the result. If identity is ambiguous, stop rather than guessing.
4. Never edit titles, URLs, credentials, tags, notes, fields, vault membership, or archive state. Never delete items or vaults.

## Verify and clean up

Re-read the complete vault through the same authenticated shell. Require the item count and ID set to match exactly. Compare normalized before/after JSON while excluding only:

- `.version`
- `.updated_at`
- `.last_edited_by`
- the derived, rotating value in `.fields[].totp`
- an icon field, but only if the CLI actually exposes one

Continue comparing the stored TOTP secret and every other field. After upload, only icon data and unavoidable change-history metadata may differ. On any mismatch, stop, retain the temporary backup, and report only item IDs and differing JSON paths—never values. Restore from the snapshot only with explicit user permission.

After a clean verification, update the report, sign out of 1Password, unset session variables, verify the temporary path is the exact directory created for this run, and delete that plaintext backup. Preserve the report and public icon assets. If interrupted or verification fails, sign out but retain the backup until the user decides what to do.
