# create certificates
./security/certs-create.sh

# create networks
docker network create --driver overlay monnet
docker network create --driver overlay cloudnet

# create certificates
cd security/
./certs-create.sh

# update paramaters.yml on docker-apps with the correct 'project id'


# start services
cd cloud/
docker-app render monitoring | docker stack deploy --compose-file - monitoring
docker-app deploy monitoring
docker-app render kafka | docker stack deploy --compose-file - kafka
docker-app deploy kafka
docker-app render dbs | docker stack deploy --compose-file - dbs
docker-app deploy dbs
docker-app render --set edge.id=upboard connect-clusters | docker stack deploy --compose-file - connect-clusters-upboard
docker-app deploy --set edge.id=upboard --name connect-clusters-upboard connect-clusters
docker-app render --set edge.id=rock64 connect-clusters | docker stack deploy --compose-file - connect-clusters-rock64
docker-app deploy --set edge.id=rock64 --name connect-clusters-rock64 connect-clusters
docker-app render kafkahq | docker stack deploy --compose-file - kafkahq
docker stack deploy kafkahq

# create topics
# Note: configure 'export SCHEMA_REGISTRY_OPTS' as in the case of the native connection to cloud
export SCHEMA_REGISTRY_OPTS="-Djavax.net.ssl.trustStore=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/kafka.client-cloud.truststore.jks -Djavax.net.ssl.trustStorePassword=itsasecret -Djavax.net.ssl.keyStore=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/kafka.client-cloud.keystore.jks -Djavax.net.ssl.keyStorePassword=itsasecret"

# upboard
kafka-topics --create --topic "iot.upboard.management.req" --bootstrap-server kafka-cloud-1:9092 --partitions 3 --replication-factor 3 --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties

kafka-topics --create --topic "iot.upboard.management.rep" --bootstrap-server kafka-cloud-1:9092 --partitions 3 --replication-factor 3 --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties

kafka-topics --create --topic "iot.upboard.observations" --bootstrap-server kafka-cloud-1:9092 --partitions 3 --replication-factor 3 --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties

kafka-topics --create --topic "iot.upboard.registrations" --bootstrap-server kafka-cloud-1:9092 --partitions 3 --replication-factor 3 --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties


# rock64
kafka-topics --create --topic "iot.rock64.management.req" --bootstrap-server kafka-cloud-1:9092 --partitions 3 --replication-factor 3 --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties

kafka-topics --create --topic "iot.rock64.management.rep" --bootstrap-server kafka-cloud-1:9092 --partitions 3 --replication-factor 3 --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties

kafka-topics --create --topic "iot.rock64.observations" --bootstrap-server kafka-cloud-1:9092 --partitions 3 --replication-factor 3 --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties

kafka-topics --create --topic "iot.rock64.registrations" --bootstrap-server kafka-cloud-1:9092 --partitions 3 --replication-factor 3 --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties


# schema-registry setup
export SCHEMA_REGISTRY_OPTS="-Djavax.net.ssl.trustStore=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/kafka.client-cloud.truststore.jks -Djavax.net.ssl.trustStorePassword=itsasecret -Djavax.net.ssl.keyStore=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/kafka.client-cloud.keystore.jks -Djavax.net.ssl.keyStorePassword=itsasecret"

# subscribe for observations
# upboard
kafka-avro-console-consumer --topic iot.upboard.observations --bootstrap-server kafka-cloud-1:9092 --property schema.registry.url=https://schema-registry-cloud:8081 --consumer.config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties

# rock64
kafka-avro-console-consumer --topic iot.rock64.observations --bootstrap-server kafka-cloud-1:9092 --property schema.registry.url=https://schema-registry-cloud:8081 --consumer.config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties

# send request

# request schema's

{"serverId": "upboard", "ep": "6a6970fbe9c240e6b1add8b4c7feb970", "ticket": "ticket#1", "payload": {"kind": "read", "path": "/3/0", "contentFormat": "TLV", "body": null}}

{"serverId": "upboard", "ep": "6a6970fbe9c240e6b1add8b4c7feb970", "ticket": "ticket#1", "payload": {"kind": "read", "path": "/3303", "contentFormat": "TLV", "body": null}}


{"serverId": "upboard", "ep": "6a6970fbe9c240e6b1add8b4c7feb970", "ticket": "ticket#1", "payload": {"kind": "read", "path": "/3/0/1", "contentFormat": "TLV", "body": null}}

{"serverId": "upboard", "ep": "6a6970fbe9c240e6b1add8b4c7feb970", "ticket": "ticket#1", "payload": {"kind": "observe", "path": "/3303/0/5700", "contentFormat": "TLV", "body": null}}

{"serverId": "upboard", "ep": "6a6970fbe9c240e6b1add8b4c7feb970", "ticket": "ticket#2", "payload": {"kind": "observeCancel", "path": "/3303/0/5700", "contentFormat": "TLV", "body": null}}

