# frozen_string_literal: true

source "https://rubygems.org"

# libadwaita bindings; pulls in gtk4, glib2, cairo and friends.
gem "adwaita", "~> 4.3"
gem "gem_kit"
# The chime and the beep. Upstream uses GstPlay; nixpkgs' gtk4 ships no
# GtkMediaFile backend, so Gtk::MediaFile would play silence.
gem "gstreamer", "~> 4.3"

group :development, :test do
  gem "rake", "~> 13.0"
  gem "rubocop"
end
