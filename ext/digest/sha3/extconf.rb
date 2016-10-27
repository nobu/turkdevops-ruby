require "mkmf"
require File.expand_path("../../digest_conf", __FILE__)

$objs = %W[sha3init.#{$OBJEXT}]
$defs << "-DHAVE_CONFIG_H"
$preload = %w[digest]

create_makefile("digest/sha3")
