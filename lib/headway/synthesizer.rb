# Two-stage AI report synthesizer. Stage 1 sends all collected updates
# to the AI and asks it to identify distinct issues/projects/topics.
# Stage 2 synthesizes a concise status section for each extracted issue.
# This handles both structured (folder-per-issue) and unstructured
# (flat employee reports) data sources.

require "json"

module Headway
	class Synthesizer
		EXTRACT_SYSTEM = <<~PROMPT
			You are Headway, a progress-tracking assistant. Your task is to
			identify every distinct issue, project, or topic mentioned in the
			collected employee updates below.

			Group related information together even when it comes from different
			people or data sources. One entry per issue, not per person.

			Return a JSON array. Each element has:
			  "name"     — short issue/project title
			  "excerpts" — array of relevant text snippets from the updates

			Rules:
			- If an update mentions multiple issues, include its text under each
			- Preserve the original language (Chinese, English, etc.)
			- Output valid JSON only — no markdown fences, no explanation
		PROMPT

		SYNTHESIZE_SYSTEM = <<~PROMPT
			You are Headway, a progress oversight report writer for executives.
			You will receive excerpts about a single issue or project.
			Write a concise status section in markdown.

			Rules:
			- Start with a ### heading: status indicator + issue name
			- Include "Due:" and "@assigned" if inferable from the content
			- Include "Last updated:" with today's date
			- Write 2-4 sentences synthesizing the current state
			- Status indicators:
			  🟢 Green — on track / healthy
			  🟡 Yellow — needs attention / at risk
			  🔴 Red — blocked / off track / overdue
			  ✅ Checked — finished / resolved
			- For ✅ finished items, add a **Review:** line summarizing what happened
			- Be direct, factual, no filler
			- Output raw markdown, no code fences
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
			@ai_client.chat( prompt, system: SYNTHESIZE_SYSTEM )
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
			[ { "name" => "General Update", "excerpts" => [ response ] } ]
		rescue JSON::ParserError
			[ { "name" => "General Update", "excerpts" => [ response ] } ]
		end
	end
end
