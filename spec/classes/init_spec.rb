require 'spec_helper'
describe 'rootpassmanager' do

  context 'with defaults for all parameters' do
    it { should contain_class('rootpassmanager') }
  end
end
