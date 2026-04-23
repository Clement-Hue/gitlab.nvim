describe("hunks.lua", function()
  local hunks = require("gitlab.hunks")

  describe("parse_possible_hunk_headers", function()
    it("parses a standard hunk header", function()
      local hunk = hunks.parse_possible_hunk_headers("@@ -10,3 +10,5 @@ some context")
      assert.are.same({ old_line = 10, old_range = 3, new_line = 10, new_range = 5 }, hunk)
    end)

    it("parses hunk header with zero range", function()
      local hunk = hunks.parse_possible_hunk_headers("@@ -5,0 +6,3 @@")
      assert.are.same({ old_line = 5, old_range = 0, new_line = 6, new_range = 3 }, hunk)
    end)

    it("parses hunk header without range values", function()
      local hunk = hunks.parse_possible_hunk_headers("@@ -23 +23 @@")
      assert.are.same({ old_line = 23, old_range = 0, new_line = 23, new_range = 0 }, hunk)
    end)

    it("returns nil for non-hunk lines", function()
      assert.is_nil(hunks.parse_possible_hunk_headers("+added line"))
      assert.is_nil(hunks.parse_possible_hunk_headers("-removed line"))
      assert.is_nil(hunks.parse_possible_hunk_headers(" context line"))
    end)
  end)

  describe("_line_was_added", function()
    it("detects a simple added line", function()
      local diff_output = {
        "@@ -5,0 +6,2 @@",
        "+line_a",
        "+line_b",
      }
      local hunk = { old_line = 5, old_range = 0, new_line = 6, new_range = 2 }
      assert.is_true(hunks._line_was_added(6, hunk, diff_output))
      assert.is_true(hunks._line_was_added(7, hunk, diff_output))
      assert.is_false(hunks._line_was_added(5, hunk, diff_output))
      assert.is_false(hunks._line_was_added(8, hunk, diff_output))
    end)

    it("detects added lines in a mixed hunk (deletions + additions)", function()
      local diff_output = {
        "@@ -10,2 +10,3 @@",
        "-old1",
        "-old2",
        "+new1",
        "+new2",
        "+new3",
      }
      local hunk = { old_line = 10, old_range = 2, new_line = 10, new_range = 3 }
      assert.is_true(hunks._line_was_added(10, hunk, diff_output))
      assert.is_true(hunks._line_was_added(11, hunk, diff_output))
      assert.is_true(hunks._line_was_added(12, hunk, diff_output))
      assert.is_false(hunks._line_was_added(9, hunk, diff_output))
      assert.is_false(hunks._line_was_added(13, hunk, diff_output))
    end)

    it("handles 'no newline at end of file' marker", function()
      local diff_output = {
        "@@ -10,0 +11,1 @@",
        "+new_line",
        "\\ No newline at end of file",
      }
      local hunk = { old_line = 10, old_range = 0, new_line = 11, new_range = 1 }
      assert.is_true(hunks._line_was_added(11, hunk, diff_output))
      assert.is_false(hunks._line_was_added(12, hunk, diff_output))
    end)

    it("works with multiple hunks and finds the correct one", function()
      local diff_output = {
        "@@ -3,0 +4,1 @@",
        "+first_addition",
        "@@ -20,0 +22,2 @@",
        "+second_a",
        "+second_b",
      }
      local hunk2 = { old_line = 20, old_range = 0, new_line = 22, new_range = 2 }
      assert.is_true(hunks._line_was_added(22, hunk2, diff_output))
      assert.is_true(hunks._line_was_added(23, hunk2, diff_output))
      assert.is_false(hunks._line_was_added(4, hunk2, diff_output))
    end)

    it("returns false for a deleted line in a mixed hunk", function()
      local diff_output = {
        "@@ -10,1 +10,1 @@",
        "-old_line",
        "+new_line",
      }
      local hunk = { old_line = 10, old_range = 1, new_line = 10, new_range = 1 }
      assert.is_true(hunks._line_was_added(10, hunk, diff_output))
    end)
  end)

  describe("_line_was_removed", function()
    it("detects a simple removed line", function()
      local diff_output = {
        "@@ -5,2 +5,0 @@",
        "-removed_a",
        "-removed_b",
      }
      local hunk = { old_line = 5, old_range = 2, new_line = 5, new_range = 0 }
      assert.is_true(hunks._line_was_removed(5, hunk, diff_output))
      assert.is_true(hunks._line_was_removed(6, hunk, diff_output))
      assert.is_false(hunks._line_was_removed(4, hunk, diff_output))
      assert.is_false(hunks._line_was_removed(7, hunk, diff_output))
    end)

    it("detects removed lines in a mixed hunk", function()
      local diff_output = {
        "@@ -10,3 +10,1 @@",
        "-old1",
        "-old2",
        "-old3",
        "+new1",
      }
      local hunk = { old_line = 10, old_range = 3, new_line = 10, new_range = 1 }
      assert.is_true(hunks._line_was_removed(10, hunk, diff_output))
      assert.is_true(hunks._line_was_removed(11, hunk, diff_output))
      assert.is_true(hunks._line_was_removed(12, hunk, diff_output))
      assert.is_false(hunks._line_was_removed(13, hunk, diff_output))
    end)

    it("handles 'no newline at end of file' marker", function()
      local diff_output = {
        "@@ -10,1 +10,0 @@",
        "-removed_line",
        "\\ No newline at end of file",
      }
      local hunk = { old_line = 10, old_range = 1, new_line = 10, new_range = 0 }
      assert.is_true(hunks._line_was_removed(10, hunk, diff_output))
      assert.is_false(hunks._line_was_removed(11, hunk, diff_output))
    end)

    it("does not detect added lines as removed", function()
      local diff_output = {
        "@@ -10,1 +10,2 @@",
        "-old_line",
        "+new_line_a",
        "+new_line_b",
      }
      local hunk = { old_line = 10, old_range = 1, new_line = 10, new_range = 2 }
      assert.is_true(hunks._line_was_removed(10, hunk, diff_output))
      assert.is_false(hunks._line_was_removed(11, hunk, diff_output))
    end)
  end)
end)
