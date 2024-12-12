require 'sqlite3'

class DbService
  # DATABASE_FILE = 'data/Dictionary.db'.freeze
  DATABASE_FILE = 'data/en_dict.db'.freeze

  class << self
    def db
      @db ||= SQLite3::Database.new(DATABASE_FILE).tap do |db|
        prepare_regex_func(db)
      end
    end

    def find_word(used_words:, word_pattern:, valid_letters: [], invalid_letters: [], invalid_patterns: [])
      conditions = prepare_conditions(used_words:, invalid_patterns:)
      sql = <<~SQL
        SELECT word FROM entries
        WHERE #{conditions}
        LIMIT 1
      SQL

      # Use positive-lookahead to make sure string contains all the valid letters.
      # Ex: /(?=.*a)(?=.*b)(?=.*c)/
      valid_regex = valid_letters.map {|l| "(?=.*#{l})" }.join

      # Use '(?i)' for case-insensitive matching.
      # See https://github.com/nalgeon/sqlean/blob/main/docs/regexp.md
      valid_regex = "(?i)#{valid_regex}"
      invalid_regex = "(?i)[#{invalid_letters.join}]"
      db.execute(sql, valid_regex:, invalid_regex:, word_pattern:).flatten.first
    end

    def find_random_word(word_pattern: '_____')
      sql = <<~SQL
        SELECT word FROM entries
        WHERE
          word LIKE :word_pattern
          AND word REGEXP '^[A-Za-z]+$'
        LIMIT 1
      SQL

      db.execute(sql, word_pattern:).flatten.first
    end

    private

    # Sqlite does not implement REGEX function by default,
    # so we need to add the extension for it.
    # See https://github.com/nalgeon/sqlean/blob/main/docs/regexp.md
    def prepare_regex_func(db)
      db.enable_load_extension(true)
      db.load_extension(regex_extension_path)
    end

    def regex_extension_path
      # Require https://github.com/nalgeon/sqlpkg-cli
      `#{sqlpkg_path} which nalgeon/regexp`.strip
    end

    def sqlpkg_path
      ENV.fetch('WORDLE_SQLPKG_PATH') { 'sqlpkg' }
    end

    def prepare_conditions(used_words: [], invalid_patterns: [])
      used_words = used_words.map {|w| "'#{w}'" }.join(', ')
      conditions = [
        "word NOT IN(#{used_words})",
        'word REGEXP :valid_regex',
        'word NOT REGEXP :invalid_regex',
        'word LIKE :word_pattern',
        "word REGEXP '^[A-Za-z]+$'" # Ensure word contains only alphabets
      ]

      invalid_patterns.map do |pattern|
        conditions << "word NOT LIKE '#{pattern}'"
      end

      conditions.join(' AND ')
    end
  end
end
