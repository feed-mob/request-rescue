# Request Rescue

Request Rescue gives Rails applications consistent error responses for malformed queries, unrecognized HTTP methods, missing templates, unsupported formats and invalid Apipie parameters. A controller concern handles exceptions raised in your actions. The Rails engine provides mountable HTML and JSON error pages.

## Install

Add `gem "request-rescue"` to your Gemfile and run `bundle install`. To try a local checkout, use `gem "request-rescue", path: "/path/to/request-rescue"`.

Include the concern in controllers where you want to handle these exceptions. It also works with `ActionController::API`.

```ruby
class ApplicationController < ActionController::Base
  include RequestRescue::Controller
end
```

Mount the pages in the application's routes. The mount name is used by migration redirects.

```ruby
Rails.application.routes.draw do
  mount RequestRescue::Engine, at: "/errors", as: :request_rescue
end
```

To render unhandled exceptions through Request Rescue, set the exception app in environments that show public error pages. Rails determines their HTTP status. A raised application exception produces a generic 500 response.

```ruby
# config/environments/production.rb
config.exceptions_app = RequestRescue::ExceptionsApp
```

## Responses

| Request or exception | Default in production | With `legacy_responses = true` |
| --- | --- | --- |
| Conflicting nested query parameter types | 400 | 400 |
| HTTP method unrecognized by Rails | 405 JSON | 405 JSON with `{"errors":["Method not allowed"]}` |
| Unsupported controller format or missing template | 404 | 302 to the mounted `not_found` page |
| Invalid cross-origin JavaScript request | 403 | Empty 200 |
| Missing or invalid Apipie parameter | 422 | 302 to the mounted `invalid_params` page |
| Mounted `/not_found`, `/invalid_params`, `/404`, `/500` | 404, 422, 404, 500 respectively | 200 with the corresponding error page |

HTML applications render error pages by default. Clients can request JSON with `Accept: application/json`. API-only applications default to JSON. HEAD requests return the status and headers with an empty body. The middleware is installed automatically. Apipie integration is available when the host loads `apipie-rails`.

Development re-raises handled controller exceptions for debugging. Cross-origin script exceptions also propagate in the test environment.

## Migrate from feedmob-rescue 0.1.7

1. Replace the old Gemfile entry and change `include Feedmob::Rescue` to `include RequestRescue::Controller`.
2. Replace the old engine with `RequestRescue::Engine` at the same mount path and name it `request_rescue`. Existing root mounts can continue using `at: "/"`. Keep the application's Apipie dependency if its controllers use Apipie.
3. Set `config.request_rescue.legacy_responses = true` in the application configuration to preserve the previous redirects and empty 200 response to cross-origin script requests in production.

Existing root mounts can keep `config.exceptions_app = self.routes` for their numeric 404 and 500 routes. Both routes accept all HTTP verbs recognized by Rails. To preserve the original HTTP error status regardless of the mount path, use `RequestRescue::ExceptionsApp`.

Check these differences when testing a migration.

- The old engine rendered ERB views through the host's `ApplicationController`. The new engine serves standalone Rack responses. Check any error-page branding, layout overrides or controller callbacks your application relies on.
- Migration mode validates the encoding of query values before routing. In version 0.1.3, a mounted page that ignores its query can return 200 for invalid UTF-8. See the [changelog](CHANGELOG.md) for the correction. With migration mode off, Rails can apply per-action parameter encodings.
- The new middleware returns 400 for conflicting nested parameter types. On the Rails 6.1 migration baseline the old middleware let the Rack parsing exception propagate. The new method check also requires the verb casing Rails recognizes.

Before switching a production application, exercise its error routes, an Apipie endpoint if applicable, and any clients that follow redirects. Once clients can consume direct 404, 403 and 422 responses, disable migration mode. To roll back, restore the old gem and lockfile, concern, engine and exception app together.

## Verify a package locally

Run the verifier under the Ruby version for the selected Rails and Rack pair.

```sh
RBENV_VERSION=3.0.3 APIPIE_VERSION=0.8.1 rbenv exec ruby bin/verify 6.1.5 2.2.4
```

The verifier builds and installs the gem into a temporary directory, boots a Rails host and exercises its full Rack stack. It writes a package, dependency lockfile and JSON request results with the package SHA-256 under `pkg/`. Omit `APIPIE_VERSION` to verify installation without the optional adapter. Set `VERIFY_PACKAGE` to an existing build to test the same bytes across runtimes. Set `VERIFY_LOCK` to a previous result’s lockfile to replay its dependency resolution. See the [compatibility matrix](https://github.com/feed-mob/request-rescue/blob/main/PLAN.md) for the seven targeted Ruby/Rails pairs and their Rack versions.

## Releases

Open **Actions → Publish gem to RubyGems → Run workflow**. Choose **patch**, **minor** or **major** under **Version increment**. The workflow calculates the target from the version in the selected branch. Leave **Publish to RubyGems** unchecked to build and test the package. To publish it, select `main` and check the box.

For one-time setup, install a dedicated GitHub App on this repository with **Contents: Read-only** and **Pull requests: Read and write**. In the repository's `release` environment, set the variable `RELEASE_APP_CLIENT_ID` to its client ID and the secret `RELEASE_APP_PRIVATE_KEY` to its PEM private key. The publish job checks that GitHub can issue a token with those permissions before uploading the gem.

After publishing, the workflow tags the source, opens the version update PR using the App. The resulting `pull_request` event starts the required **All request tests passed** check on that PR. Merge the PR before the next release.

For a version-only update, CI verifies the tag, the version change and the published RubyGems version. Other changes and release candidates run the full compatibility matrix. If recording the release fails after upload, rerun the failed jobs in the original run.

Each published tag has a [GitHub Release](https://github.com/feed-mob/request-rescue/releases) with release notes, the verified gem and its SHA-256, and source code archives in ZIP and tar.gz formats. To include a short user-facing summary, add a `## X.Y.Z` section to `CHANGELOG.md` before starting the release. GitHub also generates notes from merged pull requests.

## License

[MIT](LICENSE.txt).
