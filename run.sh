#!/bin/sh

# Run docker info command
docker info

# Check the exit status of the docker info command
if [ $? -eq 0 ]; then
    echo "Docker daemon is accessible."
else
    echo "This script requires sudo privileges as the Docker daemon is not accessible."
    if [ "$(id -u)" -eq 0 ]; then
        echo "The script is already running as root. Exiting."
        exit 1
    fi
    echo "Restarting script execution with sudo..."
    exec sudo sh run.sh # Execute the script with sudo
    exit 1
fi

# check if working directory is the cloned repository
if ! [ -f run.sh ] || ! [ -f docker-compose.yml ]; then
    echo "Please run this script from the root of the repository."
    exit 1
fi

# check if docker and docker compose are available
if ! [ -x "$(command -v docker)" ]; then
    echo "Docker is not installed. Please install Docker and try again."
    exit 1
fi

if ! [ -x "$(command -v docker-compose)" ]; then
    echo "Docker Compose is not installed. Please install Docker Compose and try again."
    exit 1
fi

# stop any currently running instances
if ! [ -x "$(docker ps | grep myredis)" ]; then
    echo "There are currently running instances. Stopping them."
    docker-compose down
fi

# build
echo "Building Docker images..."
docker-compose build

# run
echo "Starting Docker containers..."
docker-compose up -d

# wait for redis enterprise to become healthy
echo "Waiting for Redis Enterprise bootstrap to become healthy..."
until curl -k https://localhost:8443 >/dev/null 2>&1; do
    echo "Waiting for Redis Enterprise bootstrap to become healthy...";
    sleep 60;
done

# create redis enterprise cluster and database for replication
echo "Creating Redis Enterprise cluster and database with replication enabled from Redis OSS..."
docker exec -it `docker ps -aqf "name=my_redis_enterprise"` bash -c '\
    until curl -k https://localhost:9443 >/dev/null 2>&1; \
        do \
            echo "Waiting for Redis Enterprise service to become healthy..."; \
            sleep 5; \
        done \
    && /opt/redislabs/bin/rladmin cluster create name cluster.local username admin@example.com password admin ; \
    sleep 60 ; \
    until curl -u admin@example.com:admin -k https://localhost:9443/v1/clusters >/dev/null 2>&1; \
        do \
            echo "Waiting for Redis Enterprise cluster to become healthy..."; \
            sleep 5; \
        done \
    && curl -u admin@example.com:admin -k -X POST -f https://localhost:9443/v1/bdbs \
    -H "Content-type: application/json" \
    -d '\''{"name":"test","port":12000,"memory_size":107374182,"replica_sources":[{"uri":"redis://my_redis_oss:10001","server_cert":""}],"replica_sync":"enabled"}'\'''

# dump keys from Redis OSS created by Memtier
echo "Loading all memtier keys from Redis OSS into keys.txt"
docker exec -it `docker ps -aqf "name=my_redis_oss"` bash -c 'redis_conn="redis-cli -p 10001 --raw"; cursor=0; \
    while [ true ]; do \
        result=$($redis_conn -p 10001 SCAN $cursor MATCH "memtier-*"); \
        cursor=$(echo $result | cut -d" " -f1 | tr -d "[:space:]"); \
        keys=$(echo $result | cut -d" " -f2-); \
        for key in $keys; do echo "Key: $key"; done; \
        if [ "$cursor" -eq 0 ]; then break; fi; \
    done' > keys.txt && sort -t"-" -k2n keys.txt

# validate python app endpoints
echo "---------------------------------------"
echo "Validating Python app endpoints..."
sleep 30
curl --retry 10 --retry-delay 5 --fail -s -o /dev/null -w "%{http_code}" http://localhost:15000 && echo " - Python app is running"
echo "---------------------------------------"
curl --retry 10 --retry-delay 5 --fail localhost:15000/load-sequential-redis-oss && echo " - Sequential load test for Redis OSS"
echo "---------------------------------------"
curl --retry 10 --retry-delay 5 --fail localhost:15000/load-sequential-redis-enterprise && echo " - Sequential load test for Redis Enterprise"
echo "---------------------------------------"
curl --retry 10 --retry-delay 5 --fail localhost:15000/load-random-redis-oss && echo " - Random load test for Redis OSS"
echo "---------------------------------------"
curl --retry 10 --retry-delay 5 --fail localhost:15000/load-random-redis-enterprise && echo " - Random load test for Redis Enterprise"
echo "---------------------------------------"

echo "All done. Enjoy!"
