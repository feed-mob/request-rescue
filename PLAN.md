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

GitHub Actions runs the same matrix. On the initial commit, 10 jobs passed. The Rails 7.1.3.4 job with Apipie 1.4.0 returned HTTP 500 on its first request. A passing CI run, a migration trial in a downstream application, and publication to RubyGems are still pending. [Initial CI run](https://github.com/feed-mob/request-rescue/actions/runs/45925696603)
