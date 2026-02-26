# DingTalk bot notification publisher. After each pipeline run, sends
# a formatted notification to whitelisted users. Highlighted items
# (tagged or AI-flagged) show inline; the rest are collapsed with a
# link to the full report.

require "json"

module Pulse
	module Publishers
		class DingtalkBotNotify
			def initialize( messenger:, user_ids:, report_url: nil )
				@messenger = messenger
				@user_ids = user_ids
				@report_url = report_url
			end

			def publish( report )
				return if @user_ids.nil? || @user_ids.empty?

				sections = parse_sections( report )
				return if sections.empty?

				highlighted, normal = partition_sections( sections )
				content = build_message( highlighted, normal )

				@messenger.send_markdown(
					user_ids: @user_ids,
					title: "Pulse 进度通知",
					content: content
				)
			end

		private

			# Split the report into ### sections.
			def parse_sections( report )
				report.split( /(?=^### )/ ).map( &:strip ).reject( &:empty? )
			end

			# Partition sections into highlighted vs normal.
			# Highlighted: 🔴, 🟡, or contains a priority tag.
			# Normal: 🟢, ✅, or anything else.
			def partition_sections( sections )
				highlighted = []
				normal = []

				sections.each do | section |
					if highlight?( section )
						highlighted << section
					else
						normal << section
					end
				end

				[ highlighted, normal ]
			end

			def highlight?( section )
				first_line = section.lines.first || ""
				return true if first_line.include?( "\u{1F534}" ) # 🔴
				return true if first_line.include?( "\u{1F7E1}" ) # 🟡
				TagDetector.starred?( section )
			end

			def build_message( highlighted, normal )
				parts = []

				if highlighted.any?
					parts << "**\u{1F6A8} 需要关注**\n"
					highlighted.each { | s | parts << s }
				end

				if normal.any?
					parts << "**\u{1F7E2} 正常进行中**\n"
					normal.each { | s | parts << s }
				end

				if parts.empty?
					parts << "本期无更新。"
				end

				parts.join( "\n\n" )
			end
		end
	end
end
