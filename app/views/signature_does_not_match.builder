xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.Error do
  xml.Code "SignatureDoesNotMatch"
  xml.Message "The request signature we calculated does not match the signature you provided. Check your key and signing method."
  xml.RequestId
  xml.HostId
  xml.SignatureProvied @signature_provied
  xml.StringToSign @string_to_sign
  xml.AWSAccessKeyId @access_key_id
end
