xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.Error do
  xml.Code "InvalidArgument"
  xml.Message @message
  xml.ArgumentValue @argument_value
  xml.ArgumentName @argument_name
  xml.RequestId
  xml.HostId
end
