# Focused pipeline for incremental doc-to-report merging.
# When the bot receives a doc link, this runner reads the doc,
# merges its content into the existing report via a single AI call,
# and publishes — skipping the full collect-synthesise cycle.
# Returns the updated report, or nil to signal fallback to full pipeline.

require "date"
require "logger"

module Pulse
	class DocUpdateRunner
		MERGE_SYSTEM = <<~PROMPT
			你是 Pulse，一个进度追踪助手。你将收到当前的进度报告和一份新文档内容。
			请将文档内容整合到进度报告中。

			今天的日期是：%<today>s

			规则：
			- 如果文档内容与报告中某个已有议题相关，更新该议题的段落
			- 如果文档引入了新的议题，添加新的 ### 段落
			- 保留所有与文档无关的现有段落不变
			- 保持标准格式：### 加状态emoji加议题名称、负责人、截止日期、最后更新、正文
			- 状态指示符：🟢 正常、🟡 关注、🔴 阻塞、✅ 完成
			- 简洁直接，只陈述事实
			- 输出完整的报告正文（所有 ### 段落），不要包含标题和日期头部
			- 输出原始 markdown，不要代码块
		PROMPT

		def initialize( config, ai_client: nil )
			@config = config
			@ai_client = ai_client || build_ai_client
			@logger = Logger.new( $stderr, progname: "DocUpdateRunner" )
		end

		def process( msg )
			text = msg.dig( "text", "content" )&.strip || msg["content"] || ""
			urls = DingTalk::DocReader.extract_urls( text )
			return nil if urls.empty?

			previous = Runner.find_previous_report( @config.publishers )
			return nil unless previous

			doc_contents = fetch_docs( urls, msg["senderStaffId"] )
			return nil if doc_contents.empty?

			sender = msg["senderNick"] || "unknown"
			body = merge_via_ai( previous, doc_contents, sender )
			report = render( body )
			publish( report )
			report
		end

	private

		def fetch_docs( urls, sender_staff_id )
			return [] unless sender_staff_id

			reader = DingTalk::DocReader.new( client: dingtalk_client )
			urls.filter_map do | url |
				content = reader.fetch( url, operator_id: sender_staff_id )
				@logger.info( "Fetched doc: #{url} (#{content&.length || 0} chars)" )
				content
			end
		end

		def merge_via_ai( previous_report, doc_contents, sender )
			docs_text = doc_contents.map.with_index( 1 ) do | content, i |
				"## 文档 #{i}\n\n#{content}"
			end.join( "\n\n---\n\n" )

			prompt = "## 当前进度报告\n\n#{previous_report}\n\n---\n\n## 新收到的文档（由 #{sender} 提交）\n\n#{docs_text}"
			system = format( MERGE_SYSTEM, today: Date.today.to_s )

			@ai_client.chat( prompt, system: system )
		end

		def render( body )
			ReportRenderer.new.render(
				date: Time.now.strftime( "%Y-%m-%d" ),
				body: body
			)
		end

		def publish( report )
			@config.publishers.each do | p |
				case p["type"]
				when "markdown_file"
					Publishers::MarkdownFile.new( p["path"] ).publish( report )
				when "dingtalk_doc"
					Publishers::DingtalkDoc.new(
						client: dingtalk_client,
						space_id: p["space_id"],
						doc_id: p["doc_id"],
						operator_user_id: p["operator_user_id"]
					).publish( report )
				end
			end
		end

		def dingtalk_client
			@dingtalk_client ||= DingTalk::Client.new(
				app_key: @config.dingtalk_app_key,
				app_secret: @config.dingtalk_app_secret
			)
		end

		def build_ai_client
			client_class = @config.using_codex_auth? ? ResponsesClient : AIClient
			client_class.new(
				base_url: @config.ai_base_url,
				api_key: @config.ai_api_key,
				model: @config.ai_model
			)
		end
	end
end
