#!/bin/bash

# === MongoDB Sharded Cluster Setup Script ===
# Run as root: sudo ./setup_mongo_cluster.sh

echo "[INFO] Creating MongoDB data directories..."
cd /var/lib/mongodb/
mkdir -p velo_mongo && cd velo_mongo
mkdir -p cfg0 cfg1 cfg2
mkdir -p s0_0 s0_1 s1_0 s1_1 s2_0 s2_1 

echo "[INFO] Starting Config Server replica set members..."
mongod --configsvr --dbpath cfg0 --port 26050 --replSet cfg --fork --logpath log.cfg0
mongod --configsvr --dbpath cfg1 --port 26051 --replSet cfg --fork --logpath log.cfg1
mongod --configsvr --dbpath cfg2 --port 26052 --replSet cfg --fork --logpath log.cfg2
sleep 5

echo "[INFO] Initiating Config Server replica set..."
mongosh --port 26050 --eval '
rs.initiate({
  _id: "cfg",
  configsvr: true,
  members: [
    { _id: 0, host: "localhost:26050" },
    { _id: 1, host: "localhost:26051" },
    { _id: 2, host: "localhost:26052" }
  ]
})
'
sleep 5

echo "[INFO] Starting Shard 0 replica set..."
mongod --shardsvr --replSet s0 --dbpath s0_0 --port 26000 --fork --logpath log.s0_0
mongod --shardsvr --replSet s0 --dbpath s0_1 --port 26001 --fork --logpath log.s0_1
sleep 5

echo "[INFO] Initiating Shard 0..."
mongosh --port 26000 --eval '
rs.initiate({
  _id: "s0",
  members: [
    { _id: 0, host: "localhost:26000" },
    { _id: 1, host: "localhost:26001" }
  ]
})
'
sleep 5

echo "[INFO] Starting Shard 1 replica set..."
mongod --shardsvr --replSet s1 --dbpath s1_0 --port 26100 --fork --logpath log.s1_0
mongod --shardsvr --replSet s1 --dbpath s1_1 --port 26101 --fork --logpath log.s1_1
sleep 5

echo "[INFO] Initiating Shard 1..."
mongosh --port 26100 --eval '
rs.initiate({
  _id: "s1",
  members: [
    { _id: 0, host: "localhost:26100" },
    { _id: 1, host: "localhost:26101" }
  ]
})
'
sleep 5

echo "[INFO] Starting Shard 2 replica set..."
mongod --shardsvr --replSet s2 --dbpath s2_0 --port 26200 --fork --logpath log.s2_0
mongod --shardsvr --replSet s2 --dbpath s2_1 --port 26201 --fork --logpath log.s2_1
sleep 5

echo "[INFO] Initiating Shard 2..."
mongosh --port 26200 --eval '
rs.initiate({
  _id: "s2",
  members: [
    { _id: 0, host: "localhost:26200" },
    { _id: 1, host: "localhost:26201" }
  ]
})
'
sleep 5

echo "[INFO] Starting mongos router..."
mongos --configdb "cfg/localhost:26050,localhost:26051,localhost:26052" --fork --logpath log.mongos1 --port 26061
sleep 5

echo "[INFO] Adding shards to mongos..."
mongosh --port 26061 --eval '
sh.addShard("s0/localhost:26000,localhost:26001");
sh.addShard("s1/localhost:26100,localhost:26101");
sh.addShard("s2/localhost:26200,localhost:26201");
'

echo "[SUCCESS] MongoDB sharded cluster is up and running!"
