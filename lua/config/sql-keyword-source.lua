-- Static SQL keyword/function/type completion source for blink.cmp.
--
-- Why this exists: postgres_lsp (postgres-language-server) builds its entire
-- completion list from a live database schema. With no reachable DB it returns
-- ZERO items, so SQL buffers get diagnostics but no `SELECT`/`JOIN`/`coalesce`
-- suggestions -- the layer VSCode's SQL extensions ship as a baked-in word list.
-- This source supplies exactly that layer, in-process, with no DB and no plugin.
--
-- Performance notes (this runs on the completion path, so it matters):
--   * The word list is bucketed by first letter ONCE, lazily, on first request.
--     Later requests touch one bucket (~10-40 words), never the full ~450.
--   * Items are built fresh every request on purpose. blink mutates them --
--     `list.lua` does `item.score_offset = (item.score_offset or 0) + offset`,
--     which COMPOUNDS, and pins `cursor_column` to its first value. Returning
--     cached item tables makes scores drift upward and text edits land at a
--     stale column. Do NOT "optimize" this into a shared table.
--   * Case follows what you typed: lowercase prefix gives lowercase words. The
--     two variants are built and cached separately, so this costs one compare.
--   * Only the passed context is read (`ctx.line` / `ctx.bounds`) -- no Vim API
--     calls, so it is safe in blink's fast-event path.

local Kind = vim.lsp.protocol.CompletionItemKind

-- Keywords win over types and functions on collision (LEFT, RIGHT, REPLACE),
-- so a word appears exactly once. Dedup below is by lowercase form.
local KEYWORDS = {
  "ADD",
  "ALL",
  "ALTER",
  "ANALYZE",
  "AND",
  "ANY",
  "AS",
  "ASC",
  "BEGIN",
  "BETWEEN",
  "BOTH",
  "BY",
  "CASCADE",
  "CASE",
  "CAST",
  "CHECK",
  "COLLATE",
  "COLUMN",
  "COMMENT",
  "COMMIT",
  "CONCURRENTLY",
  "CONFLICT",
  "CONSTRAINT",
  "COPY",
  "CREATE",
  "CROSS",
  "CUBE",
  "CURRENT_DATE",
  "CURRENT_ROLE",
  "CURRENT_SCHEMA",
  "CURRENT_TIME",
  "CURRENT_TIMESTAMP",
  "CURRENT_USER",
  "CURSOR",
  "CYCLE",
  "DATABASE",
  "DECLARE",
  "DEFAULT",
  "DEFERRABLE",
  "DEFERRED",
  "DELETE",
  "DESC",
  "DISTINCT",
  "DO",
  "DOMAIN",
  "DROP",
  "EACH",
  "ELSE",
  "END",
  "ESCAPE",
  "EXCEPT",
  "EXCLUDE",
  "EXCLUDING",
  "EXECUTE",
  "EXISTS",
  "EXPLAIN",
  "EXTENSION",
  "FALSE",
  "FETCH",
  "FILTER",
  "FIRST",
  "FOLLOWING",
  "FOR",
  "FOREIGN",
  "FROM",
  "FULL",
  "FUNCTION",
  "GENERATED",
  "GRANT",
  "GROUP",
  "GROUPING",
  "HAVING",
  "IF",
  "ILIKE",
  "IMMUTABLE",
  "IN",
  "INCLUDE",
  "INCLUDING",
  "INDEX",
  "INHERITS",
  "INITIALLY",
  "INNER",
  "INSERT",
  "INSTEAD",
  "INTERSECT",
  "INTO",
  "IS",
  "JOIN",
  "KEY",
  "LANGUAGE",
  "LAST",
  "LATERAL",
  "LEADING",
  "LEFT",
  "LIKE",
  "LIMIT",
  "LOCK",
  "MATCH",
  "MATERIALIZED",
  "NATURAL",
  "NEW",
  "NEXT",
  "NO",
  "NOT",
  "NOTHING",
  "NOTIFY",
  "NULL",
  "NULLS",
  "OF",
  "OFFSET",
  "OLD",
  "ON",
  "ONLY",
  "OR",
  "ORDER",
  "OTHERS",
  "OUTER",
  "OVER",
  "OVERLAPS",
  "OWNER",
  "PARTITION",
  "PERFORM",
  "POLICY",
  "PRECEDING",
  "PRIMARY",
  "PROCEDURE",
  "PUBLICATION",
  "RAISE",
  "RANGE",
  "REFERENCES",
  "REFRESH",
  "REINDEX",
  "RENAME",
  "REPLACE",
  "RESTRICT",
  "RETURN",
  "RETURNING",
  "RETURNS",
  "REVOKE",
  "RIGHT",
  "ROLE",
  "ROLLBACK",
  "ROLLUP",
  "ROW",
  "ROWS",
  "RULE",
  "SAVEPOINT",
  "SCHEMA",
  "SECURITY",
  "SELECT",
  "SEQUENCE",
  "SESSION_USER",
  "SET",
  "SETOF",
  "SHOW",
  "SIMILAR",
  "SOME",
  "STABLE",
  "START",
  "STATEMENT",
  "STORED",
  "STRICT",
  "SUBSCRIPTION",
  "SYMMETRIC",
  "TABLE",
  "TABLESAMPLE",
  "TABLESPACE",
  "TEMP",
  "TEMPORARY",
  "THEN",
  "TIES",
  "TO",
  "TRAILING",
  "TRANSACTION",
  "TRIGGER",
  "TRUE",
  "TRUNCATE",
  "TYPE",
  "UNBOUNDED",
  "UNION",
  "UNIQUE",
  "UNLOGGED",
  "UPDATE",
  "USER",
  "USING",
  "VACUUM",
  "VALUES",
  "VARIADIC",
  "VIEW",
  "VOLATILE",
  "WHEN",
  "WHERE",
  "WHILE",
  "WINDOW",
  "WITH",
  "WITHIN",
  "WITHOUT",
  "WORK",
  "ZONE",
}

