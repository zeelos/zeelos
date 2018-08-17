## Architecture Overview

![Zeelos Architecture Diagram](http://image.ibb.co/g5pgk7/Zeelos_Architecture_Diagram_Edge.png)

## Setup

1. Create `zeelos-cloud` vm machine and initialize docker swarm cluster:

		docker-machine create --driver virtualbox --virtualbox-memory 8192 zeelos-cloud
		docker-machine ssh zeelos-cloud "docker swarm init --advertise-addr <zeelos-cloud-vm ip>"


2. Create `zeelos-server1` machine to simulate an edge gateway and then join the swarm:

		docker-machine create --driver virtualbox --virtualbox-memory 4096 zeelos-server1
		docker-machine ssh zeelos-server1 "docker swarm join --token <token> <zeelos-cloud-vm ip>:<port>"

	>  NOTE: Use `eval` to switch between `zeelos-cloud` and `zeelos-server1` edge when stated in the document: 

		eval $(docker-machine env zeelos-cloud)
		eval $(docker-machine env zeelos-server1)


3. Assign labels to nodes so the services would be propogated to the correct node upon deployment:

		docker-machine ssh zeelos-cloud "docker node update --label-add type=cloud zeelos-cloud"
		docker-machine ssh zeelos-cloud "docker node update --label-add type=server1 zeelos-server1"


4. Create overlay networks for cloud and edge gateway on `zeelos-cloud`:

		docker network create --driver overlay cloudnet
		docker network create --driver overlay edgenet_server1


5. Copy both cloud and edge `docker-compose.yml` files to swarm master and start the deployments:
		
		docker-machine scp docker-compose-cloud.yml zeelos-cloud:~
		docker-machine ssh zeelos-cloud "docker stack deploy -c docker-compose-cloud.yml zeelos-cloud"


		docker-machine scp docker-compose-edge.yml zeelos-cloud:~
		docker-machine ssh zeelos-cloud "docker stack deploy -c docker-compose-edge.yml zeelos-server1"
		
	> NOTE: At first run of the stack, the docker images need to be downloaded, so be a bit patient..
	
	When all docker images have been downloaded and started, you should have something like the following:
	<figure>
  <img src="http://image.ibb.co/i5WEVx/docker_containers.png" alt="Docker Containers"/>
  <figcaption>(top)-`zeelos-cloud`, (bottom)-`zeelos-server1`</figcaption>
</figure>

	
6. Create a **_'request'_** topic on `zeelos-cloud`. Clients will use that topic to send requests to the edge gateway (topic [will be replicated](https://github.com/zeelos/zeelos/blob/master/docker-compose-edge.yml#L116-L141) automatically from `zeelos_cloud` to `zeelos-server1` edge) :

		docker exec -it <kafka-container-id> kafka-topics --create --topic server1_management_req --zookeeper zookeeper-cloud:2181 --partitions 1 --replication-factor 1


7. Create **_'registration/response/observation'_** topics on `zeelos-cloud` with partition parameter set according to your requirements (we use 2 here to demonstrate scaling with the Connect framework). [Leshan Server Kafka](https://github.com/zeelos/leshan-server-kafka) running on the edge will use those topics to store all of it's messages (topics [would be replicated](https://github.com/zeelos/zeelos/blob/master/docker-compose-cloud.yml#L159-L184) automatically from `zeelos-server1` edge to `zeelos_cloud`)

	> NOTE:
	> On `zeelos-server1` edge, topics are set to be created automatically by the Kafka configuration with default partition number set to 1. According to your needs on the edge and its hardware characteristics (e.g if you use multiple kafka stream instances), you can choose to override by setting the appropriate configuration option in the `docker-compose-edge.yml`
	

		docker exec -it <kafka-container-id> kafka-topics --create --topic server1_observation --zookeeper zookeeper-cloud:2181 --partitions 2 --replication-factor 1 && \
		docker exec -it <kafka-container-id> kafka-topics --create --topic server1_registration_new --zookeeper zookeeper-cloud:2181 --partitions 2 --replication-factor 1 && \
		docker exec -it <kafka-container-id> kafka-topics --create --topic server1_registration_up --zookeeper zookeeper-cloud:2181 --partitions 2 --replication-factor 1 && \
		docker exec -it <kafka-container-id> kafka-topics --create --topic server1_registration_del --zookeeper zookeeper-cloud:2181 --partitions 2 --replication-factor 1 && \
		docker exec -it <kafka-container-id> kafka-topics --create --topic server1_management_rep --zookeeper zookeeper-cloud:2181 --partitions 2 --replication-factor 1


8. Deploy [a series of connectors](https://github.com/zeelos/zeelos/tree/master/configs) on `zeelos-cloud` for storing sensor time-series data on [InfluxDB](https://www.influxdata.com/time-series-platform/influxdb/) and visualizing the Leshan LWM2M model on a [TinkerPop3](http://tinkerpop.apache.org) enabled graph database (we used the open source [OrientDB](http://orientdb.com) in our [custom developed connector](https://github.com/cvasilak/kafka-connect-leshan-asset)).

    >NOTE: Since data are flowing into Kafka [any other connector](https://www.confluent.io/product/connectors/) can be used. For example, you can use the [Elastic Search connector](https://docs.confluent.io/current/connect/connect-elasticsearch/docs/elasticsearch_connector.html) to store the time series or/and the LWM2M model data to [Elasticsearch](https://www.elastic.co/products/elasticsearch).
 
    For deploying the connectors we recommend the excellent [kafkacli tools](https://github.com/fhussonnois/kafkacli):

		export KAFKA_CONNECT_HOST=<zeelos-cloud-vm ip>
		export KAFKA_CONNECT_PORT=8083

		cd ./configs && \
		kafka-connect-cli create -pretty -config.json kafka-connect-leshan-asset/connect-leshan-sink-asset.json && \
		kafka-connect-cli create -pretty -config.json kafka-connect-influxdb/connect-influxdb-sink.json


9. Start a [virtual sensor client demo](https://github.com/zeelos/leshan-client-demo) that will attach on the Leshan server running at the edge:

		docker service create --name leshan-client-demo-1 --network edgenet_server1 --constraint "node.labels.type == cloud" -p 8000:8000 -e JAVA_OPTS="-Djava.rmi.server.hostname=localhost -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.rmi.port=8000 -Dcom.sun.management.jmxremote.port=8000 -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Xmx32M -Xms32M" zeelos/leshan-client-demo:0.2-SNAPSHOT -u leshan-server-kafka
		
	> NOTE:
	> We strive to enable JMX on all Java running services to aid with monitoring. If you inspect the docker-compose files for cloud and edge you will see that JMX is enabled by default. You can then use your favourite tool to inspect the JVM (e.g. [VisualVM](https://visualvm.github.io)). Since the service is running inside docker (and possible docker-machine), to simplify configuration, the hostname we bound the service is `localhost` so you need to use an ssh tunnel to connect to (this also gives an advantage to avoid arbitrarily JMX connections from outside and only allow through SSH tunnel).
	>
	>For example, to connect to kafka server running on the edge, start a tunnel to the edge gateway:
		
		ssh -v -NL 9581:<edge hostname>:9581 user@<edge hostname>

	And then add it as a _'local connection'_ to the VisualVM tool:

   ![VisuaVM](https://image.ibb.co/iwLfJH/visualvm.png)
		
10. Visit [Leshan Server web interface](http://192.168.99.100:8080) and click on the sensor to get to the information page. Once there, start an '*Observation*' on the two simulated sensor instance resources on the '*Temperature*' object:

	![Leshan](https://image.ibb.co/iJVi25/leshan.png)


11. Visit [Grafana web interface](http://192.168.99.100:3000) and notice that received sensor values are correctly propagated from the edge to the cloud (using [replication](https://docs.confluent.io/current/multi-dc/mirrormaker.html)) and from there to the database by the excellent [InfluxDB Kafka connector](http://lenses.stream/connectors/sink/influx.html) from [Landoop](http://www.landoop.com):

	![Grafana](https://image.ibb.co/ibai25/grafana.png)


12. Start a [jmeter-leshan demo](https://github.com/zeelos/lwm2m-jmeter) to connect multiple virtual sensors and to perform any benchmarking tests (adjust command line parameters accordingly)

		docker service create --name jmeter-leshan --network edgenet_server1 --constraint "node.labels.type == cloud" zeelos/jmeter-leshan:0.0.1-SNAPSHOT -n -t /opt/jmeter/tests/leshan.jmx -JserverHost=leshan-server-kafka -JserverPort=5683 -JrestPort=8080 -Jthreads=10 -JthreadsRampUp=3 -JthreadsLoopCount=300 -JthreadDelayObserveSend=1000


13. Visit [OrientDB web interface](http://192.168.99.100:2480) to get a visual representation of all the sensors currently connected. Similar to Grafana, the OrientDB database is filled by another [Kafka connector](https://github.com/zeelos/kafka-connect-leshan-asset) from the incoming data from the edge.

	Once login, click the 'Graph' tab and on the graph editor do a simple query like '`select from Servers`' to get the current active Leshan server. From there you can start exploring by selecting the server and clicking the expand button:

	![OrientDB](https://image.ibb.co/cCM15Q/orientdb.png)

	Click on an endpoint and notice the left pane will contain it's properties (e.g. last registration update, binding mode etc):
	
	![OrientDB-props](http://image.ibb.co/cmZbAx/orientdb_properties.png)
	
14. We can easily scale the Kafka Connect cluster to two instances (or more) to cope with the increased _'simulated demand'_. All deployed connectors have been configured with `"tasks.max": "2"` so one of the tasks would be propagated to the second instance:

		docker service scale zeelos-cloud_kafka-connect-cloud=2
		
	For example, notice in the following screenshot, that tasks of the InfluxDBSink and LeshanAssetSink connectors are deployed in the first instance(top) and on the second one (bottom) and both being kept busy:
	
	![Kafka Connect Scale](https://image.ibb.co/jiQfQw/kafka_connect_scale.jpg)


15. Start some [Kafka Streams Analytics](https://github.com/zeelos/kafka-streams-leshan) that will run at the edge (notice the  `--constraint` parameter that explicitly specifies the edge node). [The first analytic](https://github.com/zeelos/kafka-streams-leshan/blob/master/src/main/java/io/zeelos/leshan/kafka/streams/SimpleAnalyticsStreamsApp.java#L73-L98) aggregates sensor readings by '`endpoint id`' and by '`endpoint id`' and '`path`' per minute and outputs the result in the console. Use `docker logs -f <container_id>` to watch it's output:

		docker service create --name kstreams-aggregate --network edgenet_server1 --constraint "node.labels.type == server1" -p 9000:9000 -e JAVA_OPTS="-Djava.rmi.server.hostname=localhost -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.rmi.port=9000 -Dcom.sun.management.jmxremote.port=9000 -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false" zeelos/kafka-streams-leshan:0.2-SNAPSHOT io.zeelos.leshan.kafka.streams.SimpleAnalyticsStreamsApp kafka-edge:9082 http://schema-registry-edge:8071

	[The second analytic](https://github.com/zeelos/kafka-streams-leshan/blob/master/src/main/java/io/zeelos/leshan/kafka/streams/TemperatureStreamsApp.java#L95-L120) calculates the maximum temperature of the incoming observations grouped by '`endpoint id`' and '`path`' over a period of 30 secs and outputs the result in the `server1_observation_maxper30sec` topic:
	
		docker service create --name kstreams-temperature --network edgenet_server1 --constraint "node.labels.type == server1" -p 9001:9001 -e JAVA_OPTS="-Djava.rmi.server.hostname=localhost -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.rmi.port=9001 -Dcom.sun.management.jmxremote.port=9001 -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false" zeelos/kafka-streams-leshan:0.2-SNAPSHOT io.zeelos.leshan.kafka.streams.TemperatureStreamsApp kafka-edge:9082 http://schema-registry-edge:8071
		
	> The output of the analytic resides on `server1_observation_maxper30sec` topic at `zeelos-server1` edge. Already, replication [has been configured](https://github.com/zeelos/zeelos/blob/master/docker-compose-cloud.yml#L162) for all edge topics starting with prefix `server1_*` except the `server1_management_req`. Start a consumer to watch the output of the analytic as it propagates from the edge to the cloud :
	
		docker exec -it <kafka-container-id> kafka-avro-console-consumer --topic server1_observation_maxper30sec --bootstrap-server kafka-cloud:9092 --property schema.registry.url=http://schema-registry-cloud:8081
	
		
16. Subscribe on the `zeelos-cloud` Kafka topics to watch all incoming Leshan LWM2M protocol messages coming from `zeelos-server1` edge node:

		docker exec -it <kafka-container-id> kafka-avro-console-consumer --topic server1_registration_new --bootstrap-server kafka-cloud:9092 --property schema.registry.url=http://schema-registry-cloud:8081
		
		docker exec -it <kafka-container-id> kafka-avro-console-consumer --topic server1_registration_up --bootstrap-server kafka-cloud:9092 --property schema.registry.url=http://schema-registry-cloud:8081
		
		docker exec -it <kafka-container-id> kafka-avro-console-consumer --topic server1_registration_del --bootstrap-server kafka-cloud:9092 --property schema.registry.url=http://schema-registry-cloud:8081
		
		docker exec -it <kafka-container-id> kafka-avro-console-consumer --topic server1_observation --bootstrap-server kafka-cloud:9092 --property schema.registry.url=http://schema-registry-cloud:8081
		

17. Make some requests against the `zeelos-server1` Leshan Server. Notice that clients invoke them on the central `zeelos-cloud` and the request get's propagated on the edge using [replication](https://docs.confluent.io/current/multi-dc/mirrormaker.html) and back. 

	First subscribe to the reponse topic `server1_management_rep` to view the reply of your request:

		docker exec -it <kafka-container-id> kafka-avro-console-consumer --topic server1_management_rep --bootstrap-server kafka-cloud:9092 --property schema.registry.url=http://schema-registry-cloud:8081
		
	Now issue commands by producing messages to the request topic `server1_management_req`:
	
		docker exec -it <kafka-container-id> kafka-avro-console-producer --topic server1_management_req --property value.schema="$(< ./schemas/request-schema.json)" --broker-list kafka-cloud:9092 --property schema.registry.url=http://schema-registry-cloud:8081

	Format of the requests is as follow (complying to the [Avro request schema](https://github.com/zeelos/zeelos/blob/master/schemas/request-schema.json))
	
	    --"observe" request--
        {"serverId": "server1", "ep": "<endpoint_id>", "ticket": "ticket#1", "payload": {"kind": "observe", "path": "/3303/0/5700", "contentFormat": "TLV", "body": null}}
        
    	--"observeCancel" request--
        {"serverId": "server1", "ep": "<endpoint_id>", "ticket": "ticket#2", "payload": {"kind": "observeCancel", "path": "/3303/0/5700", "contentFormat": "TLV", "body": null}}
            
	    --"read" request--
	    # string type
		{"serverId": "server1", "ep": "<endpoint_id>", "ticket": "ticket#3", "payload": {"kind": "read", "path": "/3/0/1", "contentFormat": "TLV", "body": null}}
		# boolean type
		{"serverId": "server1", "ep": "<endpoint_id>", "ticket": "ticket#3", "payload": {"kind": "read", "path": "/1/0/6", "contentFormat": "TLV", "body": null}}
	        
	    --"write" request--
	    {"serverId": "server1", "ep": "<endpoint_id>", "ticket": "ticket#4", "payload": {"kind": "write", "path": "/1/0/6", "contentFormat": "TLV", "body":{"io.zeelos.leshan.avro.request.AvroWriteRequest":{"mode":"REPLACE", "node":{"io.zeelos.leshan.avro.model.AvroResource":{"id":6,"path":"/1/0/6","kind":"SINGLE_RESOURCE","type":"BOOLEAN","value":{"boolean":true}}}}}}}
	
	    --"execute" request--
	    {"serverId": "server1", "ep": "<endpoint_id>", "ticket": "ticket#5", "payload": {"kind": "execute", "path": "/3/0/4", "contentFormat": "TLV", "body":{"io.zeelos.leshan.avro.request.AvroExecuteRequest":{"parameters":"param1,param2"}}}}
	    
	Here is an screenshot of a series of command executions(on top) together with their responses(on bottom):

	![request-response](https://image.ibb.co/eijtpF/request_response_confluent_3_3_0.png)
	
	>requests can target both an "object" (e.g /3), an "object instance" (e.g 3/0), or a specific "resource" (e.g /3/0/1).

## Protocol Adapters

Although [Lightweight M2M](http://openmobilealliance.org/iot/lightweight-m2m-lwm2m) is a feature rich protocol that can serve the needs and requirements for many IoT projects ([the specification](http://www.openmobilealliance.org/release/LightweightM2M/V1_0-20170208-A/OMA-TS-LightweightM2M-V1_0-20170208-A.pdf) is easy to read), understandable there are many legacy protocols already deployed in industrial environments that need to supported. Fortunately enough, the flexible design of LWM2M allows routing of many existing protocols. As a matter of fact, we created a [Modbus](https://en.wikipedia.org/wiki/Modbus) adapter that showcase this functionality (with an [OPC-UA](https://en.wikipedia.org/wiki/OPC_Unified_Architecture) adapter currently in the works). Supporting existing protocols is an important feature and the Open Mobile Alliance is currently working to standarize the process with the [upcoming v1.1 spec](http://www.openmobilealliance.org/release/LightweightM2M/V1_1-20171208-C/OMA-RD-LightweightM2M-V1_1-20171208-C.pdf) (check the `LwM2M Gateway functionality` section) something we are looking forward to support when available.

### Modbus to LWM2M

A protocol adapter has been created that translates LWM2M protocol messages to Modbus and back. Please have a look at the [project page](https://github.com/zeelos/leshan-client-modbus) for  more information. 



### OPC-UA to LWM2M
> currently in progress

## front-ends

[Landoop UI](http://192.168.99.100) (Kafka cluster introspection from [Landoop](http://www.landoop.com/))

[Leshan Server](http://192.168.99.100:8080) (LWM2M Server)

[Grafana](http://192.168.99.100:3000) (Metrics Visualisation)

[OrientDB](http://192.168.99.100:2480) (Model Visualisation)

> for all services use credentials **username:**`root`, **password**:`secret`
(except for Grafana where username is `admin`)

## Note about Replication

For replication between the cloud and edge Kafka installations, we chose to use the open source [Apache MirrorMaker](https://kafka.apache.org/documentation/#basic_ops_mirror_maker) tool but you are free to use any replication tool such as Confluent's own [Kafka Connect Replicator](https://docs.confluent.io/current/connect/connect-replicator/docs/connect_replicator.html). As a matter of fact, we have prepared an example Confluent Connect replication config you can find [here](https://github.com/zeelos/zeelos/blob/master/configs/kafka-connect-replicator/replicator-server1-gateway-to-cloud.json) where you can deploy it in the connect cluster on the cloud. Similarly, on the edge you can start a [standalone connect replication service](https://gist.github.com/zeelos/38d1fcdbbf4ac2086a4ee066b8656774)