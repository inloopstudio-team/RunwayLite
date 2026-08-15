# Patch libsql_activerecord (v0.0.2) for Rails 8.1 compatibility.
#
# Sources:
#   - Our own fixes for Rails 8.1 API changes
#   - libsql_activerecord PR: capability flags (PATCH 1)
#   - libsql_activerecord PR: perform_query routing fix (PATCH 2)
#
# Fixes:
# 1.  Column.new signature changed in Rails 8.1 (added cast_type as 2nd arg)
# 2.  extract_value_from_default doesn't handle TRUE/FALSE boolean defaults
# 3.  Missing insert_all / upsert support (needed by SolidCable, SolidQueue, SolidCache)
# 4.  Uses default ToSql Arel visitor instead of SQLite visitor (FOR UPDATE unsupported)
# 5.  Missing class-level quote_column_name (Rails 8.1 requires it for insert_all)
# 6.  default_insert_value emits DEFAULT which libSQL rejects; substitute actual defaults
# 7.  disable_referential_integrity not implemented; FK constraints break fixture loading
# 8.  Libsql::Statement#convert doesn't handle Ruby booleans; maps true/false to 1/0
# 9.  libsql returns strings with ASCII-8BIT encoding; force UTF-8 at result time
# 10. Missing supports_*? capability flags cause Rails to make wrong SQL assumptions
# 11. perform_query routes on column_count.zero? which is unreliable for getter PRAGMAs
# 12. begin/commit/rollback_db_transaction are no-ops in AbstractAdapter; implement for libsql
# 13. translate_exception: libsql raises RuntimeError for constraint violations; map to AR exceptions
# 14. add_foreign_key unsupported on existing tables in SQLite; make it a no-op
# 15. :jsonb is PostgreSQL-only; alias to :json so shared migrations run on libSQL

# Fix 9: libsql returns strings with ASCII-8BIT encoding; force UTF-8 at result time.
if defined?(Libsql::Rows)
  Libsql::Rows.prepend(Module.new do
    def to_a
      super.map do |row|
        row.transform_values do |v|
          v.is_a?(String) && v.encoding == Encoding::ASCII_8BIT ? v.force_encoding("UTF-8") : v
        end
      end
    end
  end)
end

# Fix 8: Libsql::Statement#convert doesn't handle Ruby booleans (true/false).
# Rails passes type-cast bind values which include native Ruby booleans for
# boolean columns. Map them to SQLite integers (1/0) before handing off.
if defined?(Libsql::Statement)
  Libsql::Statement.prepend(Module.new do
    private

    def convert(value)
      case value
      when true  then CLibsql.libsql_integer(1)
      when false then CLibsql.libsql_integer(0)
      else super
      end
    end
  end)
