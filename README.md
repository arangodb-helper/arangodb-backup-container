# Backup Container

This container contains a shell script to dump and restore all
databases of an ArangoDB server (Single Server or Cluster).

You must be able to reach the server from inside the running
container. Please refer to the orchestration guide of your
plattform.

## Authentication

It is important to use a user that has access to all database
you want to dump.

There are two ways to authenticaton in the cluster: using a
username/password (*ARANGO_USERNAME* and *ARANGO_PASSWD*) or a JWT
secret (not yet supported).

In a Kubernetes environment you should store either the password or
the JWT secret in a Kubernetes secret and pass it into the pod. If you
are using the Kubernetes operator, then the JWT secret will already be
available as Kubernetes secret.

For testing purposes you can obviously also pass the password or token
directly in the environment. However, you should avoid this setup in a
production environment.

For other setups, you can also use *ARANGODB_PASSWD_FILE* to pass the
password as a file instead of an environment variable. Please not that
this file is taken without any modification. You need to ensure that
it does not contain any superfluous newlines or carriage returns.

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

    docker run -v /some/large/disk:/backup -e ARANGO_ENDPOINT=tcp://server.name:8529 -e ARANGO_CLEAN_DUMP_DIRECTORY=true arangodb/arangodb-backup backup

## Other Options

`dump` uses `arangodump` and `restore` uses `arangodump` underneath. See [Backup & Restore](https://docs.arangodb.com/3.4/Manual/BackupRestore/)
for details about these programs.
