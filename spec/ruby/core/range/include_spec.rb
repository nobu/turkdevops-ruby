# -*- encoding: binary -*-
require_relative '../../spec_helper'
require_relative 'shared/cover_and_include'
require_relative 'shared/include'
require_relative 'shared/cover'

describe "Range#include?" do
  it_behaves_like :range_cover_and_include, :include?
  it_behaves_like :range_include, :include?

  ruby_version_is ""..."3.2" do
    it_behaves_like :range_cover_and_include_nonnumeric, :include?
    it_behaves_like :range_include_nonnumeric, :include?
  end

  ruby_version_is "3.2" do
    it "raises an ArgumentError" do
      -> {('a'..'c').include?('b')}.should raise_error(ArgumentError)
      -> {('a'...'c').include?('b')}.should raise_error(ArgumentError)
      -> {(..'c').include?('b')}.should raise_error(ArgumentError)
      -> {(...'c').include?('b')}.should raise_error(ArgumentError)
      -> {('a'..).include?('b')}.should raise_error(ArgumentError)
      -> {('a'...).include?('b')}.should raise_error(ArgumentError)
    end
  end
end
