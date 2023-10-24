#! /bin/sh

set -eu
set -o pipefail

source ./env.sh

echo "Creating backup of $POSTGRES_DATABASE database..."
pg_dump --format=custom \
        -h $POSTGRES_HOST \
        -p $POSTGRES_PORT \
        -U $POSTGRES_USER \
        -d $POSTGRES_DATABASE \
        $PGDUMP_EXTRA_OPTS \
        > db.dump

timestamp=$(date +"%Y-%m-%dT%H-%M-%S")
datetime=$(date +"%Y-%m-%d")
s3_uri_base="s3://${S3_BUCKET}/${S3_PREFIX}"

if [ -n "$PASSPHRASE" ]; then
  echo "Encrypting backup..."
  gpg --symmetric --batch --passphrase "$PASSPHRASE" db.dump
  rm db.dump
  local_file="db.dump.gpg"
  s3_uri="$s3_uri_base/${datetime}/${timestamp}.gpg"
else
  local_file="db.dump"
  s3_uri="$s3_uri_base/${datetime}/${timestamp}.dump"
fi

echo "Uploading backup to $S3_BUCKET..."
echo $s3_uri
echo $s3_uri_base
s4cmd put "$local_file" "$s3_uri" $aws_args
rm "$local_file"
echo "Backup complete."

if [ -n "$BACKUP_KEEP_DAYS" ]; then
  sec=$((86400*BACKUP_KEEP_DAYS))
  timestamp=$(date -d "@$(($(date +%s) - sec))" +%Y-%m-%d)
  s3_uri_del="${s3_uri_base}/${timestamp}"

  echo "Removing old backups from $S3_BUCKET..."
  echo $s3_uri_del
  s4cmd del -r "${s3_uri_del}" $aws_args
  echo "Removal complete."
fi
