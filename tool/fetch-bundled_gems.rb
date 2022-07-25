#!ruby -an
BEGIN {
  require 'fileutils'

  topdir = Dir.pwd
  dir = ARGV.shift
  ARGF.eof?
  FileUtils.mkdir_p(dir)
  Dir.chdir(dir)
  if Dir.pwd == File.join(topdir, dir)
    topdir = ".."
  end
}

n, v, u, r = $F

next if n =~ /^#/

if File.directory?(n)
  puts "updating #{n} ..."
  system("git", "fetch", chdir: n) or abort
else
  puts "retrieving #{n} ..."
  system(*%W"git clone #{u} #{n}") or abort
end
if r
  puts "fetching #{r} ..."
  system("git", "fetch", "origin", r, chdir: n) or abort
  bdir = "#{topdir}/../.bundle/gems/#{n}-#{v}"
  gsrc = "../../gems/src/#{n}"
  unless (File.readlink(bdir) == gsrc rescue false)
    FileUtils.rm_rf(bdir)
    File.symlink(gsrc, bdir)
  end
end
c = r || "v#{v}"
checkout = %w"git -c advice.detachedHead=false checkout"
puts "checking out #{c} (v=#{v}, r=#{r}) ..."
unless system(*checkout, c, "--", chdir: n)
  abort
end
