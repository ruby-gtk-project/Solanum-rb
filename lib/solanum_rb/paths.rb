# frozen_string_literal: true

module SolanumRb
  # Where the non-Ruby files live. Upstream compiled these into a GResource;
  # this port reads them off disk, so every consumer goes through here.
  module Paths
    module_function

    def data_dir = File.expand_path('../../data', __dir__)

    def sound(name) = File.join(data_dir, 'sounds', name)

    def icon_dir = File.join(data_dir, 'icons')

    def stylesheet = File.join(data_dir, 'style.css')

    def po_dir = File.expand_path('../../po', __dir__)

    # Where `rake desktop` writes the generated desktop entry and metainfo.
    # The nix build installs them and points this at the install prefix, so
    # both a checkout and an installed copy find the same files.
    def generated(name) = File.join(generated_dir, name)

    def generated_dir = ENV.fetch('SOLANUM_RB_GENERATED_DIR', default_generated_dir)

    def default_generated_dir = File.expand_path('../../build/generated', __dir__)
  end
end
