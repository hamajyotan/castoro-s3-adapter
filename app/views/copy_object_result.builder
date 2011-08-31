xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.CopyObjectResult :xmlns => "http://s3.amazonaws.com/doc/2006-03-01/" do
  xml.LastModified @last_modified
  xml.ETag @etag
end
