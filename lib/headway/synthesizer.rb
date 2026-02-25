# Two-stage AI report synthesizer. Stage 1 sends all collected updates
# to the AI and asks it to identify distinct issues/projects/topics.
# Stage 2 synthesizes a concise status section for each extracted issue.
# This handles both structured (folder-per-issue) and unstructured
# (flat employee reports) data sources.

require "date"
require "json"

module Headway
	class Synthesizer
		EXTRACT_SYSTEM = <<~PROMPT
			你是 Headway，一个进度追踪助手。你的任务是从下面收集的员工更新中
			识别出每一个不同的议题、项目或主题。

			即使信息来自不同的人或数据源，也要将相关信息归为同一议题。
			按议题分组，而非按人分组。

			返回一个 JSON 数组，每个元素包含：
			  "name"     — 简短的议题/项目标题
			  "excerpts" — 相关的文本摘录数组

			规则：
			- 如果一条更新涉及多个议题，将其文本分别归入每个相关议题
			- 保留摘录的原始语言
			- 仅输出有效的 JSON — 不要 markdown 代码块，不要解释说明
		PROMPT

		SYNTHESIZE_TEMPLATE = <<~PROMPT
			你是 Headway，一个为高管编写进度报告的助手。
			你将收到关于单个议题或项目的摘录，请用中文撰写简洁的状态报告段落。

			今天的日期是：%<today>s

			格式规则：
			- 以 ### 开头，包含状态指示符和议题名称
			- 如果能从内容推断，标注"截止日期："和"@负责人"
			- 标注"最后更新：%<today>s"
			- 用 2-4 句话综合当前状态
			- 状态指示符：
			  🟢 正常 — 进展顺利
			  🟡 关注 — 需要关注 / 有风险
			  🔴 阻塞 — 受阻 / 偏离计划 / 逾期
			  ✅ 完成 — 已完成 / 已解决
			- 对于 ✅ 已完成的项目，增加一行 **回顾：** 总结完成情况
			- 简洁直接，只陈述事实，不要废话
			- 输出原始 markdown，不要代码块
		PROMPT

		def initialize( ai_client )
			@ai_client = ai_client
		end

		def synthesize( items )
			return "" if items.empty?

			issues = extract_issues( items )
			return "" if issues.empty?

			sections = issues.map do | issue |
				synthesize_issue( issue )
			end

			sections.join( "\n\n" )
		end

	private

		def extract_issues( items )
			prompt = build_extraction_prompt( items )
			response = @ai_client.chat( prompt, system: EXTRACT_SYSTEM )
			parse_issues( response )
		end

		def synthesize_issue( issue )
			excerpts = issue["excerpts"] || []
			prompt = "Issue: #{issue["name"]}\n\nRelevant excerpts:\n\n#{excerpts.join( "\n\n---\n\n" )}"
			system = format( SYNTHESIZE_TEMPLATE, today: Date.today.to_s )
			@ai_client.chat( prompt, system: system )
		end

		def build_extraction_prompt( items )
			sections = items.map { | item | format_item( item ) }
			"Identify all distinct issues, projects, or topics from these collected updates:\n\n#{sections.join( "\n\n---\n\n" )}"
		end

		def format_item( item )
			file_texts = item[:files].map do | f |
				"**#{f[:filename]}:**\n#{f[:content]}"
			end
			"## #{item[:name]}\n\n#{file_texts.join( "\n\n" )}"
		end

		def parse_issues( response )
			cleaned = response.gsub( /\A\s*```(?:json)?\s*/, "" ).gsub( /\s*```\s*\z/, "" ).strip
			parsed = JSON.parse( cleaned )
			return parsed if parsed.is_a?( Array ) && parsed.all? { | e | e.is_a?( Hash ) }
			[ { "name" => "综合更新", "excerpts" => [ response ] } ]
		rescue JSON::ParserError
			[ { "name" => "综合更新", "excerpts" => [ response ] } ]
		end
	end
end
