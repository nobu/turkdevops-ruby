require_relative '../../spec_helper'
require_relative 'fixtures/classes'
require_relative '../../fixtures/reflection'

# TODO: rewrite
describe "Kernel#private_methods" do
  it "returns a list of the names of privately accessible methods in the object" do
    m = KernelSpecs::Methods.private_methods(false)
    m.should include(:shichi)
    m = KernelSpecs::Methods.new.private_methods(false)
    m.should include(:juu_shi)
  end

  it "returns a list of the names of privately accessible methods in the object and its ancestors and mixed-in modules" do
    m = (KernelSpecs::Methods.private_methods(false) & KernelSpecs::Methods.private_methods)

    m.should include(:shichi)
    m = KernelSpecs::Methods.new.private_methods
    m.should include(:juu_shi)
  end

  it "returns private methods mixed in to the metaclass" do
    m = KernelSpecs::Methods.new
    m.extend(KernelSpecs::Methods::MetaclassMethods)
    m.private_methods.should include(:shoo)
  end
end

describe :kernel_private_methods_supers, shared: true do
  it "returns a unique list for an object extended by a module" do
    m = ReflectSpecs.oed.private_methods(*@object)
    m.select { |x| x == :pri }.sort.should == [:pri]
  end

  it "returns a unique list for a class including a module" do
    m = ReflectSpecs::D.new.private_methods(*@object)
    m.select { |x| x == :pri }.sort.should == [:pri]
  end

  it "returns a unique list for a subclass of a class that includes a module" do
    m = ReflectSpecs::E.new.private_methods(*@object)
    m.select { |x| x == :pri }.sort.should == [:pri]
  end
end

describe :kernel_private_methods_with_falsy, shared: true do
  it "returns a list of private methods in without its ancestors" do
    ReflectSpecs::F.private_methods(@object).select{|m|/_pri\z/ =~ m}.sort.should == [:ds_pri, :fs_pri]
    ReflectSpecs::F.new.private_methods(@object).should == [:f_pri]
  end
end

describe :kernel_private_methods_with_invalid_argument, shared: true do
  it "raises an ArgumentError" do
    -> {ReflectSpecs::F.private_methods(@object)}.should raise_error ArgumentError
    -> {ReflectSpecs::F.new.private_methods(@object)}.should raise_error ArgumentError
  end
end

describe "Kernel#private_methods" do
  describe "when not passed an argument" do
    it_behaves_like :kernel_private_methods_supers, nil, []
  end

  describe "when passed true" do
    it_behaves_like :kernel_private_methods_supers, nil, true
  end

  describe "when passed false" do
    it_behaves_like :kernel_private_methods_with_falsy, nil, false
  end

  ruby_version_is "3.1" do
    describe "when passed nil" do
      it_behaves_like :kernel_private_methods_with_invalid_argument, nil, nil
    end

    describe "when passed an integer" do
      it_behaves_like :kernel_private_methods_with_invalid_argument, nil, 1
    end
  end
end
