# Two-stage AI report synthesizer. Stage 1 sends all collected updates
# to the AI and asks it to identify distinct issues/projects/topics.
# Stage 2 synthesizes a concise status section for each extracted issue.
# Supports iterative reporting: when a previous report is provided,
# the AI updates existing topics rather than starting from scratch.

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

		EXTRACT_WITH_PREVIOUS_SYSTEM = <<~PROMPT
			你是 Headway，一个进度追踪助手。你的任务是从下面收集的员工更新中
			识别出每一个不同的议题、项目或主题。

			你还会收到上一期的进度报告作为参考。请：
			- 沿用上期报告中仍然活跃的议题名称，保持一致性
			- 识别本期新出现的议题
			- 对于上期已标记 ✅ 完成的议题，如果本期没有新更新则不再包含

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

		SYNTHESIZE_WITH_PREVIOUS_TEMPLATE = <<~PROMPT
			你是 Headway，一个为高管编写进度报告的助手。
			你将收到关于单个议题或项目的摘录，以及上期报告中该议题的状态。
			请基于上期状态和本期新信息，用中文撰写更新后的状态报告段落。

			今天的日期是：%<today>s

			格式规则：
			- 以 ### 开头，包含状态指示符和议题名称
			- 如果能从内容推断，标注"截止日期："和"@负责人"
			- 标注"最后更新：%<today>s"
			- 用 2-4 句话综合当前状态
			- 如果状态相比上期有变化，简要说明变化
			- 状态指示符：
			  🟢 正常 — 进展顺利
			  🟡 关注 — 需要关注 / 有风险
			  🔴 阻塞 — 受阻 / 偏离计划 / 逾期
			  ✅ 完成 — 已完成 / 已解决
			- 对于 ✅ 已完成的项目，增加一行 **回顾：** 总结完成情况
			- 简洁直接，只陈述事实，不要废话
			- 输出原始 markdown，不要代码块
		PROMPT

		def initialize( ai_client, previous_report: nil )
			@ai_client = ai_client
			@previous_report = previous_report
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
			system = @previous_report ? EXTRACT_WITH_PREVIOUS_SYSTEM : EXTRACT_SYSTEM
			response = @ai_client.chat( prompt, system: system )
			parse_issues( response )
		end

		def synthesize_issue( issue )
			excerpts = issue["excerpts"] || []
			prompt = build_synthesis_prompt( issue["name"], excerpts )

			if @previous_report
				system = format( SYNTHESIZE_WITH_PREVIOUS_TEMPLATE, today: Date.today.to_s )
			else
				system = format( SYNTHESIZE_TEMPLATE, today: Date.today.to_s )
			end

			@ai_client.chat( prompt, system: system )
		end

		def build_extraction_prompt( items )
			sections = items.map { | item | format_item( item ) }
			prompt = "Identify all distinct issues, projects, or topics from these collected updates:\n\n#{sections.join( "\n\n---\n\n" )}"

			if @previous_report
				prompt += "\n\n---\n\n## 上期进度报告（参考）\n\n#{@previous_report}"
			end

			prompt
		end

		def build_synthesis_prompt( name, excerpts )
			prompt = "Issue: #{name}\n\nRelevant excerpts:\n\n#{excerpts.join( "\n\n---\n\n" )}"

			if @previous_report
				# Extract the section for this issue from the previous report
				previous_section = extract_previous_section( name )
				if previous_section
					prompt += "\n\n---\n\n上期状态：\n\n#{previous_section}"
				end
			end

			prompt
		end

		def extract_previous_section( issue_name )
			return nil unless @previous_report

			# Match a ### section that contains the issue name
			sections = @previous_report.split( /(?=^### )/ )
			sections.find { | s | s.include?( issue_name ) }
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
