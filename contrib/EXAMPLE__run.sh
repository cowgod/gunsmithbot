#!/bin/bash

export BUNGIE_API_TOKEN=<xxxxxxx>
export GUNSMITH_BOT_USERNAME=<xxxxxxx>
export ENVIRONMENT=production
export GUNSMITH_DB_HOST=<xxxxxxx>
export GUNSMITH_DB_USERNAME=<xxxxxxx>
export GUNSMITH_DB_PASSWORD=<xxxxxxx>
export GUNSMITH_DB_NAME=<xxxxxxx>

export SLACK_API_TOKEN=<xxxxxxx>
### OR
###export DISCORD_API_TOKEN=<xxxxxxx>


ruby ./app/slack_runner.rb
### OR
###ruby ./app/discord_runner.rb
