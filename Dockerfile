FROM ruby:3.3.6-slim

# The app lives here
WORKDIR /app

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl sqlite3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install Sqlite extension manager (https://github.com/nalgeon/sqlpkg-cli)
RUN curl -sS https://webi.sh/sqlpkg | sh
RUN ~/.local/bin/sqlpkg install nalgeon/regexp

ENV WORDLE_SQLPKG_PATH="~/.local/bin/sqlpkg"

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application code
COPY . .

ENTRYPOINT ["/app/bin/wordle_solver"]
