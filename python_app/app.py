from flask import Flask, render_template
import redis
import os
import sys
import logging
import json
import random

# Set up logging configuration to write to stdout
logging.basicConfig(stream=sys.stdout, level=logging.INFO)

app = Flask(__name__)

# Redis OSS configuration
REDIS_OSS_HOST = os.getenv('REDIS_OSS_HOST', 'redis_oss')
REDIS_OSS_PORT = int(os.getenv('REDIS_OSS_PORT', 6379))

# Redis Enterprise configuration
REDIS_ENTERPRISE_HOST = os.getenv('REDIS_ENTERPRISE_HOST', 'redis_enterprise')
REDIS_ENTERPRISE_PORT = int(os.getenv('REDIS_ENTERPRISE_PORT', 6379))
REDIS_ENTERPRISE_PASSWORD = os.getenv('REDIS_ENTERPRISE_PASSWORD', 'admin')

# Connect to Redis OSS
redis_oss = redis.StrictRedis(host=REDIS_OSS_HOST, port=REDIS_OSS_PORT, decode_responses=True)

# Insert numbers 1 to 100 into Redis OSS as a sorted set
sequential_numbers = {str(num): num for num in range(1, 101)}
redis_oss.zadd('sequential_numbers', sequential_numbers)

# Generate and insert 100 random numbers into Redis OSS as a Sorted Set
random_numbers = {str(num): i for i, num in enumerate(random.sample(range(1, 101), 100))}
redis_oss.zadd('random_numbers', random_numbers)

# Connect to Redis Enterprise
redis_enterprise = redis.StrictRedis(
    host=REDIS_ENTERPRISE_HOST,
    port=REDIS_ENTERPRISE_PORT,
    decode_responses=True
)

# Function to print data from Redis Sorted Set in normal order
def print_sorted_set(redis_instance, key):
    print("Data in Redis Sorted Set (Key:", key, ") from Redis Instance: [", redis_instance, "] with Default Order")
    data = redis_instance.zrange(key, 0, -1, withscores=True)
    for item, score in data:
        print(int(item), end=' ')
    print("\n----------")
    return data

# Function to print data from Redis Sorted Set in reverse order
def print_sorted_set_reverse(redis_instance, key):
    print("Data in Redis Sorted Set (Key:", key, ") from Redis Instance: [", redis_instance, "] with Reverse Order")
    data = redis_instance.zrevrange(key, 0, -1, withscores=True)
    for item, score in data:
        print(int(item), end=' ')
    print("\n----------")
    return data

@app.route('/')
def home():
    return render_template('index.html')

# ---- Sequential Logic ----
@app.route('/load-sequential-redis-oss')
def load_sequential_redis_oss():

    # Source Data in Redis OSS
    # Retrieve Sequential Numbers from Sorted Set in Default Order 
    numbers = print_sorted_set(redis_oss, 'sequential_numbers')

    return json.dumps(numbers)

@app.route('/load-sequential-redis-enterprise')
def load_sequential_redis_enterprise():

    # Replicated Data in Redis Enterprise from Redis OSS
    # Retrieve Sequential Numbers from Sorted Set in Reverse Order 
    reversed_numbers = print_sorted_set_reverse(redis_enterprise, 'sequential_numbers')
    
    return json.dumps(reversed_numbers)

# ---- Random Logic ----
@app.route('/load-random-redis-oss')
def load_random_redis_oss():

    # Source Data in Redis OSS
    # Retrieve Random Numbers from Sorted Set in Default Order
    numbers = print_sorted_set(redis_oss, 'random_numbers')

    return json.dumps(numbers)

@app.route('/load-random-redis-enterprise')
def load_random_redis_enterprise():

    # Replicated Data in Redis Enterprise from Redis OSS
    # Retrieve Random Numbers from Sorted Set in Reverse Order 
    reversed_numbers = print_sorted_set_reverse(redis_enterprise, 'random_numbers')
    
    return json.dumps(reversed_numbers)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=15000)
