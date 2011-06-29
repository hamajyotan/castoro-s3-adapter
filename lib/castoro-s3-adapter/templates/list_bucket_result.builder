xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.ListBucketResult :xmlins => "http://s3.amazonaws.com/doc/2006-03-01/" do
  xml.Name @bucket
  xml.Prefix
  xml.Marker
  xml.MaxKeys 1000
  xml.IsTruncated false
  @files.each { |k, v|
    xml.Contents do
      xml.Key File.basename(k)
      xml.LastModified v.mtime.httpdate
      xml.ETag
      xml.Size v.size
      xml.StorageClass "STANDARD"
    end
  }
end
