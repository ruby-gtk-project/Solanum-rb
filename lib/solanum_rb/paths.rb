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
  end
end
