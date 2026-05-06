#!/usr/bin/env ruby
# frozen_string_literal: true

# DHI distroless ランタイム用の Puma 起動ランチャ。
# distroless には shell も `bundle` バイナリも含まれないため、
# `CMD ["bundle", "exec", "puma", ...]` は `executable file not found in $PATH` で
# 失敗する。`ruby bin/start.rb` を CMD にして直接 Puma を起動する。
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)
require "bundler/setup"
require "puma/cli"

Puma::CLI.new(["-C", "config/puma.rb"]).run
