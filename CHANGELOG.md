# Changelog

## Unreleased

- Install the middleware after `ActionDispatch::RemoteIp`, as feedmob-rescue did, so malformed requests are rejected before the Rails request log and application middleware. Check the query before the HTTP method.
- Raise a template that is missing in every format when migration mode is off, so the application reports a 500. A template that exists only in other formats still returns 404.
- Use route format defaults and the `format` parameter to choose JSON error responses.

## 0.1.4

- Restore HTTP 400 in migration mode for query values with invalid UTF-8, including requests to mounted error pages.

## 0.1.1

- Switch to manual patch releases and verify the same gem across all supported environments before publishing to RubyGems.
- Tag the published source and open a pull request to record the version.

## 0.1.0

- Add Rails request middleware, a controller concern, mountable error pages and a Rack exception app.
- Support HTML and JSON errors, API-only applications and optional Apipie validation.
- Provide a migration mode for applications using feedmob-rescue 0.1.7.
