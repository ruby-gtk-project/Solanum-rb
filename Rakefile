# frozen_string_literal: true

SCHEMA_DIR = 'build/share/glib-2.0/schemas'
COMPILED = File.join(SCHEMA_DIR, 'gschemas.compiled')
GENERATED_DIR = 'build/generated'
SCHEMA_SOURCE = 'data/org.gnome.Solanum.Rb.gschema.xml'

def app_id
  @app_id ||= `ruby -Ilib -rsolanum_rb/config -e 'print SolanumRb::Config.app_id'`
end

desc 'Compile the GSettings schema into build/, which the dev shell puts on XDG_DATA_DIRS'
file COMPILED => SCHEMA_SOURCE do |t|
  mkdir_p SCHEMA_DIR
  cp t.prerequisites.first, SCHEMA_DIR
  sh 'glib-compile-schemas', SCHEMA_DIR
end

task schema: COMPILED

desc 'Merge po/*.po into the desktop entry and the metainfo (meson i18n.merge_file)'
task :desktop do
  # Both profiles, so the devel build and its test have a metainfo to read.
  %w[default development].each do |profile|
    sh "SOLANUM_RB_PROFILE=#{profile} ruby scripts/merge_translations.rb #{GENERATED_DIR}"
  end
end

desc 'The three checks upstream runs from meson: schema, desktop entry, metainfo'
task validate: :desktop do
  # Upstream: test('Validate schema file', ...)
  sh 'glib-compile-schemas', '--strict', '--dry-run', 'data'
  # Upstream: test('Validate desktop file', ...)
  sh 'desktop-file-validate', File.join(GENERATED_DIR, "#{app_id}.desktop")
  # Upstream: test('Validate appstream file', ...)
  sh "appstreamcli validate --no-net --explain #{File.join(GENERATED_DIR, "#{app_id}.metainfo.xml")}"
end

desc 'Drive the app headlessly and check the parts that need no display'
task test: %i[schema desktop] do
  puts "\n== test/test_units.rb"
  sh 'ruby', 'test/test_units.rb'
  # No display needed — GTK4 renders the window to an offscreen surface, and
  # the screenshots in tmp/shots come out the same as a real session's. The
  # devel profile runs separately: it is chosen from the environment before
  # the application id is built.
  %w[test/drive_solanum.rb test/drive_devel.rb].each do |script|
    puts "\n== #{script}"
    sh({ 'DISPLAY' => nil, 'WAYLAND_DISPLAY' => nil }, 'ruby', script)
  end
end

desc 'Run the application'
task run: %i[schema desktop] do
  sh 'bin/solanum-rb'
end

desc 'Lint'
task :lint do
  sh 'rubocop'
end

task default: %i[test validate lint]
