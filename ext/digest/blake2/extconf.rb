# -*- coding: us-ascii -*-
# frozen_string_literal: false

require "mkmf"
require File.expand_path("../../digest_conf", __FILE__)

$defs << "-DHAVE_CONFIG_H"

have_header("sys/cdefs.h")

$preload = %w[digest]

create_makefile("digest/blake2")
