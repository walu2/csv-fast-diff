# This library performs diffs of flat file content that contains structured data
# in fields, with rows provided in a parent-child format.
#
# Parent-child data does not lend itself well to standard text diffs, as small
# changes in the organisation of the tree at an upper level (e.g. re-ordering of
# two ancestor nodes) can lead to big movements in the position of descendant
# records - particularly when the parent-child data is generated by a hierarchy
# traversal.
#
# Additionally, simple line-based diffs can identify that a line has changed,
# but not which field(s) in the line have changed.
#
# Data may be supplied in the form of CSV files, or as an array of arrays. The
# diff process process provides a fine level of control over what to diff, and
# can optionally ignore certain types of changes (e.g. changes in order).
class CSVDiff

    # @return [CSVSource] CSVSource object containing details of the left/from
    #    input.
    attr_reader :left
    alias_method :from, :left
    # @return [CSVSource] CSVSource object containing details of the right/to
    #    input.
    attr_reader :right
    alias_method :to, :right
    # @return [Array<Hash>] An array of differences
    attr_reader :diffs
    # @return [Array<String>] An array of field names that are compared in the
    #    diff process.
    attr_reader :diff_fields
    # @return [Array<String>] An array of field namees of the key fields that
    #    uniquely identify each row.
    attr_reader :key_fields
    # @return [Array<String>] An array of field names for the parent field(s).
    attr_reader :parent_fields
    # @return [Array<String>] An array of field names for the child field(s).
    attr_reader :child_fields
    # @return [Hash] The options hash used for the diff.
    attr_reader :options


    # Generates a diff between two hierarchical tree structures, provided
    # as +left+ and +right+, each of which consists of an array of lines in CSV
    # format.
    # An array of field indexes can also be specified as +key_fields+;
    # a minimum of one field index must be specified; the last index is the
    # child id, and the remaining fields (if any) are the parent field(s) that
    # uniquely qualify the child instance.
    #
    # @param left [Array|String|CSVSource] An Array of lines, each of which is in
    #   an Array of fields, or a String specifying a path to a CSV file, or a
    #   CSVSource object.
    # @param right [Array|String|CSVSource] An Array of lines, each of which is
    #   an Array of fields, or a String specifying a path to a CSV file, or a
    #   CSVSource object.
    # @param options [Hash] A hash containing options.
    # @option options [String] :encoding The encoding to use when opening the
    #   CSV files.
    # @option options [Array<String>] :field_names An Array of field names for
    #   each field in +left+ and +right+. If not provided, the first row is
    #   assumed to contain field names.
    # @option options [Boolean] :ignore_header If true, the first line of each
    #   file is ignored. This option can only be true if :field_names is
    #   specified.
    # @options options [Array] :ignore_fields The names of any fields to be
    #   ignored when performing the diff.
    # @option options [String] :key_field The name of the field that uniquely
    #   identifies each row.
    # @option options [Array<String>] :key_fields The names of the fields
    #   that uniquely identifies each row.
    # @option options [String] :parent_field The name of the field that
    #   identifies a parent within which sibling order should be checked.
    # @option options [String] :child_field The name of the field that
    #   uniquely identifies a child of a parent.
    # @option options [Boolean] :ignore_adds If true, records that appear in
    #   the right/to file but not in the left/from file are not reported.
    # @option options [Boolean] :ignore_updates If true, records that have been
    #   updated are not reported.
    # @option options [Boolean] :ignore_moves If true, changes in row position
    #   amongst sibling rows are not reported.
    # @option options [Boolean] :ignore_deletes If true, records that appear
    #   in the left/from file but not in the right/to file are not reported.
    def initialize(left, right, options = {})
        @left = left.is_a?(CSVSource) ? left : CSVSource.new(left, options)
        raise "No field names found in left (from) source" unless @left.field_names && @left.field_names.size > 0
        @right = right.is_a?(CSVSource) ? right : CSVSource.new(right, options)
        raise "No field names found in right (to) source" unless @right.field_names && @right.field_names.size > 0
        @warnings = []
        @diff_fields = get_diff_fields(@left.field_names, @right.field_names, options[:ignore_fields])
        @key_fields = @left.key_fields.map{ |kf| @diff_fields[kf] }
        diff(options)
    end


    # Performs a diff with the specified +options+.
    def diff(options = {})
        @summary = nil
        @diffs = diff_sources(@left, @right, @key_fields, @diff_fields, options)
        @options = options
    end


    # Returns a summary of the number of adds, deletes, moves, and updates.
    def summary
        unless @summary
            @summary = Hash.new{ |h, k| h[k] = 0 }
            @diffs.each{ |k, v| @summary[v[:action]] += 1 }
            @summary['Warning'] = warnings.size if warnings.size > 0
        end
        @summary
    end


    [:adds, :deletes, :updates, :moves].each do |mthd|
        define_method mthd do
            action = mthd.to_s.chomp('s')
            @diffs.select{ |k, v| v[:action].downcase == action }
        end
    end


    # @return [Array<String>] an array of warning messages generated from the
    #    sources and the diff process.
    def warnings
        @left.warnings + @right.warnings + @warnings
    end


    # @return [Array<String>] an array of warning messages from the diff process.
    def diff_warnings
        @warnings
    end


    private


    # Given two sets of field names, determines the common set of fields present
    # in both, on which members can be diffed.
    def get_diff_fields(left_fields, right_fields, ignore_fields)
        diff_fields = []
        right_fields.each_with_index do |fld, i|
            if left_fields.include?(fld)
                diff_fields << fld unless ignore_fields && (ignore_fields.include?(fld) ||
                                                            ignore_fields.include?(i))
            else
                @warnings << "Field '#{fld}' is missing from the left (from) file, and won't be diffed"
            end
        end
        diff_fields
    end


    include Algorithm

end
