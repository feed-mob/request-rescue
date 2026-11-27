# Working on Request Rescue

## Documentation

Write all project documentation in English, including the README, changelog, plans, contributor instructions, and verification reports. Keep command examples, version numbers, and links accurate when editing or translating a document.

## Verification

Use the downstream version matrix in [PLAN.md](PLAN.md) when changing request handling or dependencies. Exercise changes through the Rails host using the packaged gem. The [README](README.md#verify-a-package-locally) describes how to run the verifier and replay its results.

## Commit attribution

For commits co-authored by an agent, include a Git `Co-authored-by: Name <email>` trailer with the contributing agent's identity. Separate the trailer from the commit description with a blank line and verify it in the saved commit message.

For a Codex co-authored commit, use the following trailer.

```text
Co-authored-by: Codex <noreply@openai.com>
```
