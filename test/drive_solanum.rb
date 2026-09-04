# frozen_string_literal: true

# Builds the real window headlessly and drives it through every state and
# every dialog. Screenshots land in tmp/shots.

require 'tmpdir'

# Never read or scribble on the real settings.
ENV['XDG_CONFIG_HOME'] = Dir.mktmpdir
ENV['GSETTINGS_BACKEND'] = 'memory'
%w[LANGUAGE LC_ALL LC_MESSAGES LANG].each { |var| ENV[var] = 'C' }

require_relative '../lib/solanum_rb'
require_relative 'gtk_driver'

# A resize is not applied on the turn it is asked for, and after the fullscreen
# round trip it can take several. Pumping the main context until the window
# reports the size makes the breakpoint steps deterministic instead of
# depending on how much a single 500ms tick happened to get through.
def settle_until(limit = 200)
  limit.times do
    case yield
    when true then break
    else GLib::MainContext.default.iteration(false)
    end
  end
end

app = SolanumRb::Application.new
win = nil
settings = nil
small_timer_height = nil

GtkDriver.drive(app, shots: 'tmp/shots') do |d, _|
  d.window { app.main_window.window }

  d.step('the window builds in the stopped state') do
    win = app.main_window
    settings = SolanumRb::Settings.gsettings

    d.check('lap label reads Lap 1') { win.lap_label.label == 'Lap 1' }
    d.check('the countdown reads 25:00') { win.timer_label.label == '25∶00' }
    d.check('the timer is stopped') { !win.timer.running? }
    d.check('the button offers to start') do
      win.timer_button.icon_name == 'media-playback-start-symbolic'
    end
    d.check('the countdown blinks while stopped') do
      win.timer_label.has_css_class?('blinking')
    end
    d.check('the start button is suggested') do
      win.timer_button.has_css_class?('suggested-action')
    end
    d.check('skip is available while stopped') { win.window.lookup_action('skip').enabled? }
    # Upstream's `default-widget: timer_button` — Enter starts the countdown.
    d.check('the timer button is the default widget') do
      win.window.default_widget == win.timer_button
    end
    d.check('a release build is not striped') { !win.window.has_css_class?('devel') }
    d.check('the window carries the application icon') do
      win.window.icon_name == 'org.gnome.Solanum.Rb'
    end
    # Baseline for the breakpoint check further down.
    small_timer_height = win.timer_label.measure(:vertical, -1)[1]
    d.check('the countdown has a height to compare against') { small_timer_height.positive? }
    d.shot('01-stopped')
  end

  d.step('the primary menu has upstream\'s three items plus reset') do
    d.check('two sections') { win.app_menu.n_items == 2 }
    d.check('reset sits alone in the first') { win.reset_section.n_items == 1 }
    d.check('preferences, shortcuts and about in the second') { win.about_section.n_items == 3 }
    d.check('the menu button is primary') { win.menu_button.primary? }
  end

  d.step('starting the timer') do
    win.timer_button.activate
  end

  d.step('the running state') do
    d.check('the timer runs') { win.timer.running? }
    d.check('the button offers to pause') do
      win.timer_button.icon_name == 'media-playback-pause-symbolic'
    end
    d.check('the countdown stops blinking') { !win.timer_label.has_css_class?('blinking') }
    d.check('the button drops the suggestion') do
      !win.timer_button.has_css_class?('suggested-action')
    end
    d.check('skip is refused while running') { !win.window.lookup_action('skip').enabled? }
    d.check('reset is refused while running') { !win.window.lookup_action('reset').enabled? }
    d.check('the countdown has moved off 25:00') { win.timer_label.label != '25∶00' }
    d.shot('02-running')
  end

  d.step('pausing again') do
    win.timer_button.activate
  end

  d.step('the paused state') do
    d.check('the timer is stopped') { !win.timer.running? }
    d.check('the button offers to start') do
      win.timer_button.icon_name == 'media-playback-start-symbolic'
    end
    d.check('the countdown blinks again') { win.timer_label.has_css_class?('blinking') }
    d.check('skip is offered again') { win.window.lookup_action('skip').enabled? }
    d.check('a pause keeps the time already spent') { win.timer.remaining < 1500 }
    d.shot('03-paused')
  end

  d.step('skipping into the first break') do
    win.skip_button.activate
  end

  d.step('the first break is a short one') do
    d.check('the lap label reads Short Break') { win.lap_label.label == 'Short Break' }
    d.check('the countdown is the 5 minute short break') { win.timer_label.label == '05∶00' }
    d.shot('04-short-break')
  end

  d.step('skipping back into lap 2') do
    win.skip_button.activate
  end

  d.step('the second pomodoro') do
    d.check('the lap counter advanced') { win.lap_label.label == 'Lap 2' }
    d.check('the countdown is a full lap again') { win.timer_label.label == '25∶00' }
  end

  # Four sessions per set by default: laps 2 and 3 take short breaks, and the
  # break after lap 4 is the long one — five more skips from here.
  #
  # Gtk::Button#activate runs the button's press animation and only emits
  # `clicked` on a later turn of the loop, so several in one step collapse into
  # one. The button wiring is covered by the single-skip steps above; from here
  # on the action is activated directly.
  d.step('running out the rest of the set') do
    5.times { win.window.activate_action('skip', nil) }
  end

  d.step('the fourth break is the long one') do
    d.check('the lap label reads Long Break') { win.lap_label.label == 'Long Break' }
    d.check('the countdown is the 15 minute long break') { win.timer_label.label == '15∶00' }
    d.shot('05-long-break')
  end

  d.step('the long break closes the set') do
    win.window.activate_action('skip', nil)
  end

  d.step('and the count starts over') do
    d.check('back to Lap 1') { win.lap_label.label == 'Lap 1' }
  end

  d.step('changing the session lengths takes effect on the next lap') do
    settings['lap-length'] = 30
    settings['short-break-length'] = 7
    win.window.activate_action('skip', nil)
  end

  d.step('the new short break length is used') do
    d.check('the break is 7 minutes') { win.timer_label.label == '07∶00' }
    win.window.activate_action('skip', nil)
  end

  d.step('and the new lap length too') do
    d.check('the lap is 30 minutes') { win.timer_label.label == '30∶00' }
    settings['lap-length'] = 25
    settings['short-break-length'] = 5
  end

  d.step('resetting') do
    win.window.activate_action('skip', nil)
    win.window.activate_action('reset', nil)
  end

  d.step('reset returns to lap 1, stopped') do
    d.check('back to Lap 1') { win.lap_label.label == 'Lap 1' }
    d.check('a full lap on the clock') { win.timer_label.label == '25∶00' }
    d.check('the timer is stopped') { !win.timer.running? }
    d.check('the countdown blinks') { win.timer_label.has_css_class?('blinking') }
    d.shot('06-after-reset')
  end

  d.step('a lap that runs out advances by itself') do
    win.window.activate_action('toggle-timer', nil)
    # Drain the lap without waiting 25 minutes: the timer reads a monotonic
    # clock, so the only way to cut it short is to shorten the lap itself.
    win.timer.instance_variable_set(:@duration, 0)
    win.timer.tick
  end

  d.step('and lands on a break, paused, with the chime played') do
    d.check('the lap label reads Short Break') { win.lap_label.label == 'Short Break' }
    d.check('the timer paused itself') { !win.timer.running? }
    d.check('the countdown blinks again') { win.timer_label.has_css_class?('blinking') }
    d.shot('07-lap-elapsed')
  end

  # We are on a break here, so starting the timer with the preference on
  # should take the window fullscreen.
  d.step('starting a break with fullscreen-break on') do
    settings['fullscreen-break'] = true
    win.window.activate_action('toggle-timer', nil)
  end

  d.step('the break takes over the screen') do
    d.check('the window is fullscreen') { win.window.fullscreened? }
    # Pause, move on to a pomodoro, and start that instead.
    win.window.activate_action('toggle-timer', nil)
    win.window.activate_action('skip', nil)
    win.window.activate_action('toggle-timer', nil)
  end

  d.step('and a pomodoro gives it back') do
    d.check('the window is not fullscreen') { !win.window.fullscreened? }
    win.window.activate_action('toggle-timer', nil)
    settings['fullscreen-break'] = false
  end

  # A fullscreen round trip leaves the offscreen surface without a size for a
  # turn, and a widget with no size produces no render node to screenshot.
  d.step('letting the window settle back to its own size') do
    d.check('the window has a size again') { win.window.width.positive? }
  end

  # Upstream's breakpoint fires at 800sp square. Rather than calling the
  # handlers, grow the window and let AdwBreakpoint decide — that is what is
  # actually being ported.
  d.step('growing the window past the breakpoint') do
    win.window.set_default_size(900, 900)
    settle_until { win.window.width >= 900 }
  end

  d.step('the large-text breakpoint applies') do
    d.check('the window grew') { win.window.width >= 900 }
    d.check('the countdown grows') { win.timer_label.has_css_class?('large-timer') }
    d.check('and is really rendered larger') do
      win.timer_label.measure(:vertical, -1)[1] > small_timer_height
    end
    d.check('the lap label becomes a title') { win.lap_label.has_css_class?('title-4') }
    d.check('and drops the heading style') { !win.lap_label.has_css_class?('heading') }
    d.shot('08-large-text')
  end

  d.step('shrinking it back') do
    win.window.set_default_size(360, 360)
    settle_until { win.window.width <= 360 }
  end

  d.step('and the breakpoint unapplies') do
    d.check('the countdown shrinks') { !win.timer_label.has_css_class?('large-timer') }
    d.check('back to its original size') do
      win.timer_label.measure(:vertical, -1)[1] == small_timer_height
    end
    d.check('the lap label is a heading again') { win.lap_label.has_css_class?('heading') }
    d.check('and no longer a title') { !win.lap_label.has_css_class?('title-4') }
  end

  d.step('opening preferences') do
    app.app.activate_action('preferences', nil)
  end

  d.step('the preferences dialog') do
    d.check('a dialog is showing') { !win.window.visible_dialog.nil? }
    d.check('it is the preferences dialog') do
      win.window.visible_dialog.is_a?(Adwaita::PreferencesDialog)
    end
    d.check('the window still has a size') { win.window.width.positive? }
    d.shot('09-preferences')
  end

  d.step('closing preferences') do
    win.window.visible_dialog&.close
  end

  # Closing is animated, and opening the next dialog before the last one has
  # finished leaving gives a window with nothing to render.
  d.step('waiting for it to finish closing') do
    d.check('no dialog is showing') { win.window.visible_dialog.nil? }
  end

  d.step('opening the shortcuts dialog') do
    win.window.activate_action('show-help-overlay', nil)
  end

  d.step('the shortcuts dialog') do
    d.check('a dialog is showing') { !win.window.visible_dialog.nil? }
    d.check('it is the shortcuts dialog') do
      win.window.visible_dialog.is_a?(Adwaita::ShortcutsDialog)
    end
    d.check('the window still has a size') { win.window.width.positive? }
    d.shot('10-shortcuts')
  end

  d.step('closing the shortcuts dialog') do
    win.window.visible_dialog&.close
  end

  d.step('waiting for that to finish closing too') do
    d.check('no dialog is showing') { win.window.visible_dialog.nil? }
  end

  d.step('opening the about dialog') do
    app.app.activate_action('about', nil)
  end

  d.step('the about dialog') do
    d.check('a dialog is showing') { !win.window.visible_dialog.nil? }
    d.check('it is the about dialog') do
      win.window.visible_dialog.is_a?(Adwaita::AboutDialog)
    end

    # Upstream fills these from the metainfo via
    # adw_about_dialog_new_from_appdata; here Appdata reads the same file.
    win.window.visible_dialog.then do |about|
      d.check('the name comes from the appdata') { about.application_name == 'Solanum' }
      d.check('the developer comes from the appdata') do
        about.developer_name == 'Christopher Davis'
      end
      d.check('the licence comes from the appdata') do
        about.license_type == Gtk::License::GPL_3_0
      end
      d.check('the description comes from the appdata') do
        about.comments.start_with?('Solanum is a time tracking app')
      end
      d.check('the website comes from the appdata') do
        about.website == 'https://apps.gnome.org/Solanum'
      end
      d.check('the issue url comes from the appdata') do
        about.issue_url.include?('gitlab.gnome.org')
      end
      d.check('the release notes come from the appdata') do
        about.release_notes.to_s.include?('scales with window size')
      end
      d.check('the version is the build version') { about.version == '6.0.0' }
      d.check("the copyright is upstream's year") do
        about.copyright == '© 2022 Christopher Davis, et al.'
      end
    end
    d.check('the window still has a size') { win.window.width.positive? }
    d.shot('11-about')
  end

  d.step('closing the about dialog') do
    win.window.visible_dialog&.close
  end

  d.step('the app-level actions the timer notification uses') do
    d.check('app.toggle-timer exists') { !app.app.lookup_action('toggle-timer').nil? }
    d.check('app.skip exists') { !app.app.lookup_action('skip').nil? }
    d.check('app.preferences exists') { !app.app.lookup_action('preferences').nil? }
    d.check('app.about exists') { !app.app.lookup_action('about').nil? }
    d.check('app.quit exists') { !app.app.lookup_action('quit').nil? }
  end

  d.step('the accelerators upstream registers') do
    d.check('Ctrl+, opens preferences') do
      # GTK canonicalises <Primary> to <Control> when it stores an accel.
      app.app.get_accels_for_action('app.preferences') == ['<Control>comma']
    end
    d.check('Ctrl+Q quits') do
      app.app.get_accels_for_action('app.quit') == ['<Control>q']
    end
    d.check('Ctrl+? shows the shortcuts') do
      app.app.get_accels_for_action('win.show-help-overlay') == ['<Control>question']
    end
  end

  d.step('app.toggle-timer drives the window, as the notification button does') do
    d.check('the timer is stopped to begin with') { !win.timer.running? }
    app.app.activate_action('toggle-timer', nil)
    d.check('the timer started') { win.timer.running? }
    app.app.activate_action('toggle-timer', nil)
    d.check('and stopped again') { !win.timer.running? }
  end

  # The window has to be inactive for one of these to be sent, which is not
  # something a headless run can arrange — but building one exercises every
  # call the notification path makes.
  d.step('the lap-change notifications') do
    win.notification(SolanumRb::Window::POMODORO).then do |notif|
      d.check('a pomodoro notification builds') { notif.is_a?(Gio::Notification) }
    end
    win.notification(SolanumRb::Window::BREAK).then do |notif|
      d.check('a break notification builds') { notif.is_a?(Gio::Notification) }
    end
    d.check('the pomodoro wording') do
      win.notification_text(SolanumRb::Window::POMODORO).first == 'Back to Work'
    end
    d.check('the break wording') do
      win.notification_text(SolanumRb::Window::BREAK).first == 'Break Time'
    end
  end

  d.step('app.skip advances the lap, as the notification button does') do
    win.lap_label.label.then do |before|
      app.app.activate_action('skip', nil)
      d.check('the lap changed') { win.lap_label.label != before }
    end
  end
end
