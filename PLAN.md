# Request Rescue release plan

Package `request-rescue` as a Ruby gem for handling malformed Rails requests and rendering error pages. The first release should let applications migrate from `feedmob-rescue 0.1.7`, verify their responses, and roll back on their existing Ruby, Rails, and Rack versions.

## Compatibility targets

The default branches of 19 non-archived downstream repositories pin `feedmob-rescue 0.1.7`. Their lockfiles give us seven Ruby/Rails pairs. Accounting for the different Rack versions gives us nine combinations to verify.

| Ruby | Rails | Rack versions in downstream lockfiles | Projects |
| --- | --- | --- | ---: |
| 3.0.3 | 6.1.5 | 2.2.4 | 1 |
| 3.1.3 | 6.1.5 | 2.2.3 | 1 |
| 3.1.3 | 6.1.7.6 | 2.2.8 | 4 |
| 3.1.4 | 6.1.7.6 | 2.2.8, 2.2.9, 2.2.21 | 10 |
| 3.1.6 | 6.1.7.6 | 2.2.8 | 1 |
| 3.2.9 | 6.1.7.6 | 2.2.9 | 1 |
| 3.2.2 | 7.1.3.4 | 3.1.7 | 1 |

One downstream application has proposed upgrading to Ruby 3.1.4 and Rails 6.1.7.10. Update the matrix when that change lands on its default branch.

## Implementation and acceptance

1. **Capture the migration baseline.** Send requests through a minimal Rails application running `feedmob-rescue 0.1.7`. Record the status, content type, body, redirect location, and exceptions that propagate in development. Cover successful requests, unrecognized methods, malformed queries, unsupported formats, missing templates, invalid cross-origin script requests, Apipie parameter errors, and requests to the error pages themselves.
2. **Implement the gem.** Use Rack middleware to validate methods and query parameters. Provide a Rails controller concern, a mountable error-page engine, and an optional `exceptions_app`. Handle Apipie errors when the host loads Apipie. Return error statuses directly by default and offer an explicit migration mode for legacy redirects and responses. Use relative links on error pages, handle only the specified exceptions, and pass successful responses through unchanged.
3. **Test the installed package.** Build the gem from its gemspec and boot the test host from the installed package. Start with Ruby 3.0.3 / Rails 6.1.5, Ruby 3.1.4 / Rails 6.1.7.6, and Ruby 3.2.2 / Rails 7.1.3.4. Exercise real routes, controllers, and exception middleware in HTML and API-only applications. Check 400, 403, 404, 405, 422, and 500 responses, HEAD requests, JSON, and redirects at both root and custom mount paths. Before release, run every row and Rack version in the matrix, including hosts with and without Apipie. Use a container with a pinned toolchain where needed. Save the package checksum, dependency lockfile, verification command, and request results. Rehearse migration in an existing application on its current framework versions.
4. **Prepare the RubyGems release.** Target version `0.1.0`. Start from a clean repository, list the files to package, retain the MIT notice for reused code, and write public installation and migration examples in English. Set the source, changelog, and publishing URLs in the gemspec. Inspect the built package and follow the README installation steps in an isolated environment. Once the matrix passes and the gem name is confirmed, configure a pending trusted publisher so GitHub Actions can publish new versions from the verified main branch using OIDC. [RubyGems publishing guide](https://guides.rubygems.org/publishing/) · [Trusted Publishing](https://guides.rubygems.org/trusted-publishing/)

## Release candidate verification

On November 27, 2026, all nine Ruby/Rails/Rack combinations passed locally using the same `0.1.0` package. Across Apipie versions and a host without Apipie, 11 environments passed 737 request assertions. The migration baseline also ran against the old gem on Rails 6.1.7.6. The local report is in `pkg/verification.md`.

The v0.1.3 release passed the GitHub Actions compatibility matrix and was published to RubyGems. The Rails 7.1 / Apipie 1.4.0 test host uses the downstream RDoc 6.7.0 dependency. [Release verification](https://github.com/feed-mob/request-rescue/actions/runs/45936731347) · [Published gem](https://rubygems.org/gems/request-rescue/versions/0.1.3)

## Migration verification

The comparison uses the downstream `feedmob-rescue 0.1.7` revision `c14dcde21bcaedd3f2d033342b3102a521cb4d69` and a packaged Request Rescue in the same Rails host. The old gem runs with its root-mounted engine and `config.exceptions_app = routes`. The new gem also runs with a custom mount, direct error responses and an API-only host.

| Legacy component | What the Rails host verifies |
| --- | --- |
| Request middleware position | GET, POST and HEAD reach the host. An unknown method returns 405 with the original JSON error. Both gems reject unknown methods and malformed queries before middleware the application adds, and check the query first. |
| Query validation | Invalid UTF-8 in scalar and nested values returns 400 in migration mode, even on a mounted page. Valid UTF-8 reaches the page. This comparison caught a regression in v0.1.3. |
| Controller concern | Unknown formats and missing templates, including a template that exists only as HTML, redirect to `not_found`. Missing and invalid Apipie parameters redirect to `invalid_params`. All four exceptions propagate in development. |
| Cross-origin JavaScript | A non-XHR script request raises in development and test. In production, migration mode returns an empty 200 and a valid XHR receives the script. |
| Error engine and exception routing | Both named pages render. The numeric routes handle non-GET requests and HEAD. With the old root-mount configuration, a routing miss and an application exception render the 404 and 500 pages with status 200, and a 400 from `params.require` has an empty body. In migration mode with `RequestRescue::ExceptionsApp`, the same requests return 404, 500 and a 400 page. |
| JSON requests in migration mode | Controllers redirect unsupported formats to `not_found` in both gems. The old pages, routing misses and application exceptions redirect JSON requests to `/not_found`, which redirects to itself. The new pages return status 200 with a JSON error. |

To repeat the side-by-side check, point `BASELINE_GEM` at a clean checkout of the legacy revision. Run both commands from this repository:

```sh
export RBENV_VERSION=3.2.9 APIPIE_VERSION=0.8.1
BASELINE_GEM="$PWD/../feedmob-rescue" rbenv exec ruby bin/verify 6.1.7.6 2.2.9
rbenv exec ruby bin/verify 6.1.7.6 2.2.9
```

Each run writes its request assertions and lockfile to a separate directory under `pkg/`. The new gem's results also include its package checksum. The shared host verifies the gem's request behavior. A migration rehearsal with a downstream application's own middleware, layouts, callbacks and routes is still pending. See the [migration guide](README.md#migrate-from-feedmob-rescue-017) for application-specific checks.
