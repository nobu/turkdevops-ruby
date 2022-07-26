#!ruby -an
BEGIN {
  require 'fileutils'

  success = true

  dir = ARGV.shift
  ARGF.eof?
  FileUtils.mkdir_p(dir)
  Dir.chdir(dir)
}

END {exit success}

n, v, u, r = $F

next if n =~ /^#/

if File.directory?(n)
  puts "updating #{n} ..."
  unless system("git", "fetch", chdir: n)
    success = false
    next
  end
else
  puts "retrieving #{n} ..."
  unless system(*%W"git clone #{u} #{n}")
    success = false
    next
  end
end
if r
  puts "fetching #{r} ..."
  unless system("git", "fetch", "origin", r, chdir: n)
    success = false
    next
  end
  c = r
else
  c = "v#{v}"
  unless system("git", "log", "-1", "--format=pretty:%%", c, err: IO::NULL, &:read)
    c = v
  end
end
checkout = %w"git -c advice.detachedHead=false checkout"
puts "checking out #{c} (v=#{v}, r=#{r}) ..."
success &= system(*checkout, c, "--", chdir: n)
