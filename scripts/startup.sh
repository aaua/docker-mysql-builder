#!/usr/bin/env sh
log () {
  echo "[`date +"%Y/%m/%d %H:%M:%S"`] $1"
}

BASE_IMAGE=mysql-base
TMP_CONTAINER=mysql-base
BUILD_IMAGE=mysql-with-data

log '** Build Start ***'
cd `dirname $0`

log '* Start Docker Deamon'
dockerd &
until docker images 2>/dev/null | grep -c REPOSITORY; do
    sleep 1
done

# TODO: awscliの認証
log '* AWS CLI Info'
aws configure list

# TODO: RDSのバックアップから新規RDSを作成

# TODO: データのマスキング

log '* MySQL Dumping'
mysqldump -h$ORIGIN_HOST -P$ORIGIN_PORT -u$ORIGIN_USER -p$ORIGIN_PASS $ORIGIN_DB_NAME -d --databases --default-character-set=binary > schema.sql
mysqldump -h$ORIGIN_HOST -P$ORIGIN_PORT -u$ORIGIN_USER -p$ORIGIN_PASS $ORIGIN_DB_NAME -t --default-character-set=binary > data.sql

# TODO: 新規RDSの削除

log '* Build MySQL Container'
docker build -t $BASE_IMAGE -f ./Dockerfile .

log '* Start MySQL Container'
docker run --name $TMP_CONTAINER -p 3306:3306 -e MYSQL_ALLOW_EMPTY_PASSWORD=yes -e MYSQL_ROOT_PASSWORD="" -d $BASE_IMAGE
until mysqladmin ping -h127.0.0.1 -uroot --silent; do
    log '.'
    sleep 1
done

log '* Import MySQL'
mysql -h127.0.0.1 -uroot < schema.sql
mysql -h127.0.0.1 -uroot $ORIGIN_DB_NAME < data.sql

log '* Commit Docker Image'
docker stop $TMP_CONTAINER
docker commit $TMP_CONTAINER $BUILD_IMAGE:latest
docker images

# TODO: ECR push

log '** Build Complete!! ***'
