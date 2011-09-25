
require 'rexml/document'

module S3Adapter::Acl
  class Parser
    def initialize xml
      doc = REXML::Document.new xml

      raise ParserError unless doc.elements['AccessControlPolicy/Owner']
      raise ParserError unless doc.elements['AccessControlPolicy/Owner/ID']
      unless doc.elements['AccessControlPolicy/Owner/DisplayName']
        unless doc.elements['AccessControlPolicy/Owner/ID'].text == User::ANONYMOUS_ID
          raise ParserError
        end
      end

      @acl = Hash.new { |h,k| h[k] = [] }.tap { |gs|
        doc.elements.each('AccessControlPolicy/AccessControlList/Grant') { |e|
          perm = e.elements['Permission'].text
          raise ParserError unless [READ, WRITE, READ_ACP, WRITE_ACP, FULL_CONTROL].include?(perm)

          case e.elements['Grantee'].attributes['xsi:type']
          when 'CanonicalUser'
            id = e.elements['Grantee/ID'].text
            gs['account'] = Hash.new { |h,k| h[k] = [] } unless gs.key?('account')
            gs['account'][id] << perm
          when 'Group'
            case e.elements['Grantee/URI'].text
            when 'http://acs.amazonaws.com/groups/global/AuthenticatedUsers'
              gs['authenticated'] << perm
            when 'http://acs.amazonaws.com/groups/global/AllUsers'
              gs['guest'] << perm
            when 'http://acs.amazonaws.com/groups/s3/LogDelivery'
              gs['log'] << perm
            end
          end
        }
      }
    end

    attr_reader :acl
  end

  class ParserError < RuntimeError; end
end