end

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
    # Fix 12 (critical): AbstractAdapter's begin/commit/rollback_db_transaction
    # are no-ops. Without these, Rails test transactions never actually BEGIN,
    # so test isolation (use_transactional_tests) doesn't work at all.
    #
    # libsql has PRAGMA foreign_keys = ON by default. PRAGMA foreign_keys
    # can only be changed OUTSIDE a transaction (inside is a no-op). So we
    # turn FK off before BEGIN and restore it after ROLLBACK/COMMIT, which
    # lets fixture loading proceed without FK order constraints.
    def begin_db_transaction
      execute("PRAGMA foreign_keys = OFF")
      execute("BEGIN")
    end

    def commit_db_transaction
      execute("COMMIT")
      execute("PRAGMA foreign_keys = ON") rescue nil
    end

    def rollback_db_transaction
      execute("ROLLBACK") rescue nil
      execute("PRAGMA foreign_keys = ON") rescue nil
    end

    # Fix 13: libsql raises RuntimeError for constraint violations; translate to
    # proper ActiveRecord exceptions so rescue_from and tests work correctly.
    def translate_exception(exception, message:, sql:, binds:)
      msg = exception.message.to_s
      if msg.include?("UNIQUE constraint failed")
        ActiveRecord::RecordNotUnique.new(message, sql: sql, binds: binds)
      elsif msg.include?("FOREIGN KEY constraint failed")
        ActiveRecord::InvalidForeignKey.new(message, sql: sql, binds: binds)
      elsif msg.include?("NOT NULL constraint failed")
        ActiveRecord::NotNullViolation.new(message, sql: sql, binds: binds)
      else
        super
      end
    end

    # Fix 14: SQLite/libSQL only supports FOREIGN KEY in CREATE TABLE, not
    # via ALTER TABLE ADD CONSTRAINT. Make add/remove foreign key no-ops so
    # migrations that use foreign_key: true still add the column and index
    # without trying to issue unsupported SQL.
    def add_foreign_key(from_table, to_table = nil, **options)
      # no-op: FK constraints unsupported on existing tables in SQLite/libSQL
    end

    def remove_foreign_key(from_table, to_table = nil, **options)
      # no-op
    end

    def foreign_keys(table_name, name: nil)
      []
    end

    # Fix 15: :jsonb is PostgreSQL-only. Alias to :json so shared migrations run on libSQL.
    def type_to_sql(type, limit: nil, precision: nil, scale: nil, **)
      super(type.to_sym == :jsonb ? :json : type, limit: limit, precision: precision, scale: scale)
    end

    # Fix 10 (PATCH 1): Declare full SQLite capability set so Rails doesn't
    # fall back to lowest-common-denominator SQL generation.
    def supports_ddl_transactions?       = true
    def supports_savepoints?             = true
    def supports_transaction_isolation?  = true
    def supports_partial_index?          = true
    def supports_expression_index?       = true
    def supports_foreign_keys?           = true
    def supports_check_constraints?      = true
    def supports_views?                  = true
    def supports_datetime_with_precision? = true
    def supports_json?                   = true
    def supports_common_table_expressions? = true
    def supports_virtual_columns?        = true
    def supports_insert_returning?       = true
    def supports_insert_on_conflict?     = true
    alias supports_insert_on_duplicate_skip?   supports_insert_on_conflict?
    alias supports_insert_on_duplicate_update? supports_insert_on_conflict?
    alias supports_insert_conflict_target?     supports_insert_on_conflict?

    # Fix 11 (PATCH 2): column_count.zero? returns 0 for getter PRAGMAs
    # (e.g. PRAGMA table_xinfo) even though they yield rows, causing the schema
    # cache to see empty columns. Keep the original column_count routing but
    # carve out getter PRAGMAs so they use stmt.query and return their rows.
    # DDL (CREATE/ALTER/DROP) and setter PRAGMAs (PRAGMA x = y) have column_count 0
    # and no result rows, so they correctly stay on the execute path.
    def perform_query(raw_connection, sql, binds, type_casted_binds, prepare:, notification_payload:, batch: false)
      _ = prepare
      _ = notification_payload
      _ = binds

      if batch
        raw_connection.execute_batch(sql)
      else
        stmt = raw_connection.prepare(sql)
        begin
          result =
            if stmt.column_count.zero? && !getter_pragma?(sql)
              @last_affected_rows = stmt.execute(type_casted_binds)
              ActiveRecord::Result.empty
            else
              rows = stmt.query(type_casted_binds)
              @last_affected_rows = nil
              ActiveRecord::Result.new(rows.columns, rows.to_a.map(&:values))
            end
        ensure
          stmt.close
        end
      end
      verified!
      result
    end

    # Fix 4: Use SQLite Arel visitor (strips FOR UPDATE, handles LIMIT -1 for OFFSET)
    def arel_visitor
      Arel::Visitors::SQLite.new(self)
    end

    # Fix 3: Insert on conflict support (SQLite supports ON CONFLICT since 3.24)
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

    # Fix 6: libSQL/SQLite does not support DEFAULT in INSERT VALUES.
    # Rails 8.1 emits Arel.sql("DEFAULT") for fixture columns not present in the
    # fixture file. Override at the source so the value is never emitted.
    def default_insert_value(column)
      if column.default.nil?
        Arel.sql("NULL")
      else
        Arel.sql(quote(column.default))
      end
    end

    # Fix 7: FK is handled in begin_db_transaction (OFF before BEGIN, ON after).
    # PRAGMA foreign_keys cannot be changed inside a transaction — yield only.
    def disable_referential_integrity
      yield
    end

    private

    # Returns true for getter PRAGMAs (PRAGMA name or PRAGMA name(...))
    # which return rows but have column_count 0 in libsql.
    # Returns false for setter PRAGMAs (PRAGMA name = value) which don't return rows.
    def getter_pragma?(sql)
      sql.match?(/\A\s*PRAGMA\s+\w+\s*(?:\(|$)/i)
    end

    # Fix 1 (PATCH 2): Column.new signature — Rails 8.1 added cast_type as 2nd arg
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

    # Fix 2: Boolean defaults — libSQL stores TRUE/FALSE literals; map to "1"/"0"
    def extract_value_from_default(default)
      case default
      when /^null$/i  then nil
      when /^true$/i  then "1"
      when /^false$/i then "0"
      when /^'([^|]*)'$/m  then ::Regexp.last_match(1).gsub("''", "'")
      when /^"([^|]*)"$/m  then ::Regexp.last_match(1).gsub('""', '"')
      when /\A-?\d+(\.\d*)?\z/ then ::Regexp.last_match(0)
      when /x'(.*)'/ then [ ::Regexp.last_match(1) ].pack("H*")
      end
    end
  end

  # Fix 15 (cont): patch the migration DSL objects so `t.jsonb` and
  # `t.add_column ..., :jsonb` resolve to :text on libSQL.
  [ ActiveRecord::ConnectionAdapters::TableDefinition,
    ActiveRecord::ConnectionAdapters::Table ].each do |klass|
    klass.class_eval do
      def jsonb(name, **options)
        options[:default] = options[:default].to_json if options[:default].is_a?(Array) || options[:default].is_a?(Hash)
        column(name, :json, **options)
      end
    end
  end

  # Fix 17: remove_index generates "DROP INDEX name ON table" — SQLite syntax is
  # "DROP INDEX name" with no ON clause. Intercept and issue correct SQL.
  ActiveRecord::ConnectionAdapters::LibsqlAdapter.class_eval do
    def remove_index(table_name, column_name = nil, **options)
      index_name = options[:name] || index_name(table_name, column_name)
      execute("DROP INDEX IF EXISTS #{quote_column_name(index_name)}")
    end
  end

  # Fix 16: SQLite does not support ALTER TABLE ... ALTER COLUMN for nullability.
  # change_column_null is a no-op — constraints are enforced at the app layer.
  # Also: add_column with :jsonb type needs Hash/Array defaults serialized to JSON.
  ActiveRecord::ConnectionAdapters::LibsqlAdapter.class_eval do
    def change_column_null(table_name, column_name, null, default = nil)
      # no-op: SQLite cannot alter column constraints after creation
    end

    def add_column(table_name, column_name, type, **options)
      if type.to_sym == :jsonb
        type = :json
        options[:default] = options[:default].to_json if options[:default].is_a?(Array) || options[:default].is_a?(Hash)
      end
      super(table_name, column_name, type, **options)
    end
  end
end
