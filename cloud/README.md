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
docker-app render kafka | docker stack deploy --compose-file - kafka
docker-app render dbs | docker stack deploy --compose-file - dbs
docker-app render --set edge.id=upboard connect-clusters | docker stack deploy --compose-file - connect-clusters-upboard
docker-app render --set edge.id=rock64 connect-clusters | docker stack deploy --compose-file - connect-clusters-rock64

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





# metadata listing for partition
kafkacat -L -b kafka-cloud-1:9092 -t iot.upboard.observations \
-X security.protocol=SSL \
-X ssl.key.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/client-cloud.key \
-X ssl.key.password=itsasecret \
-X ssl.certificate.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/client-cloud.certificate.pem \
-X ssl.ca.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/zeelos.io-ca.crt

# consume partition
kafkacat -C -b kafka-cloud-1:9092 -t iot.upboard.observations \
-X security.protocol=SSL \
-X ssl.key.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/client-cloud.key \
-X ssl.key.password=itsasecret \
-X ssl.certificate.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/client-cloud.certificate.pem \
-X ssl.ca.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/zeelos.io-ca.crt

# start mirrormaker
cd cloud/

# upboard
docker-app render --set edge.id=upboard mirrormaker | docker stack deploy --compose-file - mirrormaker-upboard

# rock64
docker-app render --set edge.id=rock64 mirrormaker | docker stack deploy --compose-file - mirrormaker-rock64

# deploy connectors

# upboard
export EDGE_ID=upboard
cd ./configs && \
LESHAN_ASSET_CONECTOR_CONFIG=`sed -e "s/EDGE_ID/$EDGE_ID/g" kafka-connect/kafka-connect-leshan-asset/connect-leshan-sink-asset.json` && \
curl -X POST -H "Content-Type: application/json" -d "$LESHAN_ASSET_CONECTOR_CONFIG" -k https://connect-leshan-asset-upboard:8084/connectors && \
INFLUXDB_CONECTOR_CONFIG=`sed -e "s/EDGE_ID/$EDGE_ID/g" kafka-connect/kafka-connect-influxdb/connect-influxdb-sink.json` && \
curl -X POST -H "Content-Type: application/json" -d "$INFLUXDB_CONECTOR_CONFIG" -k https://connect-influxdb-upboard:8083/connectors

# rock64
export EDGE_ID=rock64
cd ./configs && \
LESHAN_ASSET_CONECTOR_CONFIG=`sed -e "s/EDGE_ID/$EDGE_ID/g" kafka-connect/kafka-connect-leshan-asset/connect-leshan-sink-asset.json` && \
curl -X POST -H "Content-Type: application/json" -d "$LESHAN_ASSET_CONECTOR_CONFIG" -k https://connect-leshan-asset-rock64:8074/connectors && \
INFLUXDB_CONECTOR_CONFIG=`sed -e "s/EDGE_ID/$EDGE_ID/g" kafka-connect/kafka-connect-influxdb/connect-influxdb-sink.json` && \
curl -X POST -H "Content-Type: application/json" -d "$INFLUXDB_CONECTOR_CONFIG" -k https://connect-influxdb-rock64:8073/connectors


export EDGE_ID=rock64
cd ./configs && \
LESHAN_ASSET_CONECTOR_CONFIG=`sed -e "s/EDGE_ID/$EDGE_ID/g" kafka-connect/kafka-connect-leshan-asset/connect-leshan-sink-asset.json` && \
curl -X POST -H "Content-Type: application/json" -d "$LESHAN_ASSET_CONECTOR_CONFIG" -k https://connect-leshan-asset:8074/connectors && \
INFLUXDB_CONECTOR_CONFIG=`sed -e "s/EDGE_ID/$EDGE_ID/g" kafka-connect/kafka-connect-influxdb/connect-influxdb-sink.json` && \
curl -X POST -H "Content-Type: application/json" -d "$INFLUXDB_CONECTOR_CONFIG" -k https://connect-influxdb:8073/connectors


# list connectors
curl -X GET -k https://connect-leshan-asset:8084/connectors/
# delete connector
curl -X DELETE -k https://connect-leshan-asset:8084/connectors/_leshan_asset_sink


