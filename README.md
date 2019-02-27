# Backup Container

This container contains a shell script to dump and restore all
databases of an ArangoDB server (Single Server or Cluster).

You must be able to reach the server from inside the running
container. Please refer to the orchestration guide of your
plattform.

It is important to use a user that has access to all database
you want to dump.

## Usage

usage: backup.sh (dump|restore) <passthrough options>

the following environment variables will be recognized:
 - ARANGO_ENDPOINT
 - ARANGO_USERNAME
 - ARANGO_PASSWD
 - ARANGO_CLEAN_DUMP_DIRECTORY
 - ARANGO_DUMP_DIRECTORY
 - ARANGO_DUMP_THREADS
 - ARANGO_LOGFILE

The default dump directory is `/backup/dump`. If you run the docker
container then the `/backup` dictory should be mounted to a volume
large enough to hold the dump data.

A typical usage is

    docker run -v /some/large/disk:/backup -e ARANGO_ENDPOINT=tcp://server.name:8529 -e ARANGO_USERNAME=root -e ARANGO_PASSWD=abc arangodb/arangodb-backup backup

## Other Options

`dump` uses `arangodump` and `restore` uses `arangodump` underneath. See [Backup & Restore](https://docs.arangodb.com/3.4/Manual/BackupRestore/)
for details about these programs.
