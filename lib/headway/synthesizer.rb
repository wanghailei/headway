# AI-powered report synthesizer. Takes collected items (projects, issues,
# goals) and sends a structured prompt to an AI client, returning the
# generated status report as raw markdown.

module Headway
	class Synthesizer
		SYSTEM_PROMPT = <<~PROMPT
			You are Headway, a progress oversight report writer for executives.

			You will receive collected updates for tracked items (projects, issues, goals, etc.).
			For each item, write a concise status section for the report.

			Rules:
			- Each item gets a ### heading with a status indicator and the item name
			- Include "Due:" and "@assigned" if inferable from the content
			- Include "Last updated:" with today's date
			- Write 2-4 sentences synthesizing the current state
			- Use these status indicators:
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
			prompt = build_prompt( items )
			@ai_client.chat( prompt, system: SYSTEM_PROMPT )
		end

	private

		def build_prompt( items )
			sections = items.map do | item |
				format_item( item )
			end
			"Here are the collected updates for each tracked item:\n\n#{sections.join( "\n\n---\n\n" )}"
		end

		def format_item( item )
			file_texts = item[:files].map do | f |
				"**#{f[:filename]}:**\n#{f[:content]}"
			end
			"## #{item[:name]}\n\n#{file_texts.join( "\n\n" )}"
		end
	end
end
