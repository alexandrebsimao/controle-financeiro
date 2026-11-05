FROM ruby:3.4.1

RUN apt-get update -qq && apt-get install -y postgresql-client build-essential libpq-dev git curl
RUN mkdir /myapp
WORKDIR /myapp

RUN gem install bundler

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . /myapp

# Precompile assets during build
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]