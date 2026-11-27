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

| Request or exception | Default response |
| --- | --- |
| Malformed nested query | 400 |
| HTTP method unrecognized by Rails | 405 JSON |
| Unsupported controller format or missing template | 404 |
| Invalid cross-origin script request | 403 |
| Apipie missing or invalid parameter | 422 |

HTML applications render error pages by default. Clients can request JSON with `Accept: application/json`. API-only applications default to JSON. HEAD requests return the status and headers with an empty body. The middleware is installed automatically. Apipie integration is available when the host loads `apipie-rails`.

Development re-raises handled controller exceptions for debugging. Cross-origin script exceptions also propagate in the test environment.

## Migrate from feedmob-rescue 0.1.7

1. Replace the old Gemfile entry and change `include Feedmob::Rescue` to `include RequestRescue::Controller`.
2. Replace the old engine with `RequestRescue::Engine` at the same mount path and name it `request_rescue`. Existing root mounts can continue using `at: "/"`. Keep the application's Apipie dependency if its controllers use Apipie.
3. Set `config.request_rescue.legacy_responses = true` in the application configuration to preserve the previous redirects and empty 200 response to cross-origin script requests in production.

Migration mode redirects missing templates and unknown formats to the mounted `not_found` page and Apipie errors to `invalid_params`. The mounted pages return 200 in this mode. Existing root mounts can keep `config.exceptions_app = self.routes` for their numeric 404 and 500 routes. To preserve the original HTTP error status regardless of the mount path, use `RequestRescue::ExceptionsApp`. After clients can consume direct 404, 403 and 422 responses, disable migration mode. Rolling back requires restoring the old Gemfile entry, concern, engine and exception app together.

## Verify a package locally

Run the verifier under the Ruby version for the selected Rails and Rack pair.

```sh
RBENV_VERSION=3.0.3 APIPIE_VERSION=0.8.1 rbenv exec ruby bin/verify 6.1.5 2.2.4
```

The verifier builds and installs the gem into a temporary directory, boots a Rails host and exercises its full Rack stack. It writes a package, dependency lockfile and JSON request results with the package SHA-256 under `pkg/`. Omit `APIPIE_VERSION` to verify installation without the optional adapter. Set `VERIFY_PACKAGE` to an existing build to test the same bytes across runtimes. Set `VERIFY_LOCK` to a previous result’s lockfile to replay its dependency resolution. See the [compatibility matrix](https://github.com/feed-mob/request-rescue/blob/main/PLAN.md) for the seven targeted Ruby/Rails pairs and their Rack versions.

## Releases

Every pull request runs the compatibility matrix. The **All request tests passed** check is required to merge.

To publish, open **Actions → Publish gem to RubyGems → Run workflow**, select `main`, and click **Run workflow**. The workflow builds the next patch version (for example, `0.1.0` → `0.1.1`), tests the same gem across the full matrix, and pushes it to RubyGems using trusted publishing.

After RubyGems accepts the package, the workflow tags the versioned source commit (for example, `v0.1.1`) and opens a PR to bring that commit into `main`. Approve the PR's CI run if GitHub prompts, then merge the version update before starting the next release. If recording the release fails after upload, rerun the failed jobs in the original run. When the publish job is retried, it checks the published SHA-256 against the tested package before proceeding.

## License

[MIT](LICENSE.txt).