local TYPES = {
  "bigint",
  "bigserial",
  "bit",
  "boolean",
  "box",
  "bytea",
  "char",
  "character",
  "cidr",
  "circle",
  "citext",
  "date",
  "daterange",
  "decimal",
  "float4",
  "float8",
  "inet",
  "int",
  "int2",
  "int4",
  "int8",
  "int4range",
  "int8range",
  "integer",
  "interval",
  "json",
  "jsonb",
  "line",
  "lseg",
  "macaddr",
  "money",
  "numeric",
  "numrange",
  "path",
  "point",
  "polygon",
  "real",
  "serial",
  "smallint",
  "smallserial",
  "text",
  "time",
  "timestamp",
  "timestamptz",
  "timetz",
  "tsquery",
  "tsrange",
  "tstzrange",
  "tsvector",
  "uuid",
  "varbit",
  "varchar",
  "xml",
}

local FUNCTIONS = {
  "abs",
  "age",
  "array_agg",
  "array_length",
  "array_position",
  "array_remove",
  "array_to_string",
  "avg",
  "bit_length",
  "bool_and",
  "bool_or",
  "btrim",
  "cardinality",
  "ceil",
  "char_length",
  "coalesce",
  "concat",
  "concat_ws",
  "count",
  "cume_dist",
  "current_database",
  "current_setting",
  "date_bin",
  "date_part",
  "date_trunc",
  "decode",
  "dense_rank",
  "encode",
  "every",
  "exp",
  "extract",
  "first_value",
  "floor",
  "format",
  "gen_random_uuid",
  "generate_series",
  "greatest",
  "initcap",
  "json_agg",
  "json_build_object",
  "jsonb_agg",
  "jsonb_array_elements",
  "jsonb_build_object",
  "jsonb_each",
  "jsonb_object_keys",
  "jsonb_set",
  "jsonb_strip_nulls",
  "jsonb_typeof",
  "justify_interval",
  "lag",
  "last_value",
  "lead",
  "least",
  "length",
  "ln",
  "log",
  "lower",
  "lpad",
  "ltrim",
  "make_date",
  "make_interval",
  "make_timestamp",
  "max",
  "md5",
  "min",
  "mod",
  "now",
  "nth_value",
  "ntile",
  "nullif",
  "num_nonnulls",
  "octet_length",
  "overlay",
  "percent_rank",
  "percentile_cont",
  "percentile_disc",
  "pg_typeof",
  "position",
  "power",
  "quote_ident",
  "quote_literal",
  "radians",
  "random",
  "rank",
  "regexp_matches",
  "regexp_replace",
  "regexp_split_to_array",
  "regexp_split_to_table",
  "repeat",
  "reverse",
  "round",
  "row_number",
  "rpad",
  "rtrim",
  "sign",
  "split_part",
  "sqrt",
  "starts_with",
  "stddev",
  "string_agg",
  "strpos",
  "substr",
  "substring",
  "sum",
  "to_char",
  "to_date",
  "to_json",
  "to_jsonb",
  "to_number",
  "to_timestamp",
  "translate",
  "trim",
  "trunc",
  "unnest",
  "upper",
  "var_pop",
  "var_samp",
  "variance",
  "width_bucket",
}

--- Buckets keyed by lowercase first letter: buckets[case][letter] = { {label, kind}, ... }
--- Built on first completion request, then reused for the rest of the session.
--- @type table<string, table<string, { label: string, kind: integer }[]>>|nil
local buckets = nil

local function build_buckets()
  local upper, lower, seen = {}, {}, {}

  local function add(word, kind)
    local key = word:lower()
    if seen[key] then
      return
    end
    seen[key] = true

    local letter = key:sub(1, 1)
    upper[letter] = upper[letter] or {}
    lower[letter] = lower[letter] or {}
    table.insert(upper[letter], { label = word:upper(), kind = kind })
    table.insert(lower[letter], { label = key, kind = kind })
  end

  for _, word in ipairs(KEYWORDS) do
    add(word, Kind.Keyword)
  end
  for _, word in ipairs(TYPES) do
    add(word, Kind.Struct)
  end
  for _, word in ipairs(FUNCTIONS) do
    add(word, Kind.Function)
  end

  return { upper = upper, lower = lower }
end

--- @class blink.cmp.SqlKeywordSource : blink.cmp.Source
local Source = {}

function Source.new()
  return setmetatable({}, { __index = Source })
end

--- Only ever registered for `sql` via sources.per_filetype, so no filetype check here.
function Source:get_completions(ctx, callback)
  local bounds = ctx.bounds
  local typed = ctx.line:sub(bounds.start_col, bounds.start_col + bounds.length - 1)
  local letter = typed:sub(1, 1):lower()

  local empty = { is_incomplete_forward = false, is_incomplete_backward = false, items = {} }
  if letter == "" or not letter:match("%a") then
    callback(empty)
    return
  end

  buckets = buckets or build_buckets()
  -- An uppercase first character means the user writes SQL in caps; match it.
  local bucket = buckets[typed:sub(1, 1):match("%u") and "upper" or "lower"][letter]
  if not bucket then
    callback(empty)
    return
  end

  local items = {}
  for i, entry in ipairs(bucket) do
    items[i] = { label = entry.label, kind = entry.kind, insertText = entry.label }
  end

  callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
end

return Source
