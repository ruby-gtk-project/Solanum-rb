# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative 'i18n'
require_relative 'settings'
require_relative 'shortcuts_dialog'
require_relative 'sound'
require_relative 'timer'

module SolanumRb
  # The one window: a lap label, a countdown, and the three controls under it.
  # Upstream builds this from `window.blp`; here the same tree is assembled in
  # `build`, and the breakpoint, the window actions and the primary menu are
  # wired up the same way.
  class Window
    include I18n

    APP_ID = 'org.gnome.Solanum.Rb'
    POMODORO = :pomodoro
    BREAK = :break

    attr_reader :application

    def initialize(application)
      @application = application
      @pomodoro_count = 1
      @lap_type = POMODORO
    end

    def build
      window.tap do |win|
        win.content = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = main_box

          main_box.tap do |box|
            box.append(lap_label)
            box.append(timer_label)
            box.append(center_box)

            center_box.tap do |center|
              center.center_widget = button_box
              center.end_widget = menu_button

              button_box.tap do |buttons|
                buttons.append(timer_button)
                buttons.append(skip_button)
              end
            end
          end
        end

        win.add_breakpoint(large_text_breakpoint)
        install_actions
        start_lap(POMODORO, reset_count: true)
        # Building the pipeline scans the GStreamer plugin registry, which
        # takes hundreds of milliseconds warm and seconds cold. Doing it here
        # spends that at startup instead of freezing the first press of Start.
        sound
      end
    end

    def present = window.present

    # Whether the window has the keyboard focus, which decides whether a lap
    # change gets a notification. Upstream reads `is_active`.
    def active? = window.active?

    # --- actions -----------------------------------------------------------

    def install_actions
      window.add_action(action('toggle-timer') { toggle_timer })
      window.add_action(action('reset') { reset })
      window.add_action(action('skip') { skip })
      window.add_action(action('show-help-overlay') { show_shortcuts })
    end

    def action(name, &handler)
      Gio::SimpleAction.new(name).tap do |simple|
        simple.signal_connect('activate') { handler.call }
      end
    end

    def set_action_enabled(name, enabled)
      window.lookup_action(name).enabled = enabled
    end

    # --- lap state ---------------------------------------------------------

    # Upstream splits this between `update_lap` and `next_lap`; the count and
    # the label move together, so they live in one place here.
    def start_lap(lap_type, reset_count: false)
      @lap_type = lap_type

      case reset_count
      when true then @pomodoro_count = 1
      end

      case lap_type
      when POMODORO then start_pomodoro
      else start_break
      end
    end

    def start_pomodoro
      update_lap_label
      set_length(settings['lap-length'])
    end

    # The long break lands on the configured session count, and closes the
    # set: the next pomodoro is lap 1 again.
    def start_break
      long = @pomodoro_count >= settings['sessions-until-long-break']

      case long
      when true then begin_long_break
      else begin_short_break
      end
    end

    def begin_long_break
      @pomodoro_count = 1
      lap_label.label = _('Long Break')
      set_length(settings['long-break-length'])
    end

    def begin_short_break
      @pomodoro_count += 1
      lap_label.label = _('Short Break')
      set_length(settings['short-break-length'])
    end

    def set_length(minutes)
      timer.duration = minutes
      set_timer_label(minutes * 60)
    end

    def next_lap_type
      case @lap_type
      when POMODORO then BREAK
      else POMODORO
      end
    end

    # Advance a lap. `notify` is false for the skip button — a lap the user
    # asked for needs no notification.
    def next_lap(notify)
      next_lap_type.tap do |lap_type|
        start_lap(lap_type)

        case notify
        when true then send_notification(lap_type)
        end
      end
    end

    def skip
      next_lap(false)

      case active?
      when false then present
      end
    end

    # --- the timer ---------------------------------------------------------

    def toggle_timer
      case timer.running?
      when true then pause_timer
      else run_timer
      end
    end

    def run_timer
      application.withdraw_notification('timer-notif')
      timer.start
      sound.play(Sound::BEEP)
      timer_button.icon_name = 'media-playback-pause-symbolic'
      timer_label.remove_css_class('blinking')
      timer_button.remove_css_class('suggested-action')
      apply_fullscreen
      # Skipping and resetting are only offered while the timer is paused.
      set_action_enabled('skip', false)
      set_action_enabled('reset', false)
    end

    def pause_timer
      timer.stop
      timer_button.icon_name = 'media-playback-start-symbolic'
      timer_label.add_css_class('blinking')
      timer_button.add_css_class('suggested-action')
      set_action_enabled('skip', true)
      set_action_enabled('reset', true)
    end

    # Breaks can take over the screen, so the break is hard to ignore.
    def apply_fullscreen
      case settings['fullscreen-break']
      when false then nil
      else fullscreen_for_lap
      end
    end

    def fullscreen_for_lap
      case @lap_type
      when BREAK then window.fullscreen
      else window.unfullscreen
      end
    end

    def reset
      pause_timer
      start_lap(POMODORO, reset_count: true)
    end

    def on_countdown(minutes, seconds)
      timer_label.label = clock(minutes, seconds)
    end

    # The lap ran out: stop the timer the way the pause button would, then
    # move on and tell the user about it.
    def on_lap
      pause_timer
      next_lap(true)
    end

    # --- labels ------------------------------------------------------------

    def update_lap_label
      # Translators: Every pomodoro session can range from 1-99 laps, so {}
      # will contain a number between 1 and 99. Lap is always singular.
      lap_label.label = f_('Lap {}', @pomodoro_count)
    end

    def set_timer_label(seconds)
      timer_label.label = clock(seconds / 60, seconds % 60)
    end

    # U+2236 RATIO, as upstream uses, so the colon sits on the digits' centre.
    def clock(minutes, seconds) = format('%<m>02d∶%<s>02d', m: minutes, s: seconds)

    # --- notifications -----------------------------------------------------

    # Only worth sending when the user is looking elsewhere; the chime plays
    # either way.
    def send_notification(lap_type)
      case active?
      when false then post_notification(lap_type)
      end

      sound.play(Sound::CHIME)
    end

    def post_notification(lap_type)
      application.send_notification('timer-notif', notification(lap_type))
    end

    def notification(lap_type)
      notification_text(lap_type).then do |title, body, button|
        Gio::Notification.new(_('Solanum')).tap do |notif|
          notif.title = title
          notif.body = body
          notif.priority = :urgent
          notif.add_button(button, 'app.toggle-timer')
          notif.add_button(_('Skip'), 'app.skip')
        end
      end
    end

    def notification_text(lap_type)
      case lap_type
      when POMODORO
        [_('Back to Work'), _('Ready to keep working?'), _('Start Working')]
      else
        [_('Break Time'), _('Stretch your legs, and drink some water.'), _('Start Break')]
      end
    end

    # --- dialogs -----------------------------------------------------------

    def show_shortcuts
      ShortcutsDialog.new.build.present(window)
    end

    # --- the widget tree ---------------------------------------------------

    def window
      @window ||= Adwaita::ApplicationWindow.new(application).tap do |win|
        win.title = _('Solanum')
        win.icon_name = APP_ID
        win.set_default_size(360, 360)
        win.height_request = 294
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.show_title = false
      end
    end

    def main_box
      @main_box ||= Gtk::Box.new(:vertical, 6).tap do |box|
        box.valign = :center
        box.vexpand = true
        box.add_css_class('main-box')
      end
    end

    def lap_label
      @lap_label ||= Gtk::Label.new.tap do |label|
        label.add_css_class('heading')
        label.add_css_class('dim-label')
      end
    end

    def timer_label
      @timer_label ||= Gtk::Label.new.tap do |label|
        # Left-to-right even under an RTL locale: a countdown is a number,
        # not a sentence.
        label.direction = :ltr
        label.add_css_class('timer-label')
        label.add_css_class('accent')
        label.add_css_class('blinking')
      end
    end

    def center_box
      @center_box ||= Gtk::CenterBox.new.tap do |center|
        center.margin_bottom = 48
        center.halign = :center
      end
    end

    def button_box
      @button_box ||= Gtk::Box.new(:horizontal, 12).tap do |box|
        box.halign = :center
      end
    end

    def timer_button
      @timer_button ||= Gtk::Button.new.tap do |button|
        button.tooltip_text = _('Toggle Timer')
        button.icon_name = 'media-playback-start-symbolic'
        button.action_name = 'win.toggle-timer'
        button.valign = :center
        button.add_css_class('circular')
        button.add_css_class('large')
        button.add_css_class('suggested-action')
      end
    end

    def skip_button
      @skip_button ||= Gtk::Button.new.tap do |button|
        button.tooltip_text = _('Skip')
        button.icon_name = 'media-seek-forward-symbolic'
        button.action_name = 'win.skip'
        button.valign = :center
        button.add_css_class('circular')
        button.add_css_class('large')
      end
    end

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.primary = true
        button.tooltip_text = _('Main Menu')
        button.menu_model = app_menu
        button.icon_name = 'open-menu-symbolic'
        button.halign = :end
        button.valign = :center
        button.margin_start = 12
        button.add_css_class('circular')
      end
    end

    def app_menu
      @app_menu ||= Gio::Menu.new.tap do |menu|
        menu.append_section(nil, reset_section)
        menu.append_section(nil, about_section)
      end
    end

    def reset_section
      @reset_section ||= Gio::Menu.new.tap do |section|
        section.append(_('Reset Sessions'), 'win.reset')
      end
    end

    def about_section
      @about_section ||= Gio::Menu.new.tap do |section|
        section.append(_('_Preferences'), 'app.preferences')
        section.append(_('_Keyboard Shortcuts'), 'win.show-help-overlay')
        section.append(_('_About Solanum'), 'app.about')
      end
    end

    # On a large window the countdown grows and the lap label grows with it.
    def large_text_breakpoint
      @large_text_breakpoint ||= Adwaita::Breakpoint.new(large_text_condition).tap do |bp|
        bp.signal_connect('apply') { apply_large_text }
        bp.signal_connect('unapply') { unapply_large_text }
      end
    end

    def large_text_condition
      Adwaita::BreakpointCondition.parse('min-width: 800sp and min-height: 800sp')
    end

    def apply_large_text
      timer_label.add_css_class('large-timer')
      lap_label.remove_css_class('heading')
      lap_label.add_css_class('title-4')
    end

    def unapply_large_text
      timer_label.remove_css_class('large-timer')
      lap_label.remove_css_class('title-4')
      lap_label.add_css_class('heading')
    end

    def timer
      @timer ||= Timer.new(
        on_countdown: method(:on_countdown),
        on_lap:       method(:on_lap),
      )
    end

    def sound = @sound ||= Sound.new

    def settings = Settings.gsettings
  end
end
