xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.Error do
  xml.Code "PreconditionFailed"
  xml.Message "At least one of the pre-conditions you specified did not hold"
  xml.Condition @condition
  xml.RequestId
  xml.HostId
end
