# Tests for Pulse::TagDetector. Verifies pattern detection and stripping
# for all supported inline priority tags.

require "test_helper"

class TestTagDetector < Minitest::Test
	def test_detects_p0_tag
		assert Pulse::TagDetector.starred?( "Deploy %P0% fix immediately" )
	end

	def test_detects_p0_case_insensitive
		assert Pulse::TagDetector.starred?( "Deploy %p0% fix" )
	end

	def test_detects_p1_tag
		assert Pulse::TagDetector.starred?( "Review %P1% item" )
	end

	def test_detects_star_tag
		assert Pulse::TagDetector.starred?( "Check {star} this item" )
	end

	def test_detects_star_case_insensitive
		assert Pulse::TagDetector.starred?( "Check {Star} this" )
	end

	def test_detects_chinese_important_tag
		assert Pulse::TagDetector.starred?( "需要处理 #重要# 事项" )
	end

	def test_detects_urgent_tag
		assert Pulse::TagDetector.starred?( "Handle #urgent# issue" )
	end

	def test_detects_urgent_case_insensitive
		assert Pulse::TagDetector.starred?( "Handle #URGENT# issue" )
	end

	def test_returns_false_for_plain_text
		refute Pulse::TagDetector.starred?( "Normal status update" )
	end

	def test_returns_false_for_nil
		refute Pulse::TagDetector.starred?( nil )
	end

	def test_returns_false_for_empty_string
		refute Pulse::TagDetector.starred?( "" )
	end

	def test_strips_p0_tag
		result = Pulse::TagDetector.strip( "Deploy %P0% fix immediately" )
		assert_includes result, "Deploy"
		assert_includes result, "fix immediately"
		refute_includes result, "%P0%"
	end

	def test_strips_multiple_tags
		result = Pulse::TagDetector.strip( "%P0% Deploy {star} fix" )
		assert_includes result, "Deploy"
		assert_includes result, "fix"
		refute_includes result, "%P0%"
		refute_includes result, "{star}"
	end

	def test_strips_chinese_important_tag
		result = Pulse::TagDetector.strip( "需要处理 #重要# 事项" )
		assert_includes result, "需要处理"
		assert_includes result, "事项"
		refute_includes result, "#重要#"
	end

	def test_strip_returns_empty_for_nil
		assert_equal "", Pulse::TagDetector.strip( nil )
	end

	def test_strip_preserves_plain_text
		assert_equal "Normal update", Pulse::TagDetector.strip( "Normal update" )
	end
end
