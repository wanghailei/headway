# Shared DingTalk API client with automatic token management. Handles
# authentication via AppKey/AppSecret, token caching, and automatic
# refresh when tokens expire. All DingTalk collectors and publishers
# share a single Client instance per run.

require "faraday"

module Headway
	module DingTalk
		class Client
			class APIError < StandardError; end
			class AuthError < APIError; end

			BASE_URL = "https://api.dingtalk.com"
			LEGACY_BASE_URL = "https://oapi.dingtalk.com"
			EXPIRY_BUFFER_SECONDS = 300

			def initialize( app_key:, app_secret: )
				raise ArgumentError, "app_key is required (set DINGTALK_APP_KEY)" unless app_key
				raise ArgumentError, "app_secret is required (set DINGTALK_APP_SECRET)" unless app_secret
				@app_key = app_key
				@app_secret = app_secret
				@token = nil
				@token_expires_at = nil
			end

			# GET request to new API (api.dingtalk.com).
			def get( path, params: {}, connection: nil )
				conn = connection || build_connection
				ensure_token( connection: connection )
				response = conn.get( path ) do | req |
					req.params.merge!( params )
					req.headers["x-acs-dingtalk-access-token"] = @token
				end
				handle_response( response )
			end

			# POST request to new API (api.dingtalk.com).
			def post( path, body: {}, connection: nil )
				conn = connection || build_connection
				ensure_token( connection: connection )
				response = conn.post( path, body ) do | req |
					req.headers["x-acs-dingtalk-access-token"] = @token
				end
				handle_response( response )
			end

			# POST request to legacy API (oapi.dingtalk.com).
			# Token passed as query param instead of header.
			# Legacy API returns errors as HTTP 200 with errcode != 0,
			# so we check the errcode after the HTTP-level check.
			def legacy_post( path, body: {}, connection: nil )
				conn = connection || build_legacy_connection
				ensure_token( connection: connection )
				response = conn.post( path, body ) do | req |
					req.params["access_token"] = @token
				end
				result = handle_response( response )
				check_legacy_errcode( result )
				result
			end

		private

			def ensure_token( connection: nil )
				return if @token && @token_expires_at && Time.now < @token_expires_at
				fetch_token( connection: connection )
			end

			def fetch_token( connection: nil )
				conn = connection || build_connection
				response = conn.post( "v1.0/oauth2/accessToken", {
					appKey: @app_key,
					appSecret: @app_secret
				} )

				unless response.success?
					raise AuthError, "DingTalk auth failed: #{response.status}"
				end

				body = response.body
				@token = body["accessToken"]
				raise AuthError, "DingTalk auth succeeded but returned no accessToken" unless @token

				expires_in = body["expireIn"] || 7200
				@token_expires_at = Time.now + expires_in - EXPIRY_BUFFER_SECONDS
			end

			def build_connection
				Faraday.new( url: BASE_URL ) do | f |
					f.request :json
					f.response :json
					f.adapter Faraday.default_adapter
				end
			end

			def build_legacy_connection
				Faraday.new( url: LEGACY_BASE_URL ) do | f |
					f.request :json
					f.response :json
					f.adapter Faraday.default_adapter
				end
			end

			def check_legacy_errcode( result )
				return unless result.is_a?( Hash ) && result["errcode"]
				return if result["errcode"] == 0
				raise APIError, "DingTalk legacy API error #{result["errcode"]}: #{result["errmsg"]}"
			end

			def handle_response( response )
				unless response.success?
					error_msg = response.body.is_a?( Hash ) ? response.body["message"] : nil
					raise APIError, "DingTalk API returned #{response.status}: #{error_msg || response.body.to_s}"
				end
				response.body
			end
		end
	end
end
