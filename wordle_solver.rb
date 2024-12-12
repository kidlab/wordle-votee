require 'json'
require 'net/http'
require_relative 'db_service'

class WordleSolver
  STARTING_WORD = 'stare'.freeze
  API_HOST = 'https://wordle.votee.dev:8000'.freeze
  MAX_TRIES = 26

  # A data object to store the history of a guess attempt, just for reference.
  Attempt = Struct.new(
    :guessed_word, :valid_letters, :invalid_letters, :word_pattern,
    :invalid_pattern, :success, :result
  )

  # To store data of a guess game
  class GameData
    attr_accessor :attempts, :word_size, :word,
                  :used_words, :valid_letters, :invalid_letters,
                  :invalid_patterns, :word_pattern

    def initialize(word_size: 5)
      @attempts = []
      @word_size = word_size
      @used_words = []
      @valid_letters = Set.new
      @invalid_letters = Set.new
      @invalid_patterns = Set.new
      # Wildcard match all words by default.
      @word_pattern = '_' * word_size
    end

    def starting_word
      word_size == 5 ? STARTING_WORD : DbService.find_random_word(word_pattern:)
    end

    def in_progress?
      attempts.size < MAX_TRIES && word.nil?
    end
  end

  def guess_daily(word_size: 5)
    guess('/daily', word_size:)
  end

  def guess_random(word_size: 5, seed: rand(100))
    guess('/random', word_size:, seed:)
  end

  private

  def guess(api_path, word_size: 5, **other_params)
    game = GameData.new(word_size:)
    guessed_word = game.starting_word

    while game.in_progress?
      guessed_word ||= find_word(game)
      raise("No guessed word found.\n#{game.inspect}") unless guessed_word

      puts("=========== Attempt #{game.attempts.size}:", game.inspect, guessed_word)

      response = send_get_request(api_path, guess: guessed_word, size: word_size, **other_params)

      data = JSON.parse(response.body)
      analyze_result = analyze_response(word_size, data)
      attempt = Attempt.new(guessed_word:, **analyze_result)

      update_game_data(game, attempt)

      if attempt.success
        game.word = guessed_word
        puts "Word found!: #{guessed_word}"
        break
      end

      # Reset guessed word.
      guessed_word = nil
    end

    game
  end

  def find_word(game)
    DbService.find_word(
      used_words: game.used_words,
      valid_letters: game.valid_letters,
      invalid_letters: game.invalid_letters,
      invalid_patterns: game.invalid_patterns,
      word_pattern: game.word_pattern
    )&.downcase
  end

  def update_game_data(game, attempt)
    game.attempts << attempt
    game.used_words << attempt.guessed_word
    game.invalid_patterns << attempt.invalid_pattern
    game.word_pattern = attempt.word_pattern
    game.valid_letters += attempt.valid_letters
    game.invalid_letters += attempt.invalid_letters
  end

  def send_get_request(path, **params)
    # URI.encode_www_form encodes Symbol differently,
    # so we need to make sure keys are strings.
    params = params.transform_keys(&:to_s)
    params = URI.encode_www_form(params)
    Net::HTTP.get_response(URI("#{API_HOST}#{path}?#{params}"))
  end

  def analyze_response(word_size, data)
    word_pattern = '_' * word_size
    invalid_pattern = '_' * word_size
    result = '_' * word_size
    valid_letters = Set.new
    invalid_letters = Set.new

    data.each_with_index do |item, idx|
      guess = item['guess']
      case item['result']
      when 'absent'
        invalid_letters << guess
        invalid_pattern[idx] = guess
        result[idx] = 'A'
      when 'present'
        valid_letters << guess
        invalid_pattern[idx] = guess
        result[idx] = 'P'
      when 'correct'
        valid_letters << guess
        word_pattern[idx] = guess
        result[idx] = 'C'
      end
    end

    success = !word_pattern.include?('_')
    {valid_letters:, invalid_letters:, word_pattern:, invalid_pattern:, success:, result:}
  end
end
