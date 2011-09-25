xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.Error do
  xml.Code "BadDigest"
  xml.Message "The Content-MD5 you specified did not match what we received."
  xml.ExpectedDigest @expected_digest
  xml.CalculatedDigest @calculated_digest
  xml.RequestId
  xml.HostId
end
