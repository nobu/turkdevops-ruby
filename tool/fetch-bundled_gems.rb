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
end
c = r || "v#{v}"
checkout = %w"git -c advice.detachedHead=false checkout"
puts "checking out #{c} (v=#{v}, r=#{r}) ..."
unless system(*checkout, c, "--", chdir: n)
  if r or !system(*checkout, v, "--", chdir: n)
    success = false
  end
end
