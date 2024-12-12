Welcome to Wordle Solver running against Votee Wordle API
------

This program plays the [Wordle-like](https://www.nytimes.com/games/wordle/index.html) game, the challenge words are generated by https://wordle.votee.dev:8000/redoc API.
It uses a Sqlite English words database and queries against it to guess the correct words, then the program will validate the guessed word with [Votee Wordle API](https://wordle.votee.dev:8000/redoc).

The program is written with:
- Ruby 3
- Sqlite3 gem: https://github.com/sparklemotion/sqlite3-ruby
- The Sqlite regex extension: https://github.com/nalgeon/sqlean/blob/main/docs/regexp.md to implement the `REGEXP` function.
- The English words database is taken from https://github.com/ScriptSmith/topwords

### About the code

- The heart of the game is the data service implemented it `db_service.rb` file where all the follow rules in ChatGPT/LLM prompt are converted to the equivalent SQL condition clauses.
- The game loop is operated by `wordle_solver.rb` file which is also the entrypoint of the program. It basically glues everything together: calls the data service and Votee API.

### Why not ChatGPT/LLM?

I did try ChatGPT and other open-source LLMs (Llama 3 and Mistral) in localhost with [Ollama](https://ollama.com/).
Here was the prompt that I used:
```
You are playing the Wordle game. It is a 5-letter word guessing game.
For each guess, you need to guess a 5-letter one word only that must obey all the following rules:
1. The guess word must be a 5-letter word only.
2. The guess word must be a valid and meaningful English word.
3. The guess word must not be the same as in the "History" list.
4. The guess word must refer to the "Sample" word, if the sample word contains "-" symbol that is the unknown letter. You must replace "-" with the other guessed letter.
5. Use the "Valid letters" list to fill the unknown letter in the sample word. The guess word must contain all the letters in the valid list.
6. The guess word must not contain letters in the "Invalid letters" list provided below.
7. Respond in JSON format, with the guess word in "word" key.
8. Do not return slang or obsolete words, use only common, formal English words in the dictionary.

- History:
  STARE

- Invalid letters: S, T, A, R, E
- Sample: ----Y
- Valid letters: L, Y
```

It's not very optimal yet and I could spend some more time to improve it.
However, the point is that if you look at the rules, you can see that they can be converted to condition clauses in SQL.
That's the reason why I believe using ChatGPT/LLMs is a bit overkill to solve Wordle game.
With a good words database we can totally win the game with normal SQL queries.

### Shortcut to run the solver with Docker (recommended)

```
docker run -it $(docker build -t wordle_solver -q .) --type daily
docker run -it $(docker build -t wordle_solver -q .) --type random
docker run -it $(docker build -t wordle_solver -q .) --type daily --size 8
docker run -it $(docker build -t wordle_solver -q .) --type random --size 8
docker run -it $(docker build -t wordle_solver -q .) --type random --size 8 --seed 10
```

### To debug in the Docker container

```
docker run --entrypoint sh -it $(docker build -t wordle_solver -q .)
bundle console
```

Then you can run the Ruby code:
```ruby
require_relative 'wordle_solver'

s = WordleSolver.new
game = s.guess_daily
game = s.guess_random
game = s.guess_daily(word_size: 6)
game = s.guess_random(seed: 10)
```

### Manual set up (for Linux/Mac)

- Install Ruby 3+ (recommended to install it with https://asdf-vm.com/)
- Install `curl` and `sqlite3`.
- Go to the project root and run:
```
bundle
```
To install required Ruby packages.

- Install https://github.com/nalgeon/sqlpkg-cli, the Sqlite extension manager.
- Install the `nalgeon/regexp` extension so that we can use `REGEXP` function:
```
sqlpkg install nalgeon/regexp
```

- (Optionally) To re-generate the words database:
```
bin/setup_db
```

- (Optionally) For a friendly Sqlite console, install https://github.com/dbcli/litecli

### To run the solver directly from console

```
bin/worlder_solver --type daily
bin/worlder_solver -t daily
bin/worlder_solver --type random
bin/worlder_solver -t random

bin/worlder_solver --type daily --size 8
bin/worlder_solver --type random --size 8
bin/worlder_solver --type random --size 8 --seed 10
```

### To run console

```
bundle console
```

Then you can run the Ruby code:
```ruby
require_relative 'wordle_solver'

s = WordleSolver.new
game = s.guess_daily
```

### Credits

- Words data is taken from https://github.com/ScriptSmith/topwords
- The research document: https://arxiv.org/html/2410.02829v1#S4

### What's next

- Build a web UI.
- Reduce the Docker image size.
- Use a better performant database (e.g. PostgreSQL)
- Write unit tests.
