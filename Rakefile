task :build do
    sh 'npx webpack'
end

task :run, [:ruby_port, :python_port] do |t, args|
    ruby = Process.spawn("ruby app.rb #{args[:ruby_port]} #{args[:python_port]}")
    python = Process.spawn("python app.py #{args[:ruby_port]} #{args[:python_port]}")

    Process.wait(ruby)
    Process.wait(python)
end

task :default => :build