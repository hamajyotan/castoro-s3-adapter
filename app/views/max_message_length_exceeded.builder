xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.Error do
  xml.Code "MaxMessageLengthExceeded"
  xml.Message @message
  xml.RequestId
  xml.HostId
  xml.MaxMessageLengthBytes @max_message_length_bytes
end
