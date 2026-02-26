# Tests for Pulse::DingTalk::DocReader. Verifies URL extraction and
# doc content fetching with mocked API responses.

require "test_helper"
require "faraday"
require "json"

class TestDocReader < Minitest::Test
	# --- URL extraction ---

	def test_extract_urls_single
		text = "请看这个文档 https://alidocs.dingtalk.com/i/nodes/abc123 谢谢"
		urls = Pulse::DingTalk::DocReader.extract_urls( text )
		assert_equal ["https://alidocs.dingtalk.com/i/nodes/abc123"], urls
	end

	def test_extract_urls_multiple
		text = "文档1 https://alidocs.dingtalk.com/doc1 和 https://alidocs.dingtalk.com/doc2"
		urls = Pulse::DingTalk::DocReader.extract_urls( text )
		assert_equal 2, urls.size
		assert_includes urls, "https://alidocs.dingtalk.com/doc1"
		assert_includes urls, "https://alidocs.dingtalk.com/doc2"
	end

	def test_extract_urls_none
		text = "没有文档链接"
		urls = Pulse::DingTalk::DocReader.extract_urls( text )
		assert_equal [], urls
	end

	def test_extract_urls_nil
		assert_equal [], Pulse::DingTalk::DocReader.extract_urls( nil )
	end

	def test_extract_urls_empty
		assert_equal [], Pulse::DingTalk::DocReader.extract_urls( "" )
	end

	def test_extract_urls_ignores_non_dingtalk
		text = "看看 https://docs.google.com/abc 和 https://alidocs.dingtalk.com/xyz"
		urls = Pulse::DingTalk::DocReader.extract_urls( text )
		assert_equal ["https://alidocs.dingtalk.com/xyz"], urls
	end

	# --- fetch ---

	def auth_response
		JSON.generate( { accessToken: "test-token", expireIn: 7200 } )
	end

	def build_stubs( &block )
		Faraday::Adapter::Test::Stubs.new( &block )
	end

	def build_connection( stubs )
		Faraday.new do | f |
			f.request :json
			f.response :json
			f.adapter :test, stubs
		end
	end

	def test_fetch_returns_content
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do
				[ 200, { "Content-Type" => "application/json" }, auth_response ]
			end
			stub.get( "/v2.0/doc/dentries/queryByUrl" ) do | env |
				assert_includes env.url.to_s, "operatorId=op123"
				[ 200, { "Content-Type" => "application/json" },
					JSON.generate( { "dentryUuid" => "dentry-uuid-1" } ) ]
			end
			stub.get( "/v2.0/doc/me/query/dentry-uuid-1/contents" ) do | env |
				assert_includes env.url.to_s, "targetFormat=markdown"
				[ 200, { "Content-Type" => "application/json" },
					JSON.generate( { "content" => "# Hello World\n\nDoc body here." } ) ]
			end
		end
		conn = build_connection( stubs )

		client = Pulse::DingTalk::Client.new( app_key: "key", app_secret: "secret" )
		reader = Pulse::DingTalk::DocReader.new( client: client, operator_id: "op123" )

		result = reader.fetch( "https://alidocs.dingtalk.com/i/nodes/abc123", connection: conn )
		assert_equal "# Hello World\n\nDoc body here.", result
		stubs.verify_stubbed_calls
	end

	def test_fetch_returns_nil_on_api_error
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do
				[ 200, { "Content-Type" => "application/json" }, auth_response ]
			end
			stub.get( "/v2.0/doc/dentries/queryByUrl" ) do
				[ 403, { "Content-Type" => "application/json" },
					JSON.generate( { "message" => "forbidden" } ) ]
			end
		end
		conn = build_connection( stubs )

		client = Pulse::DingTalk::Client.new( app_key: "key", app_secret: "secret" )
		reader = Pulse::DingTalk::DocReader.new( client: client, operator_id: "op123" )

		result = reader.fetch( "https://alidocs.dingtalk.com/i/nodes/abc123", connection: conn )
		assert_nil result
	end

	def test_fetch_returns_nil_when_no_dentry_uuid
		stubs = build_stubs do | stub |
			stub.post( "v1.0/oauth2/accessToken" ) do
				[ 200, { "Content-Type" => "application/json" }, auth_response ]
			end
			stub.get( "/v2.0/doc/dentries/queryByUrl" ) do
				[ 200, { "Content-Type" => "application/json" },
					JSON.generate( {} ) ]
			end
		end
		conn = build_connection( stubs )

		client = Pulse::DingTalk::Client.new( app_key: "key", app_secret: "secret" )
		reader = Pulse::DingTalk::DocReader.new( client: client, operator_id: "op123" )

		result = reader.fetch( "https://alidocs.dingtalk.com/i/nodes/abc123", connection: conn )
		assert_nil result
	end
end
