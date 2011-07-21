xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.ListBucketResult :xmlins => "http://s3.amazonaws.com/doc/2006-03-01/" do
  xml.Name @bucket
  xml.Prefix @prefix
  xml.Marker @marker
  xml.MaxKeys @max_keys
  xml.Delimiter @delimiter if @delimiter
  xml.IsTruncated @truncated

  keys = 0
  @contents.to_a.each { |content|
    keys += 1
    break if keys > @max_keys

    xml.Contents do
      xml.Key           content[:key]
      xml.LastModified  content[:last_modified]
      xml.ETag          """#{content[:etag]}"""
      xml.Size          content[:size]
      xml.StorageClass  content[:storage_class]
    end
  }
  @common_prefixes.to_a.each { |common_prefix|
    keys += 1
    break if keys > @max_keys

    xml.CommonPrefixes do
      xml.Prefix common_prefix[:prefix]
    end
  }
end
