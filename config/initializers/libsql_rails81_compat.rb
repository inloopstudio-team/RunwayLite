# Patch libsql_activerecord (v0.0.2) for Rails 8.1 compatibility.
#
# Fixes:
# 1. Column.new signature changed in Rails 8.1 (added cast_type as 2nd arg)
# 2. extract_value_from_default doesn't handle TRUE/FALSE boolean defaults
# 3. Missing insert_all / upsert support (needed by SolidCable, SolidQueue, SolidCache)
# 4. Uses default ToSql Arel visitor instead of SQLite visitor (FOR UPDATE unsupported)
# 5. Missing class-level quote_column_name (Rails 8.1 requires it for insert_all)

if defined?(ActiveRecord::ConnectionAdapters::LibsqlAdapter)
  # --- Class-level quoting (Rails 8.1 requires these for insert_all) ---
  ActiveRecord::ConnectionAdapters::LibsqlAdapter.singleton_class.class_eval do
    def quote_column_name(column_name)
      column_name = column_name.to_s
      if column_name == column_name.upcase || column_name =~ /\W/
        "\"#{column_name.gsub('"', '""')}\""
      else
        "\"#{column_name}\""
      end
    end
  end

  ActiveRecord::ConnectionAdapters::LibsqlAdapter.class_eval do
    # --- Use SQLite Arel visitor (strips FOR UPDATE, handles LIMIT -1 for OFFSET) ---

    def arel_visitor
      Arel::Visitors::SQLite.new(self)
    end

    # --- Insert on conflict support (SQLite supports ON CONFLICT since 3.24) ---

    def supports_insert_on_conflict?
      true
    end
    alias supports_insert_on_duplicate_skip? supports_insert_on_conflict?
    alias supports_insert_on_duplicate_update? supports_insert_on_conflict?
    alias supports_insert_conflict_target? supports_insert_on_conflict?

    def supports_insert_returning?
      true
    end

    def build_insert_sql(insert)
      sql = +"INSERT #{insert.into} #{insert.values_list}"

      if insert.skip_duplicates?
        sql << " ON CONFLICT #{insert.conflict_target} DO NOTHING"
      elsif insert.update_duplicates?
        sql << " ON CONFLICT #{insert.conflict_target} DO UPDATE SET "
        if insert.raw_update_sql?
          sql << insert.raw_update_sql
        else
          sql << insert.touch_model_timestamps_unless { |column| "#{column} IS excluded.#{column}" }
          sql << insert.updatable_columns.map { |column| "#{column}=excluded.#{column}" }.join(",")
        end
      end

      sql << " RETURNING #{insert.returning}" if insert.returning
      sql
    end

    private

    # --- Column.new signature fix ---

    def new_column_from_field(_table_name, field, definitions)
      default = field["dflt_value"]

      type_metadata = fetch_type_metadata(field["type"])
      cast_type = lookup_cast_type(field["type"])
      default_value = extract_value_from_default(default)
      generated_type = extract_generated_type(field)

      default_function =
        if generated_type.present?
          default
        else
          extract_default_function(default_value, default)
        end

      rowid = column_the_rowid?(field, definitions)

      ActiveRecord::ConnectionAdapters::Column.new(
        field["name"],
        cast_type,
        default_value,
        type_metadata,
        field["notnull"].to_i.zero?,
        default_function,
        collation: field["collation"],
        auto_increment: field["auto_increment"],
        rowid:,
        generated_type:
      )
    end

    # --- Boolean default fix ---

    def extract_value_from_default(default)
      case default
      when /^null$/i then nil
      when /^true$/i then "1"
      when /^false$/i then "0"
      when /^'([^|]*)'$/m then ::Regexp.last_match(1).gsub("''", "'")
      when /^"([^|]*)"$/m then ::Regexp.last_match(1).gsub('""', '"')
      when /\A-?\d+(\.\d*)?\z/ then ::Regexp.last_match(0)
      when /x'(.*)'/ then [ ::Regexp.last_match(1) ].pack("H*")
      end
    end
  end
end
