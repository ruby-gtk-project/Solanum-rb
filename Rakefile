# frozen_string_literal: true

SCHEMA_DIR = 'build/share/glib-2.0/schemas'
COMPILED = File.join(SCHEMA_DIR, 'gschemas.compiled')

desc 'Compile the GSettings schema into build/, which the dev shell puts on XDG_DATA_DIRS'
file COMPILED => 'data/org.gnome.Solanum.Rb.gschema.xml' do |t|
  mkdir_p SCHEMA_DIR
  cp t.prerequisites.first, SCHEMA_DIR
  sh 'glib-compile-schemas', SCHEMA_DIR
end

task schema: COMPILED

desc 'Drive the app headlessly'
task test: :schema do
  sh({ 'DISPLAY' => nil, 'WAYLAND_DISPLAY' => nil }, 'ruby', 'test/drive_solanum.rb')
  sh 'ruby', 'test/test_units.rb'
end

desc 'Lint'
task :lint do
  sh 'rubocop'
end

task default: %i[test lint]
