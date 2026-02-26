# DingTalk Stream mode client. Maintains a WebSocket connection to
# receive real-time events (bot @mentions, system pings). Runs in a
# background thread and dispatches received messages via a callback.
# Automatically reconnects on disconnect with backoff.

require "faraday"
require "json"
require "websocket-client-simple"

module Pulse
	module DingTalk
		class Stream
			GATEWAY_URL = "https://api.dingtalk.com"
			GATEWAY_PATH = "/v1.0/gateway/connections/open"
			BOT_TOPIC = "/v1.0/im/bot/messages/get"
			RECONNECT_DELAY = 5

			def initialize( app_key:, app_secret:, on_message: nil, output: $stdout )
				@app_key = app_key
				@app_secret = app_secret
				@on_message = on_message
				@output = output
				@running = false
				@ws = nil
				@thread = nil
			end

			def start
				@running = true
				@thread = Thread.new { run_loop }
				@thread.abort_on_exception = false
			end

			def stop
				@running = false
				@ws&.close rescue nil
				@thread&.join( 5 )
			end

			def running?
				@running && @thread&.alive?
			end

		private

			def run_loop
				while @running
					begin
						endpoint, ticket = register_connection
						connect_websocket( endpoint, ticket )
					rescue => e
						log "Stream error: #{e.class}: #{e.message}"
						interruptible_sleep( RECONNECT_DELAY ) if @running
					end
				end
			end

			def register_connection( connection: nil )
				conn = connection || build_gateway_connection
				response = conn.post( GATEWAY_PATH, {
					clientId: @app_key,
					clientSecret: @app_secret,
					subscriptions: [
						{ type: "CALLBACK", topic: BOT_TOPIC }
					],
					ua: "pulse/#{Pulse::VERSION} ruby/#{RUBY_VERSION}"
				} )

				unless response.success?
					raise "Stream registration failed: #{response.status} #{response.body}"
				end

				body = response.body
				[ body["endpoint"], body["ticket"] ]
			end

			def connect_websocket( endpoint, ticket )
				url = "#{endpoint}?ticket=#{ticket}"
				stream = self
				ws = WebSocket::Client::Simple.connect( url )
				@ws = ws

				ws.on :message do | msg |
					stream.send( :handle_message, ws, msg.data )
				end

				ws.on :close do
					# Will reconnect via run_loop
				end

				ws.on :error do | e |
					# Will reconnect via run_loop
				end

				# Block until closed or stopped
				sleep 1 while @running && ws.open?
			end

			def handle_message( ws, raw )
				data = JSON.parse( raw )
				type = data["type"]
				headers = data["headers"] || {}
				topic = headers["topic"]
				message_id = headers["messageId"]

				case type
				when "SYSTEM"
					handle_system( ws, topic, message_id, data )
				when "CALLBACK"
					handle_callback( ws, topic, message_id, data )
				end
			rescue JSON::ParserError => e
				log "Stream: failed to parse message: #{e.message}"
			end

			def handle_system( ws, topic, message_id, data )
				case topic
				when "ping"
					send_ack( ws, message_id, data["data"] || "{}" )
				when "disconnect"
					@ws&.close rescue nil
				end
			end

			def handle_callback( ws, topic, message_id, data )
				if topic == BOT_TOPIC
					payload = JSON.parse( data["data"] || "{}" )
					reply_with_ack_emoji( payload )
					@on_message&.call( payload )
				end
				send_ack( ws, message_id )
			end

			def reply_with_ack_emoji( payload )
				webhook = payload["sessionWebhook"]
				return unless webhook

				Faraday.post( webhook ) do | req |
					req.headers["Content-Type"] = "application/json"
					req.body = JSON.generate( {
						msgtype: "text",
						text: { content: "👌" }
					} )
				end
			rescue => e
				log "Stream: failed to reply: #{e.message}"
			end

			def send_ack( ws, message_id, response_data = '{"response":null}' )
				ack = {
					code: 200,
					headers: { messageId: message_id, contentType: "application/json" },
					message: "OK",
					data: response_data
				}
				ws.send( JSON.generate( ack ) )
			rescue => e
				log "Stream: failed to send ack: #{e.message}"
			end

			def build_gateway_connection
				Faraday.new( url: GATEWAY_URL ) do | f |
					f.request :json
					f.response :json
					f.adapter Faraday.default_adapter
				end
			end

			def interruptible_sleep( seconds )
				seconds.times do
					break unless @running
					sleep 1
				end
			end

			def log( message )
				@output.puts message
			end
		end
	end
end
