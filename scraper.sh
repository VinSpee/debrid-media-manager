#!/bin/bash

function find_free_port() {
    port=$(shuf -i 1024-65535 -n 1)
    while netstat -an | grep -q LISTEN:$port; do
        port=$(shuf -i 1024-65535 -n 1)
    done
    echo $port
}

function wait_for_healthz_ok() {
    local url="$1"
    local response=""
    while true; do
        response=$(curl -s "$url" | jq -r '.status')
        if [ "$response" == "ok" ]; then
            break
        else
            sleep 1
        fi
    done
}

function launch_scraper() {
    DMM_PATH="/home/ben/debrid-media-manager"
    echo "$0"
    echo "$(readlink -f $0)"

    echo "Launching scraper ($DMM_PATH): $1..."

    if [ "$1" = "upkeep" ]; then
        SESSION_NAME="upkeep"
        tmux new-session -d -s upkeep

        # requested
        tmux new-window -t upkeep:1 -n requested
        PORT=$(find_free_port)
        tmux send-keys -t upkeep:1 "cd $DMM_PATH && npm start -- -p $PORT && exit" C-m
        wait_for_healthz_ok "http://localhost:$PORT/api/healthz"
        tmux send-keys -t upkeep:0 "curl \"http://localhost:$PORT/api/upkeep/requested\" &" C-m

        # stuck
        tmux new-window -t upkeep:2 -n stuck
        PORT=$(find_free_port)
        tmux send-keys -t upkeep:2 "cd $DMM_PATH && npm start -- -p $PORT && exit" C-m
        wait_for_healthz_ok "http://localhost:$PORT/api/healthz"
        tmux send-keys -t upkeep:0 "curl \"http://localhost:$PORT/api/upkeep/stuck\" &" C-m

        # empty
        tmux new-window -t upkeep:5 -n empty
        PORT=$(find_free_port)
        tmux send-keys -t upkeep:5 "cd $DMM_PATH && npm start -- -p $PORT && exit" C-m
        wait_for_healthz_ok "http://localhost:$PORT/api/healthz"
        tmux send-keys -t upkeep:0 "curl \"http://localhost:$PORT/api/stuck/empty?quantity=3\" &" C-m

        # done!
        sleep 3
        tmux kill-window -t upkeep:0

    elif [ "$1" = "newepisodes" ]; then
        PARAM="46119"
        SLUG=$(curl -s "https://mdblist.com/api/lists/$PARAM/?apikey=55gg408ja72aa3f5d5p90w4zu" | jq -r '.[0].slug')
        PORT=$(find_free_port)
        SESSION_NAME="$SLUG-$PORT"
        AGE="0"
        tmux new-session -d -s $SESSION_NAME
        tmux send-keys -t $SESSION_NAME:0 "cd $DMM_PATH && npm start -- -p $PORT && exit" C-m
        sleep 3
        tmux new-window -t $SESSION_NAME:1
        tmux send-keys -t $SESSION_NAME:1 "curl \"http://localhost:$PORT/api/scrapers/singlelist?skipMs=1&rescrapeIfXDaysOld=$AGE&quantity=5&listId=$PARAM&lastSeason=true\"" C-m
        sleep 3
        tmux kill-window -t $SESSION_NAME:1

    elif [ "$1" = "newreleases" ]; then
        PARAM="46446"
        SLUG=$(curl -s "https://mdblist.com/api/lists/$PARAM/?apikey=55gg408ja72aa3f5d5p90w4zu" | jq -r '.[0].slug')
        PORT=$(find_free_port)
        SESSION_NAME="$SLUG-$PORT"
        AGE="0"
        tmux new-session -d -s $SESSION_NAME
        tmux send-keys -t $SESSION_NAME:0 "cd $DMM_PATH && npm start -- -p $PORT && exit" C-m
        sleep 3
        tmux new-window -t $SESSION_NAME:1
        tmux send-keys -t $SESSION_NAME:1 "curl \"http://localhost:$PORT/api/scrapers/singlelist?skipMs=1&rescrapeIfXDaysOld=$AGE&quantity=5&listId=$PARAM&lastSeason=true\"" C-m
        sleep 3
        tmux kill-window -t $SESSION_NAME:1

    elif [ "$1" = "torrentio" ]; then
        PORT=$(find_free_port)
        SESSION_NAME="torrentio-$PORT"
        tmux new-session -d -s $SESSION_NAME
        tmux send-keys -t $SESSION_NAME:0 "cd $DMM_PATH && npm start -- -p $PORT && exit" C-m
        sleep 3
        tmux new-window -t $SESSION_NAME:1
        tmux send-keys -t $SESSION_NAME:1 "curl \"http://localhost:$PORT/api/scrapers/torrentio\"" C-m
        sleep 3
        tmux kill-window -t $SESSION_NAME:1

    elif [[ "$1" =~ ^tt[a-z0-9]{3,20}$ ]]; then
        PARAM="$1"
        PORT=$(find_free_port)
        SESSION_NAME="$PARAM-$PORT"
        AGE="$2"
        tmux new-session -d -s $SESSION_NAME
        tmux send-keys -t $SESSION_NAME:0 "cd $DMM_PATH && npm start -- -p $PORT && exit" C-m
        sleep 3
        tmux new-window -t $SESSION_NAME:1
        tmux send-keys -t $SESSION_NAME:1 "curl \"http://localhost:$PORT/api/scrapers/imdb?replaceOldScrape=false&id=$PARAM\"" C-m
        sleep 3
        tmux kill-window -t $SESSION_NAME:1

    elif [[ "$1" =~ ^rtt[a-z0-9]{3,20}$ ]]; then
        PARAM="${1#r}"
        PORT=$(find_free_port)
        SESSION_NAME="$PARAM-$PORT"
        AGE="$2"
        tmux new-session -d -s $SESSION_NAME
        tmux send-keys -t $SESSION_NAME:0 "cd $DMM_PATH && npm start -- -p $PORT && exit" C-m
        sleep 3
        tmux new-window -t $SESSION_NAME:1
        tmux send-keys -t $SESSION_NAME:1 "curl \"http://localhost:$PORT/api/scrapers/imdb?replaceOldScrape=true&id=$PARAM\"" C-m
        sleep 3
        tmux kill-window -t $SESSION_NAME:1

    elif [[ "$1" =~ ^[a-z]{3,20}$ ]]; then
        PARAM="$1"
        PORT=$(find_free_port)
        SESSION_NAME="$PARAM-$PORT"
        AGE="$2"
        tmux new-session -d -s $SESSION_NAME
        tmux send-keys -t $SESSION_NAME:0 "cd $DMM_PATH && npm start -- -p $PORT && exit" C-m
        sleep 3
        tmux new-window -t $SESSION_NAME:1
        tmux send-keys -t $SESSION_NAME:1 "curl \"http://localhost:$PORT/api/scrapers/listoflists?skipMs=1&rescrapeIfXDaysOld=$AGE&quantity=3&search=$PARAM\"" C-m
        sleep 3
        tmux kill-window -t $SESSION_NAME:1

    else
        PARAM="$1"
        SLUG=$(curl -s "https://mdblist.com/api/lists/$PARAM/?apikey=55gg408ja72aa3f5d5p90w4zu" | jq -r '.[0].slug')
        PORT=$(find_free_port)
        SESSION_NAME="$SLUG-$PORT"
        AGE="$2"
        tmux new-session -d -s $SESSION_NAME
        tmux send-keys -t $SESSION_NAME:0 "cd $DMM_PATH && npm start -- -p $PORT && exit" C-m
        sleep 3
        tmux new-window -t $SESSION_NAME:1
        tmux send-keys -t $SESSION_NAME:1 "curl \"http://localhost:$PORT/api/scrapers/singlelist?skipMs=1&rescrapeIfXDaysOld=$AGE&quantity=3&listId=$PARAM\"" C-m
        sleep 3
        tmux kill-window -t $SESSION_NAME:1
    fi

    tmux ls | grep $SESSION_NAME
    echo "Launched $SESSION_NAME"
}
