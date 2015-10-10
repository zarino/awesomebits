#!/bin/bash

set -e

bundle install
bundle exec rake db:migrate
bundle exec rake db:seed
bundle exec rails s -p 3000 -b '0.0.0.0'