#!/bin/bash -eu
BASE_DIR=$(
  cd "$(dirname "$0")"
  pwd
)

COMMAND="$1"
shift

cd "${BASE_DIR}"

function main() {
  case "$COMMAND" in
  up)
    echo "docker-compose up -d"
    docker-compose up -d
    ;;
  down)
    echo "docker-compose down"
    docker-compose down
    ;;
  start)
    echo "docker-compose start"
    docker-compose start
    ;;
  stop)
    echo "docker-compose stop"
    docker-compose stop
    ;;
  restart)
    echo "docker-compose restart"
    docker-compose restart
    ;;
  article)
    echo "docker-compose run zenn-cli new:article"
    docker-compose run zenn-cli new:article
    ;;
  book)
    echo "docker-compose run zenn-cli new:book"
    docker-compose run zenn-cli new:book
    ;;
  esac
}

main "$@"
