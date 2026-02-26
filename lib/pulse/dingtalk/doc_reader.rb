# Fetches DingTalk document content given a shared link URL.
# Uses the doc_2.0 API: first resolves the URL to a dentry UUID,
# then fetches the document body as markdown.

require "logger"

module Pulse
	module DingTalk
		class DocReader
			DINGTALK_DOC_PATTERN = %r{https?://alidocs\.dingtalk\.com/\S+}

			def initialize( client: )
				@client = client
				@logger = Logger.new( $stderr, progname: "DocReader" )
			end

			# Scans text for alidocs.dingtalk.com URLs.
			def self.extract_urls( text )
				return [] if text.nil? || text.empty?
				text.scan( DINGTALK_DOC_PATTERN )
			end

			# Fetches document content as markdown. The operator_id is the
			# sender's staff ID — using the sender's identity ensures they
			# have permission to access the doc they shared.
			# Returns content string or nil on any failure (logged, not raised).
			def fetch( url, operator_id:, connection: nil )
				dentry = lookup_dentry( url, operator_id: operator_id, connection: connection )
				return nil unless dentry

				dentry_uuid = dentry["dentryUuid"]
				return nil unless dentry_uuid

				fetch_content( dentry_uuid, connection: connection )
			rescue Client::APIError => e
				@logger.warn( "Failed to fetch doc #{url}: #{e.message}" )
				nil
			end

		private

			def lookup_dentry( url, operator_id:, connection: nil )
				@client.get(
					"/v2.0/doc/dentries/queryByUrl",
					params: { url: url, operatorId: operator_id },
					connection: connection
				)
			end

			def fetch_content( dentry_uuid, connection: nil )
				result = @client.get(
					"/v2.0/doc/me/query/#{dentry_uuid}/contents",
					params: { targetFormat: "markdown" },
					connection: connection
				)
				result["content"]
			end
		end
	end
end
