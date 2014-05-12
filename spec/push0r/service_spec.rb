require "spec_helper"

describe Push0r::GcmService do

  before(:each) do
    @service = Push0r::GcmService.new("")
  end

  it "should be able to send GcmPushMessages" do
    message = Push0r::GcmPushMessage.new([])
    @service.can_send?(message).should be_true
  end

  it "should not be able to send APNS Messages" do
    message = Push0r::ApnsPushMessage.new([])
    @service.can_send?(message).should be_false
  end

end