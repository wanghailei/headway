# Fetches DingTalk document content given a shared link URL.
# Uses the doc_2.0 API: first resolves the URL to a dentry UUID,
# then fetches the document body as markdown.

require "logger"
require "uri"

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
				dentry_uuid = extract_dentry_uuid( url )

				unless dentry_uuid
					dentry = lookup_dentry( url, operator_id: operator_id, connection: connection )
					dentry_uuid = dentry&.dig( "dentryUuid" )
				end

				return nil unless dentry_uuid

				fetch_content( dentry_uuid, operator_id: operator_id, connection: connection )
			rescue Client::APIError => e
				@logger.warn( "Failed to fetch doc #{url}: #{e.message}" )
				nil
			end

		private

			# Extract dentryUuid directly from /i/nodes/{uuid} URL paths.
			def extract_dentry_uuid( url )
				match = url.match( %r{/i/nodes/([A-Za-z0-9_-]+)} )
				match&.[]( 1 )
			end

			def lookup_dentry( url, operator_id:, connection: nil )
				@client.get(
					"/v2.0/doc/dentries/queryByUrl",
					params: { url: clean_url( url ), operatorId: operator_id },
					connection: connection
				)
			end

			# Strip query parameters (UTM tracking, corpId, etc.) that the
			# doc API doesn't recognise.
			def clean_url( url )
				uri = URI.parse( url )
				uri.query = nil
				uri.fragment = nil
				uri.to_s
			rescue URI::InvalidURIError
				url
			end

			def fetch_content( dentry_uuid, operator_id:, connection: nil )
				# Try wiki endpoint first (uses Document.WorkspaceDocument.Read),
				# fall back to doc endpoint (requires Document.Document.Read).
				result = @client.get(
					"/v2.0/wiki/nodes/#{dentry_uuid}/content",
					params: { targetFormat: "markdown", operatorId: operator_id },
					connection: connection
				)
				result["content"]
			rescue Client::APIError
				result = @client.get(
					"/v2.0/doc/me/query/#{dentry_uuid}/contents",
					params: { targetFormat: "markdown", operatorId: operator_id },
					connection: connection
				)
				result["content"]
			end
		end
	end
end
