require_relative '../../spec_helper'

describe "ArgumentError" do
  class ArgumentErrorDummyClass
    def foo(a,b,c:)
    end

    def foo_kw(a:)
    end
  end

  it "is a subclass of StandardError" do
    StandardError.should be_ancestor_of(ArgumentError)
  end

  it "gives its own class name as message if it has no message" do
    ArgumentError.new.message.should == "ArgumentError"
  end

  ruby_version_is "2.6" do
    describe "arity error" do
      it "includes receiver and method name when raised by application code" do
        obj = ArgumentErrorDummyClass.new
        -> {obj.foo(3)}.should raise_error(ArgumentError) {|exc|
          exc.receiver.should == obj
          exc.method_name.should == :foo
        }
      end
    end

    describe "kw error" do
      it "includes receiver and method name when raised by application code" do
        obj = ArgumentErrorDummyClass.new
        -> {obj.foo_kw}.should raise_error(ArgumentError) {|exc|
          exc.receiver.should == obj
          exc.method_name.should == :foo_kw
        }
      end
    end
  end
end
