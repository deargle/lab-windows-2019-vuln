require 'winrm'
require 'winrm-fs'
EP = 'http://192.168.56.100:5985/wsman'
def conn
  WinRM::Connection.new(endpoint: EP, transport: :negotiate, user: 'vagrant',
                        password: 'vagrant', operation_timeout: 300)
end
case ARGV[0]
when 'run'
  cmd = ARGV[1] == '-f' ? File.read(ARGV[2]) : ARGV[1..].join(' ')
  conn.shell(:powershell) { |s| o = s.run(cmd); $stdout.write o.stdout; $stderr.write o.stderr; exit o.exitcode }
when 'upload'
  conn.shell(:powershell) {} # warm
  fm = WinRM::FS::FileManager.new(conn)
  rc = fm.upload(ARGV[1], ARGV[2])
  puts "uploaded #{ARGV[1]} -> #{ARGV[2]} rc=#{rc}"
else
  abort "usage: w.rb run [-f file | cmd...] | upload local remote"
end
