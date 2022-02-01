#!/usr/bin/env ruby

class ABI
  def initialize(srcdir:, arch_hdrdir:)
    @srcdir = srcdir
    @arch_hdrdir = arch_hdrdir
  end

  def digest
    begin
      require "digest/sha2"
    rescue LoadError
      return
    end
    algo = Digest::SHA256
    d = algo.new

    # Generate checksum for every header file
    files = Dir["#{@srcdir}/include/**/*.h"]
    files.sort!
    @headers = files.map { |file| '$(srcdir)' + file[@srcdir.size..-1] }
    files << "#{@arch_hdrdir}/ruby/config.h"
    @headers << "$(arch_hdrdir)/ruby/config.h"
    files.each { |file| d << file << algo.file(file).digest }
    d
  end

  def version
    return 0 unless (d = digest)
    upper, lower = d.digest.unpack("Q>*")
    upper ^ lower
  end

  def source
    v = version.to_s(16)
    h = <<H
#define RUBY_ABI_CHECKSUM #{v}

#if 0 /* for Makefile */
RUBY_ABI_CHECKSUM = #{v}

abi.mk: #{@headers.join(" \\\n        ")}
#endif
H
  end
end

# Run only if file was directly called
if __FILE__ == $0
  require "optparse"
  require_relative "lib/colorize"

  OptionParser.new do |opts|
    opts.on("--srcdir=PATH", "use PATH as source directory") do |srcdir|
      @srcdir = srcdir
    end

    opts.on("--arch_hdrdir=PATH", "use PATH as arch_hdrdir") do |arch_hdrdir|
      @arch_hdrdir = arch_hdrdir
    end

    opts.on("--output_file=PATH", "use PATH as output file") do |output_file|
      @output_file = output_file
    end
  end.parse!

  abi = ABI.new(srcdir: @srcdir, arch_hdrdir: @arch_hdrdir)
  color = Colorize.new(color)
  updated = color.fail("updated")

  begin
    source = abi.source
  rescue
    exit
  end

  # Update if changed or doesn't exist
  if !@output_file
    print source
  elsif !File.exist?(@output_file) || File.read(@output_file) != source
    File.write(@output_file, source)

    puts "#{@output_file} #{updated}"
  end
end
