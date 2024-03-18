# Task Requirements

- Use Redis OSS and configure to run it on port 10001
- Use Memtier Benchmark to load data into Redis OSS and capture generated keys
- Use Redis Enterprise and create a database which replicates data from Redis OSS
- Create a script/app that:
  - Inserts 1-100 sequentially in Redis OSS and prints in reverse order from Redis Enterprise
  - Inserts 100 random values in Redis OSS and prints in reverse order from Redis Enterprise

# Run

- Pre-requisites: Docker + Docker Compose + Git
```bash
# On Ubuntu
sudo apt-get update -y && sudo apt-get install -y docker.io docker-compose git
```

- Run the following command in a Unix Shell 
```bash
git clone https://github.com/harshvyas/myredistask.git && cd myredistask
sh run.sh
```
- Access the python app at `http://<localhost | ipaddress>:15000`

# Result
[test](./static/perm.webm)
- Logs (Click to Zoom)
![screenshot_2024-03-17_16 19 17](https://github.com/harshvyas/myredistask/assets/2585335/49e8eded-7cc7-4d74-8c10-8cfdbf4c5d6b)

- WebApp (Click to Zoom)
![screenshot_2024-03-17_16 13 42](https://github.com/harshvyas/myredistask/assets/2585335/dcb3f28f-d7df-4473-8b9f-4cdf22fb7527)

# Implementation

- Used Docker Compose to setup Redis OSS, Redis Enterprise, Memtier Benchmark and a Python App
  - Redis OSS configured to run on port 10001
  - Memtier loads 1000 keys into Redis OSS
  - Redis Enterprise cluster created with database as the target replica of Redis OSS source database accessible on port 10001
  
- Python App built using Flask, loads/reterives sequential and random values in Redis using Sorted Set data structure 
  - At startup
    - Establishes connection to both Redis OSS and Redis Enterprise on startup 
    - Inserts all (1-100) sequential numbers with scores ranging from 1-100 into Redis OSS as sorted set using `ZADD` in a single network request
    - Inserts all 100 random numbers between 1 and 100 with scores assigned based on the order of insertion into Redis OSS as sorted set using `ZADD` in a single network request
  - `ZRANGE` and `ZREVRANGE` makes it simple and efficient to get data in both ascending and descending order directly from Redis
  - Sorted Set - Cons: 
    - Slightly higher memory overhead for storing of scores alongside elements
    - O(log N) complexity for inserting
  - Alternatively, Redis Lists could have been used
  - Lists - Cons: 
    - Printing in reverse would require additional logic in the python code 
    - O(N) complexity for retrieval of full dataset

# Miscellaneous Step by Step Details

<details>

- Use `sudo` if needed

## 1. Clone 

```bash
git clone https://github.com/harshvyas/myredistask.git && cd myredistask
```

## 2. Build 

```bash
docker-compose build
```

## 3. Start

```bash
docker-compose up -d
```

## 4. Check Redis OSS Logs 

```bash
docker-compose logs my_redis_oss
```

## 5. Check Redis Enterprise Logs

```bash
docker-compose logs my_redis_enterprise
```

## 6. Check Memtier Logs

```bash
docker-compose logs my_memtier_benchmark | more
```

## 7. Check Memtier Result

```bash
docker exec -it `docker ps -aqf "name=my_redis_oss"` bash -c 'redis-cli -p 10001 KEYS "memtier-*"' > keys.txt && cat keys.txt
```

## 8. Setup Cluster and Create Database in Redis Enterprise cluster.local to replicate from Redis OSS

```bash
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
```

## 9. Watch Python App Logs

```bash
docker-compose logs -f my_python_app
```

## 10. Validate from browser 

- http://localhost:15000

## 11. Sample Output from Python App logs after clicking buttons 1,2,3,4 in UI

```bash
my_python_app-1  | Data in Redis Sorted Set (Key: sequential_numbers ) from Redis Instance: [ Redis<ConnectionPool<Connection<host=my_redis_oss,port=10001,db=0>>> ] with Default Order
my_python_app-1  | 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100 
my_python_app-1  | ----------
my_python_app-1  | INFO:werkzeug:192.168.112.1 - - [17/Mar/2024 15:31:28] "GET /load-sequential-redis-oss HTTP/1.1" 200 -
my_python_app-1  | Data in Redis Sorted Set (Key: sequential_numbers ) from Redis Instance: [ Redis<ConnectionPool<Connection<host=my_redis_enterprise,port=12000,db=0>>> ] with Reverse Order
my_python_app-1  | 100 99 98 97 96 95 94 93 92 91 90 89 88 87 86 85 84 83 82 81 80 79 78 77 76 75 74 73 72 71 70 69 68 67 66 65 64 63 62 61 60 59 58 57 56 55 54 53 52 51 50 49 48 47 46 45 44 43 42 41 40 39 38 37 36 35 34 33 32 31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 
my_python_app-1  | ----------
my_python_app-1  | INFO:werkzeug:192.168.112.1 - - [17/Mar/2024 15:31:30] "GET /load-sequential-redis-enterprise HTTP/1.1" 200 -
my_python_app-1  | Data in Redis Sorted Set (Key: random_numbers ) from Redis Instance: [ Redis<ConnectionPool<Connection<host=my_redis_oss,port=10001,db=0>>> ] with Default Order
my_python_app-1  | 50 24 5 58 70 47 63 57 95 93 59 17 34 96 51 77 94 76 4 67 91 80 1 83 53 35 52 64 22 33 38 28 62 73 16 89 78 19 69 100 54 12 2 90 85 18 61 56 44 43 32 36 13 97 8 75 3 30 45 72 66 71 21 41 55 40 37 87 25 15 31 46 9 65 10 27 84 11 92 82 26 81 23 20 74 68 6 99 49 79 39 42 98 86 60 48 14 29 7 88 
my_python_app-1  | ----------
my_python_app-1  | INFO:werkzeug:192.168.112.1 - - [17/Mar/2024 15:31:31] "GET /load-random-redis-oss HTTP/1.1" 200 -
my_python_app-1  | Data in Redis Sorted Set (Key: random_numbers ) from Redis Instance: [ Redis<ConnectionPool<Connection<host=my_redis_enterprise,port=12000,db=0>>> ] with Reverse Order
my_python_app-1  | 88 7 29 14 48 60 86 98 42 39 79 49 99 6 68 74 20 23 81 26 82 92 11 84 27 10 65 9 46 31 15 25 87 37 40 55 41 21 71 66 72 45 30 3 75 8 97 13 36 32 43 44 56 61 18 85 90 2 12 54 100 69 19 78 89 16 73 62 28 38 33 22 64 52 35 53 83 1 80 91 67 4 76 94 77 51 96 34 17 59 93 95 57 63 47 70 58 5 24 50 
my_python_app-1  | ----------
my_python_app-1  | INFO:werkzeug:192.168.112.1 - - [17/Mar/2024 15:31:33] "GET /load-random-redis-enterprise HTTP/1.1" 200 -
```

## 12. Kill

```bash
docker-compose down
```
</details>
