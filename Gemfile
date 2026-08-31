source "https://rubygems.org"

# GitHub Pages dependency set. Upgrade with: bundle update github-pages
gem "github-pages", "~> 232", group: :jekyll_plugins

# Transitive security pins (Dependabot). Relax when github-pages pulls these in.
gem "activesupport", ">= 8.1.2.1"
gem "addressable", ">= 2.9.0"
gem "concurrent-ruby", ">= 1.3.7"
gem "faraday", ">= 2.14.3"
gem "json", ">= 2.19.2"
gem "nokogiri", ">= 1.19.4"

group :jekyll_plugins do
  gem "jekyll-feed", "~> 0.17"
  gem "jekyll-remote-theme"
end

platforms :mingw, :x64_mingw, :mswin, :jruby do
  gem "tzinfo", ">= 1", "< 3"
  gem "tzinfo-data"
end

gem "wdm", "~> 0.1.1", platforms: [:mingw, :x64_mingw, :mswin]

gem "http_parser.rb", "~> 0.6.0", platforms: [:jruby]

gem "webrick", "~> 1.8"
