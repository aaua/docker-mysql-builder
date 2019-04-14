#!/usr/bin/env sh
log () {
  echo "[`date +"%Y/%m/%d %H:%M:%S"`] $1"
}

aurora_cluster_wait_available () {
  log "wait abailable ${1}"
  while :
  do
    AURORA_CLUSTER_STATUS=$(aws rds describe-db-clusters \
      --db-cluster-identifier ${1} \
      --query "DBClusters[].Status" \
      --output text)
    if [ "${AURORA_CLUSTER_STATUS}" != "available" ]; then
      log '.'
      sleep 10
    else
      break
    fi
  done
}

rds_wait_available () {
  log "wait abailable ${1}"
  while :
  do
    RDS_STATUS=$(aws rds describe-db-instances \
      --db-instance-identifier ${1} \
      --query "DBInstances[].DBInstanceStatus" \
      --output text)
    if [ "${RDS_STATUS}" != "available" ]; then
      log '.'
      sleep 10
    else
      break
    fi
  done
}

aurora_cluster_wait_members_null () {
  log "wait cluster wait menbers null ${1}"
  while :
  do
    AURORA_CLUSTER_MEMBERS=$(aws rds describe-db-clusters \
      --db-cluster-identifier ${1} \
      --query "Clusters[].DBClusterMembers[]")
    if [ "${AURORA_CLUSTER_MEMBERS}" != "null" ]; then
      log '.'
      sleep 10
    else
      break
    fi
  done
}

BASE_IMAGE=mysql-base
TMP_CONTAINER=mysql-base
TMP_CLUSTER_MEMBER=${TMP_CLUSTER}-member

log '** Build Start ***'
cd `dirname $0`

log '* Start Docker Deamon'
dockerd &
until docker images 2>/dev/null | grep -c REPOSITORY; do
    sleep 1
done

################
#
# Create RDS from latest snapshot
#
################
log '* Create RDS from latest snapshot'
log "DBClusterIdentifier: ${DB_CLUSTER_IDENTIFIER}"
LATEST_SNAPSHOT=$( \
  aws rds describe-db-cluster-snapshots \
  --snapshot-type automated \
  --query "reverse(sort_by(DBClusterSnapshots,&SnapshotCreateTime))[?DBClusterIdentifier=='${DB_CLUSTER_IDENTIFIER}']|[0].[DBClusterSnapshotIdentifier]" \
  --output text)
log "DBClusterSnapshotIdentifier: ${LATEST_SNAPSHOT}"
LATEST_ENGINE=$( \
  aws rds describe-db-cluster-snapshots \
  --snapshot-type automated \
  --query "reverse(sort_by(DBClusterSnapshots,&SnapshotCreateTime))[?DBClusterIdentifier=='${DB_CLUSTER_IDENTIFIER}']|[0].[Engine]" \
  --output text)
log "Engine: ${LATEST_ENGINE}"

log 'Create RDS cluster'
aws rds restore-db-cluster-from-snapshot \
  --db-cluster-identifier $TMP_CLUSTER \
  --snapshot-identifier $LATEST_SNAPSHOT \
  --engine $LATEST_ENGINE

aurora_cluster_wait_available $TMP_CLUSTER

log 'Create RDS cluster member'
aws rds create-db-instance \
  --db-instance-identifier $TMP_CLUSTER_MEMBER \
  --db-instance-class $TMP_CLUSTER_CLASS \
  --engine $LATEST_ENGINE \
  --no-multi-az \
  --no-publicly-accessible \
  --db-cluster-identifier $TMP_CLUSTER

rds_wait_available $TMP_CLUSTER_MEMBER

TMP_CLUSTER_ENDPOINT=$(aws rds describe-db-clusters \
  --db-cluster-identifier $TMP_CLUSTER \
  --query "DBClusters[].Endpoint" \
  --output text)
log "Endpoint: ${TMP_CLUSTER_ENDPOINT}"
TMP_CLUSTER_PORT=$(aws rds describe-db-clusters \
  --db-cluster-identifier $TMP_CLUSTER \
  --query "DBClusters[].Port" \
  --output text)
log "Port: ${TMP_CLUSTER_ENDPOINT}"

until mysqladmin ping -h$TMP_CLUSTER_ENDPOINT -P$TMP_CLUSTER_PORT -u$ORIGIN_USER -p$ORIGIN_PASS --silent; do
    log '.'
    sleep 1
done


################
#
# Masking Data
#
################
# TODO: masking sql


################
#
# Dump Data
#
################
log '* MySQL Dumping'
mysqldump -h$TMP_CLUSTER_ENDPOINT -P$TMP_CLUSTER_PORT -u$ORIGIN_USER -p$ORIGIN_PASS $ORIGIN_DB_NAME -d --databases --default-character-set=binary > schema.sql
mysqldump -h$TMP_CLUSTER_ENDPOINT -P$TMP_CLUSTER_PORT -u$ORIGIN_USER -p$ORIGIN_PASS $ORIGIN_DB_NAME -t --default-character-set=binary > data.sql



################
#
# Delete RDS
#
################
log '* Delete RDS cluster member'
aws rds delete-db-instance \
  --db-instance-identifier $TMP_CLUSTER_MEMBER \
  --skip-final-snapshot

aurora_cluster_wait_members_null $TMP_CLUSTER

log '* Delete RDS cluster'
aws rds delete-db-cluster \
  --db-cluster-identifier $TMP_CLUSTER \
  --skip-final-snapshot



################
#
# Create Docker Image
#
################
log '* Build MySQL Container'
docker build -t $BASE_IMAGE -f ./Dockerfile .

log '* Start MySQL Container'
docker run --name $TMP_CONTAINER -p 3306:3306 -e MYSQL_ALLOW_EMPTY_PASSWORD=yes -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD -d $BASE_IMAGE
until mysqladmin ping -h127.0.0.1 -uroot --silent; do
    log '.'
    sleep 1
done

log '* Import MySQL'
mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD < schema.sql
mysql -h127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD $ORIGIN_DB_NAME < data.sql

log '* Commit Docker Image'
docker stop $TMP_CONTAINER
docker commit $TMP_CONTAINER $REPOSITORY_URI:$REPOSITORY_TAG
docker images

log '* push to ECR'
aws ecr get-login --no-include-email | sh
docker push $REPOSITORY_URI:$REPOSITORY_TAG

log '** Build Complete!! ***'