# string
{"serverId": "upboard", "ep": "6a6970fbe9c240e6b1add8b4c7feb970", "ticket": "ticket#2", "payload": {"kind": "read", "path": "/3/0/0", "contentFormat": "TLV", "body": null}}

# boolean
{"serverId": "upboard", "ep": "6a6970fbe9c240e6b1add8b4c7feb970", "ticket": "ticket#3", "payload": {"kind": "read", "path": "/1/0/6", "contentFormat": "TLV", "body": null}}

{"serverId": "upboard", "ep": "6a6970fbe9c240e6b1add8b4c7feb970", "ticket": "ticket#4", "payload": {"kind": "write", "path": "/1/0/6", "contentFormat": "TLV", "body":{"io.zeelos.leshan.avro.request.AvroWriteRequest":{"mode":"REPLACE", "node":{"io.zeelos.leshan.avro.resource.AvroResource":{"id":6,"path":"/1/0/6","kind":"SINGLE_RESOURCE","type":"BOOLEAN","value":{"boolean":true}}}}}}}

{"serverId": "upboard", "ep": "6a6970fbe9c240e6b1add8b4c7feb970", "ticket": "ticket#5", "payload": {"kind": "execute", "path": "/3/0/4", "contentFormat": "TLV", "body":{"io.zeelos.leshan.avro.request.AvroExecuteRequest":{"parameters":"foo,bar"}}}}


# upboard
kafka-avro-console-producer --topic iot.upboard.management.req --property value.schema="$(< /Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/schemas/request-schema.json)" --broker-list kafka-cloud-1:9092 --property schema.registry.url=https://schema-registry-cloud:8081 --producer.config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties

# rock64
kafka-avro-console-producer --topic iot.rock64.management.req --property value.schema="$(< /Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/schemas/request-schema.json)" --broker-list kafka-cloud-1:9092 --property schema.registry.url=https://schema-registry-cloud:8081 --producer.config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties

# retrieve response


# upboard
kafka-avro-console-consumer --topic iot.upboard.management.rep --bootstrap-server kafka-cloud-1:9092 --property schema.registry.url=https://schema-registry-cloud:8081 --consumer.config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties

# rock64
kafka-avro-console-consumer --topic iot.rock64.management.rep --bootstrap-server kafka-cloud-1:9092 --property schema.registry.url=https://schema-registry-cloud:8081 --consumer.config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties

# metadata listing for partition
kafkacat -L -b kafka-cloud-1:9092 -t iot.upboard.observations \
-X security.protocol=SSL \
-X ssl.key.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/client-cloud.key \
-X ssl.key.password=itsasecret \
-X ssl.certificate.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/client-cloud.certificate.pem \
-X ssl.ca.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/zeelos.io-ca.crt

# consume partition

# upboard
kafkacat -C -b kafka-cloud-1:9092 -t iot.upboard.observations -o end \
-X security.protocol=SSL \
-X ssl.key.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/client-cloud.key \
-X ssl.key.password=itsasecret \
-X ssl.certificate.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/client-cloud.certificate.pem \
-X ssl.ca.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/zeelos.io-ca.crt

# rock64
kafkacat -C -b kafka-cloud-1:9092 -t iot.rock64.observations -o end \
-X security.protocol=SSL \
-X ssl.key.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/client-cloud.key \
-X ssl.key.password=itsasecret \
-X ssl.certificate.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/client-cloud.certificate.pem \
-X ssl.ca.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/zeelos.io-ca.crt

# start mirrormaker
cd cloud/

# upboard
docker-app render --set edge.id=upboard mirrormaker | docker stack deploy --compose-file - mirrormaker-upboard
docker-app deploy --set edge.id=upboard --name mirrormaker-upboard mirrormaker

# rock64
docker-app render --set edge.id=rock64 mirrormaker | docker stack deploy --compose-file - mirrormaker-rock64
docker-app deploy --set edge.id=rock64 --name mirrormaker-rock64 mirrormaker
# deploy connectors

# upboard
export EDGE_ID=upboard
cd ./configs && \
LESHAN_ASSET_CONECTOR_CONFIG=`sed -e "s/EDGE_ID/$EDGE_ID/g" kafka-connect/kafka-connect-leshan-asset/connect-leshan-sink-asset.json` && \
curl -X POST -H "Content-Type: application/json" -d "$LESHAN_ASSET_CONECTOR_CONFIG" -k https://connect-cloud:8084/connectors && \
INFLUXDB_CONECTOR_CONFIG=`sed -e "s/EDGE_ID/$EDGE_ID/g" kafka-connect/kafka-connect-influxdb/connect-influxdb-sink.json` && \
curl -X POST -H "Content-Type: application/json" -d "$INFLUXDB_CONECTOR_CONFIG" -k https://connect-cloud:8083/connectors

