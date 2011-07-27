xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.Error do
  xml.Code "InvalidRange"
  xml.Message @message
  xml.ActualObjectSize @actual_object_size
  xml.RequestId
  xml.HostId
  xml.RangeRequested @range_requested
end
