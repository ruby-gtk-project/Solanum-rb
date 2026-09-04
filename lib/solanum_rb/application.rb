# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative 'about_dialog'
require_relative 'i18n'
require_relative 'paths'
require_relative 'preferences_dialog'
require_relative 'window'

module SolanumRb
  # The application: one window, the app-level actions, and the accelerators.
  # Upstream loads its stylesheet and icons from a GResource; this port
  # registers the same files from `data/` instead.
  class Application
    include I18n

    APP_ID = Window::APP_ID

    def build
      app.tap do |a|
        a.signal_connect('startup') do
          # Without this libadwaita never loads its stylesheet, so `accent`,
          # `circular` and the Adwaita colour scheme all silently do nothing.
          # AdwApplication would have done it; a Gtk::Application does not.
          Adwaita.init

          register_icons
          load_stylesheet
          install_actions

          a.set_accels_for_action('app.preferences', ['<Primary>comma'])
          a.set_accels_for_action('app.quit', ['<Primary>q'])
          # GtkApplicationWindow would have bound this for a help overlay set
          # through `set_help_overlay`; AdwShortcutsDialog has no such hook,
          # so the conventional accelerator is registered by hand.
          a.set_accels_for_action('win.show-help-overlay', ['<Primary>question'])

          main_window.build
        end

        a.signal_connect('activate') { main_window.present }
      end
    end

    def run = app.run([])

    # One window only: re-activating the app raises the existing one.
    def main_window = @main_window ||= Window.new(app)

    def register_icons
      Gtk::IconTheme.get_for_display(Gdk::Display.default)
                    .add_search_path(Paths.icon_dir)
    end

    def load_stylesheet
      Gtk::StyleContext.add_provider_for_display(
        Gdk::Display.default,
        css_provider,
        Gtk::StyleProvider::PRIORITY_APPLICATION,
      )
    end

    # `toggle-timer` and `skip` exist at app level so the timer notification's
    # buttons can reach them: a notification action has to be `app.`-scoped.
    def install_actions
      app.add_action(action('about') { show_about })
      app.add_action(action('preferences') { show_preferences })
      app.add_action(action('quit') { app.quit })
      app.add_action(action('toggle-timer') { main_window.toggle_timer })
      app.add_action(action('skip') { main_window.skip })
    end

    def action(name, &handler)
      Gio::SimpleAction.new(name).tap do |simple|
        simple.signal_connect('activate') { handler.call }
      end
    end

    def show_about
      AboutDialog.new.build.present(main_window.window)
    end

    def show_preferences
      PreferencesDialog.new.build.present(main_window.window)
    end

    def app
      @app ||= Gtk::Application.new(APP_ID, :default_flags).tap do |a|
        a.resource_base_path = '/org/gnome/Solanum/Rb'
      end
    end

    def css_provider
      @css_provider ||= Gtk::CssProvider.new.tap do |provider|
        provider.load(data: File.read(Paths.stylesheet))
      end
    end
  end
end
