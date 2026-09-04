# frozen_string_literal: true

# The development profile, which upstream selects with -Dprofile=development.
# It needs its own process: the profile is read from the environment when the
# application id is first asked for, and a Gtk::Application keeps the id it
# was built with.

require 'tmpdir'

ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir
ENV['GSETTINGS_BACKEND'] = 'memory'
ENV['SOLANUM_RB_PROFILE'] = 'development'
ENV['SOLANUM_RB_GENERATED_DIR'] = File.expand_path('../build/generated', __dir__)
%w[LANGUAGE LC_ALL LC_MESSAGES LANG].each { |var| ENV[var] = 'C' }

require_relative '../lib/solanum_rb'
require_relative 'gtk_driver'

app = SolanumRb::Application.new
win = nil

GtkDriver.drive(app, shots: 'tmp/shots') do |d, _|
  d.window { app.main_window.window }

  d.step('the devel window builds') do
    win = app.main_window

    d.check('the application id is suffixed') do
      app.app.application_id == 'org.gnome.Solanum.Rb.Devel'
    end
    d.check('the window is striped') { win.window.has_css_class?('devel') }
    d.check('and carries the devel icon') do
      win.window.icon_name == 'org.gnome.Solanum.Rb.Devel'
    end
    d.check('the timer still works') { win.timer_label.label == '25∶00' }
    d.shot('12-devel')
  end

  d.step('opening the devel about dialog') do
    app.app.activate_action('about', nil)
  end

  d.step('the about dialog reports the commit') do
    win.window.visible_dialog.then do |about|
      d.check('a dialog is showing') { !about.nil? }
      d.check('the version carries a suffix') { about.version.start_with?('6.0.0-') }
      d.check('the icon is the devel one') do
        about.application_icon == 'org.gnome.Solanum.Rb.Devel'
      end
    end
    d.shot('13-devel-about')
  end

  d.step('closing it') do
    win.window.visible_dialog&.close
  end
end
