# frozen_string_literal: true

# The gem is named solanum-rb, so `require "solanum/rb"` is its conventional
# entry point. It carries the version constant and nothing else: the
# application lives under `SolanumRb` and is loaded by `lib/solanum_rb.rb`,
# which pulls in GTK — more than a version lookup should cost.
require_relative "rb/version"