# rock64
export EDGE_ID=rock64
cd ./configs && \
LESHAN_ASSET_CONECTOR_CONFIG=`sed -e "s/EDGE_ID/$EDGE_ID/g" kafka-connect/kafka-connect-leshan-asset/connect-leshan-sink-asset.json` && \
curl -X POST -H "Content-Type: application/json" -d "$LESHAN_ASSET_CONECTOR_CONFIG" -k https://connect-cloud:8074/connectors && \
INFLUXDB_CONECTOR_CONFIG=`sed -e "s/EDGE_ID/$EDGE_ID/g" kafka-connect/kafka-connect-influxdb/connect-influxdb-sink.json` && \
curl -X POST -H "Content-Type: application/json" -d "$INFLUXDB_CONECTOR_CONFIG" -k https://connect-cloud:8073/connectors


export EDGE_ID=rock64
cd ./configs && \
LESHAN_ASSET_CONECTOR_CONFIG=`sed -e "s/EDGE_ID/$EDGE_ID/g" kafka-connect/kafka-connect-leshan-asset/connect-leshan-sink-asset.json` && \
curl -X POST -H "Content-Type: application/json" -d "$LESHAN_ASSET_CONECTOR_CONFIG" -k https://connect-cloud:8074/connectors && \
INFLUXDB_CONECTOR_CONFIG=`sed -e "s/EDGE_ID/$EDGE_ID/g" kafka-connect/kafka-connect-influxdb/connect-influxdb-sink.json` && \
curl -X POST -H "Content-Type: application/json" -d "$INFLUXDB_CONECTOR_CONFIG" -k https://connect-cloud:8073/connectors


# list connectors
curl -X GET -k https://connect-cloud:8084/connectors/upboard_leshan_asset_sink
# delete connector
curl -X DELETE -k https://connect-cloud:8084/connectors/_leshan_asset_sink

#
## useful kafka administration tools
#

## list topics
kafka-topics --bootstrap-server kafka-cloud-1:9092 --list --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties


## decribe topic
kafka-topics --bootstrap-server kafka-cloud-1:9092 --describe --topic {topic_name} --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties


## inspect topic config
kafka-configs --zookeeper zookeeper-cloud-1:2181 --describe --entity-type topics --entity-name {topic_name}


## list consumer groups
kafka-consumer-groups --bootstrap-server kafka-cloud-1:9092 --list --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties

# upboard
kafka-consumer-groups --bootstrap-server kafka-upboard-edge:9082 --list --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_edge.properties
# rock64
kafka-consumer-groups --bootstrap-server kafka-rock64-edge:9082 --list --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_edge.properties


## describe influxdb sink offsets
kafka-consumer-groups --bootstrap-server kafka-cloud-1:9092 --describe --group connect-upboard_influxdb_sink --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties

# upboard
kafka-consumer-groups --bootstrap-server kafka-upboard-edge:9082 --describe --group {consumer-group} --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_edge.properties
# rock64
kafka-consumer-groups --bootstrap-server kafka-rock64-edge:9082 --describe --group {consumer-group} --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_edge.properties


## reset influxdb sink to latest offset
kafka-consumer-groups -bootstrap-server kafka-cloud-1:9092 --group {consumer-group} --reset-offsets --to-latest --all-topics --execute --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties


## reset asset sink to latest offset
kafka-consumer-groups -bootstrap-server kafka-cloud-1:9092 --group {consumer-group} --reset-offsets --to-latest --all-topics --execute --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_cloud.properties

kafka-consumer-groups -bootstrap-server kafka-upboard-edge:9082 --group mirrormaker_cloud_upboard --reset-offsets --to-latest --all-topics --execute --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_edge.properties


## verify compression('snappy') is applied
unset KAFKA_OPTS
unset KAFKA_JMX_OPTS
kafka-run-class kafka.tools.DumpLogSegments --files /var/lib/kafka/data/<topic-partition>/<file>.log 


## virtual sensor
# upboard
docker run -it --rm --name virtual-sensor-upboard -e JAVA_OPTS="-Xmx32M -Xms32M" images.zeelos.io/library/leshan-client-demo:0.7-SNAPSHOT -u upboard-gateway.entrydns.org
# rock64
docker run -it --rm --name virtual-sensor-rock64 -e JAVA_OPTS="-Xmx32M -Xms32M" images.zeelos.io/library/leshan-client-demo:0.7-SNAPSHOT -u rock64-gateway.entrydns.org

## jmeter
# upboard
docker run -it --rm --name jmeter-upboard images.zeelos.io/library/jmeter-leshan:0.0.1-SNAPSHOT -n -t /opt/jmeter/tests/leshan.jmx -JserverHost=upboard-gateway.entrydns.org -JserverPort=5683 -JrestPort=80 -Jthreads=10 -JthreadsRampUp=3 -JthreadsLoopCount=100 -JthreadDelayObserveSend=30000
# rock64
docker run -it --rm --name jmeter-rock64 images.zeelos.io/library/jmeter-leshan:0.0.1-SNAPSHOT -n -t /opt/jmeter/tests/leshan.jmx -JserverHost=rock64-gateway.entrydns.org -JserverPort=5683 -JrestPort=80 -Jthreads=10 -JthreadsRampUp=3 -JthreadsLoopCount=100 -JthreadDelayObserveSend=30000
