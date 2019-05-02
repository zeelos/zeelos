# initialize swarm
docker swarm init --advertise-addr=<ip>

# create networks
docker network create --driver overlay monnet
docker network create --driver overlay edgenet_upboard
docker network create --driver overlay edgenet_rock64

# start services
cd edge/
docker-app render monitoring | docker stack deploy --compose-file - monitoring
docker-app render --set edge.id=upboard kafka | docker stack deploy --compose-file - kafka
docker-app render --set edge.id=upboard leshan | docker stack deploy --compose-file - leshan


# create topics
kafka-topics --create --topic "iot.upboard.management.req" --bootstrap-server kafka-upboard-edge:9082 --partitions 3 --replication-factor 1 --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_edge.properties

kafka-topics --create --topic "iot.upboard.management.rep" --bootstrap-server kafka-upboard-edge:9082 --partitions 3 --replication-factor 1 --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_edge.properties

kafka-topics --create --topic "iot.upboard.observations" --bootstrap-server kafka-upboard-edge:9082 --partitions 3 --replication-factor 1 --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_edge.properties

kafka-topics --create --topic "iot.upboard.registrations" --bootstrap-server kafka-upboard-edge:9082 --partitions 3 --replication-factor 1 --command-config /Users/cvasilak/Projects/RealRed/projects/zeelos/leshan/client_security_edge.properties

# metadata listing for partition
kafkacat -L -b kafka-upboard-edge:9082 -t iot.upboard.management.req \
-X security.protocol=SSL \
-X ssl.key.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/client-edge.key \
-X ssl.key.password=itsasecret \
-X ssl.certificate.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/client-edge.certificate.pem \
-X ssl.ca.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/zeelos.io-ca.crt

kafkacat -C -b kafka-upboard-edge:9082 -t iot.upboard.observations \
-X security.protocol=SSL \
-X ssl.key.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/client-edge.key \
-X ssl.key.password=itsasecret \
-X ssl.certificate.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/client-edge.certificate.pem \
-X ssl.ca.location=/Users/cvasilak/Projects/RealRed/projects/zeelos/zeelos/security/zeelos.io-ca.crt


# start mirrormaker
cd edge/
docker-app render --set edge.id=upboard mirrormaker | docker stack deploy --compose-file - mirrormaker

docker-app render --set edge.id=rock64 mirrormaker | docker stack deploy --compose-file - mirrormaker

# start streams
export EDGE_ID=upboard

docker service create --name kstreams-${EDGE_ID}-aggregate --network edgenet_${EDGE_ID} --constraint "node.role == manager" --secret "source=kafka_client_security_edge.properties,target=/etc/kafka/secrets/client_security_edge.properties" --secret "source=kafka_kafka.client-edge.keystore.jks,target=/etc/kafka/secrets/kafka.client-edge.keystore.jks" --secret "source=kafka_kafka.client-edge.truststore.jks,target=/etc/kafka/secrets/kafka.client-edge.truststore.jks" -e JAVA_OPTS="-Xmx128M -Xms128M -Djava.rmi.server.hostname=localhost -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.rmi.port=9000 -Dcom.sun.management.jmxremote.port=9000 -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djavax.net.ssl.trustStore=/etc/kafka/secrets/kafka.client-edge.truststore.jks -Djavax.net.ssl.trustStorePassword=itsasecret -Djavax.net.ssl.keyStore=/etc/kafka/secrets/kafka.client-edge.keystore.jks -Djavax.net.ssl.keyStorePassword=itsasecret" images.zeelos.io/library/kafka-streams-leshan:0.7-SNAPSHOT-arm64v8 io.zeelos.leshan.kafka.streams.SimpleAnalyticsStreamsApp kafka-edge:9082 https://schema-registry-edge:8071 iot.${EDGE_ID}.observations /tmp/kafka-streams-leshan /etc/kafka/secrets/client_security_edge.properties

docker service create --name kstreams-${EDGE_ID}-temperature --network edgenet_${EDGE_ID} --constraint "node.role == manager" --secret "source=kafka_client_security_edge.properties,target=/etc/kafka/secrets/client_security_edge.properties" --secret "source=kafka_kafka.client-edge.keystore.jks,target=/etc/kafka/secrets/kafka.client-edge.keystore.jks" --secret "source=kafka_kafka.client-edge.truststore.jks,target=/etc/kafka/secrets/kafka.client-edge.truststore.jks" -e JAVA_OPTS="-Djava.rmi.server.hostname=localhost -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.rmi.port=9000 -Dcom.sun.management.jmxremote.port=9000 -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djavax.net.ssl.trustStore=/etc/kafka/secrets/kafka.client-edge.truststore.jks -Djavax.net.ssl.trustStorePassword=itsasecret -Djavax.net.ssl.keyStore=/etc/kafka/secrets/kafka.client-edge.keystore.jks -Djavax.net.ssl.keyStorePassword=itsasecret" images.zeelos.io/library/kafka-streams-leshan:0.4-SNAPSHOT io.zeelos.leshan.kafka.streams.TemperatureStreamsApp kafka-edge:9082 https://schema-registry-edge:8071 iot.$EDGE_ID.observations analytics.$EDGE_ID.observations.maxper30sec /tmp/kafka-streams-leshan /etc/kafka/secrets/client_security_edge.properties