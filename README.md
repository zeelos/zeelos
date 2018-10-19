> NOTE:
> This project aims to be a sample prototype of utilizing Apache Kafka and Lightweight M2M (LWM2M) protocol as the backbone for cloud/edge IoT integration. It is mainly developed to spin out discussions around Kafka and it's usage in IoT and how can be leveraged to simplify and enhance both developer and user experience. It is not meant to be used as is in a production setting. That said, please open issues and make suggestions, will be happy to hear from you!

## Architecture Overview

![Zeelos Architecture Diagram](http://image.ibb.co/g5pgk7/Zeelos_Architecture_Diagram_Edge.png)

## Setup

### Hardware Prerequisites

We have verified the setup to work on the following _'edge'_ hardware:

- [Asus Tinker Board](https://www.asus.com/gr/Single-Board-Computer/Tinker-Board/) running [Armbian Debian Stretch](https://www.armbian.com/tinkerboard/) - **_arm32v7 (2G Memory)_**
- [Rock64](https://www.pine64.org/?page_id=7147) running [Armbian Debian Stretch](https://www.armbian.com/rock64/) - **_arm64v8 (4G Memory)_**
- [UP Squared](http://www.up-board.org/upsquared/) running [Ubilinux Debian Stretch](https://downloads.up-community.org/download/ubilinux-installer-4-0/) - **_x64 (8G Memory)_**

> NOTE:
> If you don't happen to have any of this hardware and you still like to test the setup, we suggest you spin out hosts on [Scaleway](https://www.scaleway.com) that provide both Arm32v7/Arm64v8 and x64 hardware for users to test out. The cost is rather low (especially on Arm hardware), so it's easy to get started.

### Software Prerequisites

We are utilizing [Docker](https://docs.docker.com) (tested on `v18.06.1-ce`) with it's Swarm orchestration and [docker-app](https://github.com/docker/app) (tested on `v0.6.0`) for flexible configuration of the various services running on the different hardware architectures, so ensure you have those two tools installed. Once installed, [enable the experimental features](https://ops.tips/gists/how-to-collect-docker-daemon-metrics/) of Docker for extended metrics reporting to Prometheus, which will be visible on the Grafana dashboard.

To ease administration, ensure you have installed the [Cockpit web administration interface](https://cockpit-project.org) on each cloud and edge node as well as the [cockpit-leshan](https://github.com/zeelos/cockpit-leshan) plugin we have developed for Leshan LWM2M administration. The plugin is an adaptation of the original Leshan web interface made to work inside Cockpit. (both [`deb`](https://github.com/zeelos/cockpit-leshan/releases/download/v0.1.0/cockpit-leshan_0.1.0-1_all.deb) and [`rpm`](https://github.com/zeelos/cockpit-leshan/releases/download/v0.1.0/cockpit-leshan-0.1.0-0.noarch.rpm) packages [are provided](https://github.com/zeelos/cockpit-leshan/releases) for easy installation). Further, we recommend to install `cockpit-docker`, `cockpit-storaged` and `cockpit-networkmanager` plugins for further introspection and administration of the cloud and edge hardware.

### Step-by-Step

1. Initialize your Swarm cluster with at least one manager node and one worker. In the following `'saturn'` host plays the role of a manager node with the other `edge` hardware playing the role of workers:

		➜  zeelos git:(master) ✗ docker node ls
		ID                            HOSTNAME              STATUS              AVAILABILITY        MANAGER STATUS      ENGINE VERSION
		nn0xxqopfuu6bib06a4m477o3     rock64                Ready               Active                                  18.06.1-ce
		m8x5f0xet2bk9mb4od8m0bj7e *   saturn                Ready               Active              Leader              18.06.1-ce
		75cvshqeuozofkhdctretv4t4     tinkerboard           Ready               Active                                  18.06.1-ce
		kopkm2u73yyd1vngwusnmcfts     upboard               Ready               Active                                  18.06.1-ce

	> NOTE:
	> The manager node will be used to deploy all cloud services and in this guide we refer to is as the `cloud node`.


2. Assign labels to nodes so services would be propagated to the correct node upon deployment:

		docker node update --label-add type=cloud saturn
		docker node update --label-add type=upboard upboard
		docker node update --label-add type=tinkerboard tinkerboard
		docker node update --label-add type=rock64 rock64


3. Create overlay networks for cloud, monitoring and edge gateways: 

		docker network create --driver overlay cloudnet
		docker network create --driver overlay monnet
		docker network create --driver overlay edgenet_upboard
		docker network create --driver overlay edgenet_tinkerboard
		docker network create --driver overlay edgenet_rock64


4. Generate certificates to [enable SSL encryption and authentication in Kafka](https://docs.confluent.io/current/kafka/authentication_ssl.html#kafka-ssl-authentication). We provide a convenience script based on the [kafka-cluster-ssl](https://github.com/confluentinc/cp-docker-images/tree/master/examples/kafka-cluster-ssl/secrets) script found in Confluent's docker distribution.

		cd security && ./certs-create.sh

	The generated certificates can be found inside the `security/` folder and would be attached to Swarm cluster as [secrets](https://docs.docker.com/engine/swarm/secrets/#defining-and-using-secrets-in-compose-files).

	>NOTE:
	>The main goal here was to enable SSL encryption both in cloud and edge Kafka nodes, in order to assess the overhead of SSL on hardware with limited resources. We do not advertise this approach as be a production ready, since it lacks many other security features (e.g. [Authorization and ACLs](https://docs.confluent.io/current/kafka/authorization.html)).


5. Deploy [`monitoring`](https://github.com/zeelos/zeelos/blob/master/monitoring.dockerapp/docker-compose.yml) stack: 

		docker-app deploy monitoring
		
	Monitoring services are replicated globally and are multi-arch compatible so each node in the cluster will start running them as soon as the image downloads finish.

	> NOTE:
	> Since services are replicated globally, when a new node joins the swarm cluster, monitoring services are start automatically, easying the administration burden.

	Verify that monitoring stack has started by doing a `'docker ps'` on an edge node:

		rock64@rock64:~$ docker ps
		CONTAINER ID        IMAGE                                              COMMAND                  CREATED             STATUS              PORTS                                                                              NAMES
		89726175821c        zeelos/docker_exporter:1.7.3.1                     "/bin/sh -c 'socat -…"   2 hours ago         Up 2 hours                                                                                             monitoring_docker-exporter.nn0xxqopfuu6bib06a4m477o3.g74jhiwapcr9itk1hdskpxp22
		128dd34dae0c        zeelos/cadvisor:v0.30.2                            "/usr/bin/cadvisor -…"   2 hours ago         Up 2 hours          8080/tcp                                                                           monitoring_cadvisor.nn0xxqopfuu6bib06a4m477o3.4ogyz9khudol6ehmyasnhu6es
		43bd5c3cbabf        zeelos/node_exporter:v0.16.0                       "/usr/bin/docker-ent…"   2 hours ago         Up 2 hours          8080/tcp                                                                           monitoring_node-exporter.nn0xxqopfuu6bib06a4m477o3.lq7skc5fvouuzze8gxq9ge7mo

	In the cloud node, verify that `prometheus`, `alertmanager` and `unsee` services have all been started too:
	
		➜  zeelos@saturn docker ps               
		CONTAINER ID        IMAGE                                               COMMAND                  CREATED              STATUS                  PORTS                          NAMES
		d577a095669c        prom/alertmanager:v0.15.2                           "/bin/alertmanager -…"   8 hours ago          Up 8 hours              9093/tcp                       monitoring_alertmanager.1.h8v4kbtc07rerglv7ay19ey5r
		78f0f4e5ce46        prom/prometheus:v2.3.2                              "/bin/prometheus --c…"   8 hours ago          Up 8 hours              9090/tcp                       monitoring_prometheus.1.v25fdvrmx1t7jj7ar1fv16wyw
		5a8c73d11029        cloudflare/unsee:v0.9.2                             "/unsee"                 8 hours ago          Up 8 hours              8080/tcp                       monitoring_unsee.1.9ts5x0539h4j3x7r5nnxdpu1b

	
6. Deploy [`cloud`](https://github.com/zeelos/zeelos/blob/master/cloud.dockerapp/docker-compose.yml) stack: 

		docker-app deploy cloud
	
	On the cloud node, verify that cloud services have all been started correctly:

		➜  zeelos git:(master) ✗ docker ps               
		CONTAINER ID        IMAGE                                               COMMAND                  CREATED              STATUS                  PORTS                          NAMES
		3b3cb847f5a5        zeelos/kafka_exporter:v1.2.0                        "/usr/bin/kafka_expo…"   8 hours ago          Up 8 hours              8080/tcp                       cloud_kafka-exporter-cloud.1.t719fc3eczl8bu9kdfohuhweh
		f3d6c34512e3        confluentinc/cp-schema-registry:5.0.0               "/etc/confluent/dock…"   8 hours ago          Up 8 hours              8081/tcp                       cloud_schema-registry-cloud.1.q72ty6poet3blixsgx9qtpndk
		932d2b848122        confluentinc/cp-kafka-rest:5.0.0                    "/etc/confluent/dock…"   8 hours ago          Up 8 hours              8082/tcp                       cloud_kafka-rest-cloud.1.w7pa64cwbln4sghibwgkamkbd
		00829ab46593        confluentinc/cp-kafka-connect-base:5.0.0            "bash -c -a 'tail -f…"   8 hours ago          Up 8 hours              8083/tcp, 9092/tcp             cloud_kafka-command-client.1.3nmmz8lccvd25jq2md2dzyh3u
		c58406cb80ce        zeelos/influxdb:1.6.3-with-zeelosdb                 "/entrypoint.sh infl…"   8 hours ago          Up 8 hours              8086/tcp                       cloud_influxdb.1.9o0v5fzvnzfcnp717inhq6cym
		65b658bb5b35        zeelos/orientdb:3.0.8-tp3-with-zeelosdb             "server.sh"              8 hours ago          Up 8 hours              2424/tcp, 2480/tcp             cloud_orientdb.1.yf07hk6c4lbjzq0o7slp2r9hw
		5d088ebc3d18        confluentinc/cp-zookeeper:5.0.0                     "/etc/confluent/dock…"   8 hours ago          Up 8 hours              2181/tcp, 2888/tcp, 3888/tcp   cloud_zookeeper-cloud.1.mv32u8fxjlpl2jhw9de16j7mo
		59ab141f8b9b        confluentinc/cp-kafka:5.0.0                         "/etc/confluent/dock…"   8 hours ago          Up 8 hours              9092/tcp                       cloud_kafka-cloud.1.lilwriyw0fp9blrl4d33y2s8k
		c9f5702e474f        zeelos/grafana:5.2.4-influx-with-zeelosdb           "/run.sh"                8 hours ago          Up 8 hours              3000/tcp                       cloud_grafana.1.xqflcej9yg9ajixw9vmfz3h4v


7. Deploy [`gateway`](https://github.com/zeelos/zeelos/blob/master/cloud.dockerapp/docker-compose.yml) stack for each edge gateway hardware: 

		docker-app deploy gateway -d gateway-upboard -s gateway.id=upboard
		docker-app deploy gateway -d gateway-tinkerboard -s gateway.id=tinkerboard -f gateway.dockerapp/settings.arm32v7.yml
		docker-app deploy gateway -d gateway-rock64 -s gateway.id=rock64 -f gateway.dockerapp/settings.arm64v8.yml

	> NOTE:
	> Notice the use of the gateway.id parameter for each edge node as well as the passing of the appropriate settings for each hardware architecture.

	Verify the gateway stack has started by doing a `'docker ps'` on an edge node. For example here is `docker ps` on `rock64/arm64v8` hardware:

		rock64@rock64:~$ docker ps
		CONTAINER ID        IMAGE                                              COMMAND                  CREATED             STATUS              PORTS                                                                              NAMES
		5f438a90f5f2        zeelos/kafka_exporter:v1.2.0                       "/usr/bin/kafka_expo…"   42 hours ago        Up 42 hours         8080/tcp                                                                           gateway-rock64_kafka-exporter-gateway.1.1t4o8pyzjkwbevo489z9bqc80
		d5ce547527b5        zeelos/cp-kafka-rest:5.0.0-arm64v8                 "/etc/confluent/dock…"   42 hours ago        Up 42 hours         0.0.0.0:8072->8072/tcp, 0.0.0.0:9573->9573/tcp, 8082/tcp                           gateway-rock64_kafka-rest-gateway.1.p8h7xngza32iryy4ggh7ghhhw
		2e727557da93        zeelos/cp-kafka-connect-base:5.0.0-arm64v8         "bash -c -a 'tail -f…"   42 hours ago        Up 42 hours         8083/tcp, 9092/tcp                                                                 gateway-rock64_kafka-command-client.1.r3d78xj46nabmcrhawbcnz3om
		b83283a62ad4        zeelos/cp-schema-registry:5.0.0-arm64v8            "/etc/confluent/dock…"   42 hours ago        Up 42 hours         0.0.0.0:8071->8071/tcp, 0.0.0.0:9572->9572/tcp, 8081/tcp                           gateway-rock64_schema-registry-gateway.1.0vdkfs2xkhtg3jqokp3abzvku
		8f1c55975bf5        zeelos/cp-kafka:5.0.0-arm64v8                      "/etc/confluent/dock…"   42 hours ago        Up 42 hours         0.0.0.0:9082->9082/tcp, 0.0.0.0:9571->9571/tcp, 9092/tcp                           gateway-rock64_kafka-gateway.1.emdk0nv5uv71kdq4iecs8atbg
		358defcc3401        zeelos/cp-zookeeper:5.0.0-arm64v8                  "/etc/confluent/dock…"   42 hours ago        Up 42 hours         2181/tcp, 2888/tcp, 0.0.0.0:2171->2171/tcp, 0.0.0.0:9575->9575/tcp, 3888/tcp       gateway-rock64_zookeeper-gateway.1.1unhhjl6pg95thibeqs1xywb2
		ca704a6ad79a        zeelos/kafka-mirrormaker:5.0.0-arm64v8             "/etc/confluent/dock…"   42 hours ago        Up 42 hours         0.0.0.0:9564->9564/tcp                                                             gateway-rock64_kafka-mirrormaker-gateway.1.26p4cap0xokfu6zz0456ilss8
		165f855bad3e        zeelos/leshan-server-kafka:0.2-SNAPSHOT-arm64v8    "./entrypoint.sh"        42 hours ago        Up 42 hours         0.0.0.0:8080->8080/tcp, 0.0.0.0:5683-5684->5683-5684/udp, 0.0.0.0:9590->9590/tcp   gateway-rock64_leshan-server-kafka-gateway.1.qbt9ecbgspk48q0c9nyfcfksh

	> NOTE:
	> Notice the `arm64v8` docker images of Apache Kafka services. This was made possible by appropriate modifications of Confluent`s docker images in order to be based on Arm. Check the [arm32v7](https://github.com/zeelos/cp-docker-images/tree/5.0.0-post-arm32v7) and [arm64v8](https://github.com/zeelos/cp-docker-images/tree/5.0.0-post-arm64v8) branches in the forked [cp-docker-images](https://github.com/zeelos/cp-docker-images) repository.
	
	> NOTE:
	> If you are feeling adventurous, there is also an [openj9](https://github.com/zeelos/cp-docker-images/tree/5.0.0-post-openj9) branch that uses [Eclipse OpenJ9](https://www.eclipse.org/openj9/) as the base Java Runtime environment, which further improves the memory efficiency (currently only for x86 architectures).
		
		docker-app deploy gateway -d gateway-upboard -s gateway.id=upboard -f gateway.dockerapp/settings.openj9.yml 


8. Deploy [`mirrormaker`](https://github.com/zeelos/zeelos/blob/master/mirrormaker.dockerapp/docker-compose.yml) stack to enable replication of data from edge gateway's to the cloud:

		docker-app deploy mirrormaker -d mirromaker-upboard -s gateway.id=upboard
		docker-app deploy mirrormaker -d mirromaker-tinkerboard -s gateway.id=tinkerboard
		docker-app deploy mirrormaker -d mirromaker-rock64 -s gateway.id=rock64

	On the cloud node, verify that mirrormaker services have all been started correctly:
		
		➜  zeelos git:(master) ✗ docker ps
		CONTAINER ID        IMAGE                                               COMMAND                  CREATED             STATUS              PORTS                          NAMES
		dc04ae5be39d        zeelos/kafka-mirrormaker:5.0.0                      "/etc/confluent/dock…"   25 hours ago        Up 25 hours                                        mirromaker-upboard_kafka-mirrormaker.1.6jddrekd4smnkhwhtyap8c4em
		d8f31cdbaf01        zeelos/kafka-mirrormaker:5.0.0                      "/etc/confluent/dock…"   25 hours ago        Up 25 hours                                        mirromaker-rock64_kafka-mirrormaker.1.iwqo2ejvpyn2afn4xiblyje34
		aaf11axdas02        zeelos/kafka-mirrormaker:5.0.0                      "/etc/confluent/dock…"   25 hours ago        Up 25 hours                                        mirromaker-tinkerboard_kafka-mirrormaker.1.sym2sop2wq0yqyma12vnx


9. Deploy [`kafka-connect cluster`](https://github.com/zeelos/zeelos/blob/master/connect-clusters.dockerapp/docker-compose.yml) stack: 

		docker-app deploy connect-clusters -d connect-upboard -s gateway.id=upboard
		docker-app deploy connect-clusters -d connect-tinkerboard -s gateway.id=tinkerboard
		docker-app deploy connect-clusters -d connect-rock64 -s gateway.id=rock64

	> NOTE:
	> Notice the use of the gateway.id parameter for each edge node.

	On the cloud node, verify the connect cluster services have started correctly for each gateway:

		➜  zeelos git:(master) ✗ docker ps
		CONTAINER ID        IMAGE                                               COMMAND                  CREATED             STATUS              PORTS                          NAMES
		068b88156da4        zeelos/kafka-connect-leshan-influxdb:0.2-SNAPSHOT   "/etc/confluent/dock…"   11 hours ago        Up 11 hours         8083/tcp, 9092/tcp             connect-rock64_kafka-connect-leshan-asset.1.1kwz2m9lumai89rbggo8nhyxj
		fc9d72401e48        zeelos/kafka-connect-leshan-influxdb:0.2-SNAPSHOT   "/etc/confluent/dock…"   11 hours ago        Up 11 hours         8083/tcp, 9092/tcp             connect-rock64_kafka-connect-influxdb.1.i5ho7zccbypst8pcfdf6ie6cz
		c4dadbad83ee        zeelos/kafka-connect-leshan-influxdb:0.2-SNAPSHOT   "/etc/confluent/dock…"   11 hours ago        Up 11 hours         8083/tcp, 9092/tcp             connect-upboard_kafka-connect-leshan-asset.1.krkunw30fhtar8i7c8nba9yda
		e42a2b2d0df8        zeelos/kafka-connect-leshan-influxdb:0.2-SNAPSHOT   "/etc/confluent/dock…"   11 hours ago        Up 11 hours         8083/tcp, 9092/tcp             connect-upboard_kafka-connect-influxdb.1.ns1cistwdzeqow8zoa6w4oj90
		s2ddfbausjxk        zeelos/kafka-connect-leshan-influxdb:0.2-SNAPSHOT   "/etc/confluent/dock…"   11 hours ago        Up 11 hours         8083/tcp, 9092/tcp             connect-tinkerboard_kafka-connect-leshan-asset.1.xjs2lakj21yiqp29y
		e42a2b2d0df8        zeelos/kafka-connect-leshan-influxdb:0.2-SNAPSHOT   "/etc/confluent/dock…"   11 hours ago        Up 11 hours         8083/tcp, 9092/tcp             connect-tinkerboard_kafka-connect-influxdb.1.sym2sop2wq0yqyma12vnx


10. Create **_'request'_** topics on the cloud node for each connected gateway. Clients will use that topic to send requests to the edge gateway (topic [will be replicated](https://github.com/zeelos/zeelos/blob/master/gateway.dockerapp/docker-compose.yml#L213-L261) automatically from `cloud` to each `edge` gateway) :

		docker exec -it <container-id> bash -c "kafka-topics --create --topic "iot.upboard.management.req" --zookeeper zookeeper-cloud:2181 --partitions 1 --replication-factor 1"

	Repeat for each connected gateway, replacing the topic name with the correct edge gateway name e.g `iot.tinkerboard.management.req`,           `iot.rock64.management.req`

	> NOTE:
	> You need to determine and note down the docker container id of the [kafka-command-client](https://github.com/zeelos/zeelos/blob/master/cloud.dockerapp/docker-compose.yml#L187-L210) which is used to issue commands in the cloud cluster.


11. Create **_'registration/response/observation'_** topics on `cloud node` with partition parameter set according to your requirements (we use two here to demonstrate scaling with the Connect framework). [Leshan Server Kafka](https://github.com/zeelos/leshan-server-kafka) running on the edge will use those topics to store all of it's messages (topics [would be replicated](https://github.com/zeelos/zeelos/blob/master/mirrormaker.dockerapp/docker-compose.yml) automatically from `edge node` to `cloud node`)

	> NOTE:
	> On `edge nodes`, topics are set to be created automatically by the Kafka configuration with default partition number set to 1. According to your needs on the edge and its hardware characteristics (e.g if you use multiple kafka stream instances), you can choose to override by setting the appropriate configuration option in the [edge stack](https://github.com/zeelos/zeelos/blob/master/gateway.dockerapp/docker-compose.yml#L47-L105).
	

		docker exec -it <container-id> bash -c "kafka-topics --create --topic "iot.upboard.management.rep" --zookeeper zookeeper-cloud:2181 --partitions 2 --replication-factor 1" && \
		docker exec -it <container-id> bash -c "kafka-topics --create --topic "iot.upboard.observations" --zookeeper zookeeper-cloud:2181 --partitions 2 --replication-factor 1" && \
		docker exec -it <container-id> bash -c "kafka-topics --create --topic "iot.upboard.registrations" --zookeeper zookeeper-cloud:2181 --partitions 2 --replication-factor 1"


12. Deploy [a series of connectors](https://github.com/zeelos/zeelos/tree/master/configs/kafka-connect) on `kafka-connect clusters` started earlier.  Time-series data are stored on [InfluxDB](https://www.influxdata.com/time-series-platform/influxdb/) whereas for visualizing the Leshan LWM2M model, the graph database [OrientDB](http://orientdb.com) is used using our [custom developed connector](https://github.com/cvasilak/kafka-connect-leshan-asset). Notice that we follow the approach of having separate connect cluster for each connector so that we can scale independently without affecting others.

    >NOTE:
	>Since data are flowing into Kafka [any other connector](https://www.confluent.io/product/connectors/) can be used. For example, you can use the [Elastic Search connector](https://docs.confluent.io/current/connect/connect-elasticsearch/docs/elasticsearch_connector.html) to store the time series or/and the LWM2M model data to [Elasticsearch](https://www.elastic.co/products/elasticsearch).
 
		export GATEWAY_ID=[upboard|rock64|tinkerboard]

    	cd ./configs && \
		LESHAN_ASSET_CONECTOR_CONFIG=`sed -e "s/GATEWAY_ID/$GATEWAY_ID/g" kafka-connect/kafka-connect-leshan-asset/connect-leshan-sink-asset.json` && \
		docker exec -it <connect-asset-container-id> curl -X POST -H "Content-Type: application/json" -d "$LESHAN_ASSET_CONECTOR_CONFIG" -k --cert /etc/kafka/secrets/client-cloud.certificate.pem --key ./etc/kafka/secrets/client-cloud.key https://localhost:8083/connectors && \
		INFLUXDB_CONECTOR_CONFIG=`sed -e "s/GATEWAY_ID/$GATEWAY_ID/g" kafka-connect/kafka-connect-influxdb/connect-influxdb-sink.json` && \
		docker exec -it <connect-influxdb-container-id> curl -X POST -H "Content-Type: application/json" -d "$INFLUXDB_CONECTOR_CONFIG" -k --cert /etc/kafka/secrets/client-cloud.certificate.pem --key ./etc/kafka/secrets/client-cloud.key https://localhost:8083/connectors

	> NOTE:
	> Adjust the GATEWAY_ID env variable with the name of the gateway you target.

	> NOTE:
	> Adjust `<connect-asset-container-id>` and `<connect-influxdb-container-id>` with the docker container id of the running connect cluster for each gateway.

		➜  zeelos git:(master) ✗ docker ps

		CONTAINER ID        IMAGE                                               COMMAND                  CREATED             STATUS              PORTS                          NAMES
		43539f5d03c7        zeelos/kafka-connect-leshan-influxdb:0.2-SNAPSHOT   "/etc/confluent/dock…"   15 hours ago        Up 15 hours         8083/tcp, 9092/tcp             connect-upboard_kafka-connect-leshan-asset.1.ol955j8z76tqp8tcrp8tbrqhr
		ab9cede8be8a        zeelos/kafka-connect-leshan-influxdb:0.2-SNAPSHOT   "/etc/confluent/dock…"   15 hours ago        Up 15 hours         8083/tcp, 9092/tcp             connect-upboard_kafka-connect-influxdb.1.w8racy837yrilbs415n8eok1q

	Verify that each connector is successfully installed:

		➜  zeelos git:(master) ✗ docker exec -it <connect-influxdb-container-id> curl -X GET -k --cert /etc/kafka/secrets/client-cloud.certificate.pem --key ./etc/kafka/secrets/client-cloud.key https://localhost:8083/connectors/
		
		["upboard_influxdb_sink"]

		➜  zeelos git:(master) ✗ docker exec -it <connect-influxdb-container-id> curl -X GET -k --cert /etc/kafka/secrets/client-cloud.certificate.pem --key ./etc/kafka/secrets/client-cloud.key https://localhost:8083/connectors/upboard_influxdb_sink/status
		
		{"name":"upboard_influxdb_sink","connector":{"state":"RUNNING","worker_id":"kafka-connect-influxdb:8083"},"tasks":[{"state":"RUNNING","id":0,"worker_id":"kafka-connect-influxdb:8083"}],"type":"sink"}

		➜  zeelos git:(master) ✗ docker exec -it <connect-asset-container-id> curl -X GET -k --cert /etc/kafka/secrets/client-cloud.certificate.pem --key ./etc/kafka/secrets/client-cloud.key https://localhost:8083/connectors/
		
		["upboard_leshan_asset_sink"]

		➜  zeelos git:(master) ✗ docker exec -it <connect-asset-container-id> curl -X GET -k --cert /etc/kafka/secrets/client-cloud.certificate.pem --key ./etc/kafka/secrets/client-cloud.key https://localhost:8083/connectors/upboard_leshan_asset_sink/status
		
		{"name":"upboard_leshan_asset_sink","connector":{"state":"RUNNING","worker_id":"kafka-connect-leshan-asset:8083"},"tasks":[{"state":"RUNNING","id":0,"worker_id":"kafka-connect-leshan-asset:8083"}],"type":"sink"}% 


13. Start a [virtual sensor client demo](https://github.com/zeelos/leshan-client-demo) that will attach on the Leshan server running at the edge:

		➜  zeelos git:(master) ✗ docker service create --name leshan-client-demo-1-$GATEWAY_ID --network edgenet_$GATEWAY_ID --constraint "node.labels.type == cloud" -e JAVA_OPTS="-Djava.rmi.server.hostname=localhost -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.rmi.port=8000 -Dcom.sun.management.jmxremote.port=8000 -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Xmx32M -Xms32M" zeelos/leshan-client-demo:0.2-SNAPSHOT -u leshan-server-kafka-gateway

	> NOTE:
	> We use the GATEWAY_ID env variable defined earlier to specify the gateway we target to.

	> NOTE:
	> We schedule the client demo to run on the cloud node but you can use any other node.
	
	> NOTE:
	> We strive to enable JMX on all Java running services to aid with monitoring. If you inspect the docker-compose files for cloud and edge you will see that JMX is enabled by default. You can then use your favourite tool to inspect the JVM (e.g. [VisualVM](https://visualvm.github.io)). Since the service is running inside docker (and possible docker-machine), to simplify configuration, the hostname we bound the service is `localhost` so you need to use an ssh tunnel to connect to (this also gives an advantage to avoid arbitrarily JMX connections from outside and only allow through SSH tunnel).
	>
	>For example, to connect to kafka server running on the edge, start a tunnel to the edge gateway:
		
		ssh -v -NL 9581:<edge hostname>:9581 user@<edge hostname>

	And then add it as a _'local connection'_ to the VisualVM tool:

   ![VisuaVM](https://image.ibb.co/iwLfJH/visualvm.png)
		

14. Visit [Cockpit's Leshan Server interface](https://github.com/zeelos/cockpit-leshan) and click on the sensor to get to the information page. Once there, start an '*Observation*' on the two simulated sensor instance resources on the '*Temperature*' object:

	![Leshan](https://image.ibb.co/esoUnK/cockpit_leshan.png)


15. Visit Grafana web interface and notice that received sensor values are correctly propagated from the edge to the cloud (using [replication](https://docs.confluent.io/current/multi-dc/mirrormaker.html)) and from there to the database by the [InfluxDB Kafka connector](http://lenses.stream/connectors/sink/influx.html):

	![Grafana](https://image.ibb.co/ibai25/grafana.png)


16. Start a [jmeter-leshan demo](https://github.com/zeelos/lwm2m-jmeter) to connect multiple virtual sensors and to perform any benchmarking tests (adjust command line parameters accordingly)

		➜  zeelos git:(master) ✗ docker service create --name jmeter-leshan-$GATEWAY_ID --network edgenet_$GATEWAY_ID --constraint "node.labels.type == cloud" zeelos/jmeter-leshan:0.0.1-SNAPSHOT -n -t /opt/jmeter/tests/leshan.jmx -JserverHost=leshan-server-kafka-gateway -JserverPort=5683 -JrestPort=8080 -Jthreads=10 -JthreadsRampUp=3 -JthreadsLoopCount=600 -JthreadDelayObserveSend=1000


17. Visit OrientDB web interface to get a visual representation of all the sensors currently connected. Similar to Grafana, the OrientDB database is filled by another [Kafka connector](https://github.com/zeelos/kafka-connect-leshan-asset) from the incoming data from the edge.

	Once login, click the 'Graph' tab and on the graph editor do a simple query like '`select from Servers`' to get the current active Leshan server. From there you can start exploring by selecting the server and clicking the expand button:

	![OrientDB](https://image.ibb.co/cCM15Q/orientdb.png)

	Click on an endpoint and notice the left pane will contain it's properties (e.g. last registration update, binding mode etc):
	
	![OrientDB-props](http://image.ibb.co/cmZbAx/orientdb_properties.png)


18. We can easily scale each Kafka Connect cluster to two instances (or more) to cope with the increased _'simulated demand'_:

		docker service scale connect-upboard_kafka-connect-influxdb=2
		docker service scale connect-upboard_kafka-connect-leshan-asset=2

	> NOTE:
	> Make sure you also update the [`tasks.max`](https://docs.confluent.io/2.0.0/connect/userguide.html#configuring-connectors) configuration of the connectors. 

	For example, notice in the following screenshot, that tasks of the InfluxDBSink and LeshanAssetSink connectors are deployed in the first instance(top) and on the second one (bottom) and both being kept busy:
	
	![Kafka Connect Scale](https://image.ibb.co/jiQfQw/kafka_connect_scale.jpg)


19. Start some [Kafka Streams Analytics](https://github.com/zeelos/kafka-streams-leshan) that will run at the edge (notice the  `--constraint` parameter that explicitly specifies the edge node that this analytic will run on). [The first analytic](https://github.com/zeelos/kafka-streams-leshan/blob/master/src/main/java/io/zeelos/leshan/kafka/streams/SimpleAnalyticsStreamsApp.java#L78-L107) aggregates sensor readings by '`endpoint id`' and by '`endpoint id`' and '`path`' per minute and outputs the result in the console. Connect to the edge node that you run the analytic and use `docker logs -f <container_id>` to watch it's output:

		docker service create --name kstreams-${GATEWAY_ID}-aggregate --network edgenet_${GATEWAY_ID} --constraint "node.labels.type == ${GATEWAY_ID}" --secret "source=gateway-${GATEWAY_ID}_client_security_gateway.properties,target=/etc/kafka/secrets/client_security_gateway.properties" --secret "source=gateway-${GATEWAY_ID}_kafka.client-gateway.keystore.jks,target=/etc/kafka/secrets/kafka.client-gateway.keystore.jks" --secret "source=gateway-${GATEWAY_ID}_kafka.client-gateway.truststore.jks,target=/etc/kafka/secrets/kafka.client-gateway.truststore.jks" -e JAVA_OPTS="-Djava.rmi.server.hostname=localhost -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.rmi.port=9000 -Dcom.sun.management.jmxremote.port=9000 -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djavax.net.ssl.trustStore=/etc/kafka/secrets/kafka.client-gateway.truststore.jks -Djavax.net.ssl.trustStorePassword=itsasecret -Djavax.net.ssl.keyStore=/etc/kafka/secrets/kafka.client-gateway.keystore.jks -Djavax.net.ssl.keyStorePassword=itsasecret" zeelos/kafka-streams-leshan:0.2-SNAPSHOT io.zeelos.leshan.kafka.streams.SimpleAnalyticsStreamsApp kafka-gateway:9082 https://schema-registry-gateway:8071 iot.${GATEWAY_ID}.observations /etc/kafka/secrets/client_security_gateway.properties

	[The second analytic](https://github.com/zeelos/kafka-streams-leshan/blob/master/src/main/java/io/zeelos/leshan/kafka/streams/TemperatureStreamsApp.java#L86-L126) calculates the maximum temperature of the incoming observations grouped by '`endpoint id`' and '`path`' over a period of 30 secs and outputs the result in the `analytics.$GATEWAY_ID.observations.maxper30sec` topic:
	
		docker service create --name kstreams-${GATEWAY_ID}-temperature --network edgenet_${GATEWAY_ID} --constraint "node.labels.type == ${GATEWAY_ID}" --secret "source=gateway-${GATEWAY_ID}_client_security_gateway.properties,target=/etc/kafka/secrets/client_security_gateway.properties" --secret "source=gateway-${GATEWAY_ID}_kafka.client-gateway.keystore.jks,target=/etc/kafka/secrets/kafka.client-gateway.keystore.jks" --secret "source=gateway-${GATEWAY_ID}_kafka.client-gateway.truststore.jks,target=/etc/kafka/secrets/kafka.client-gateway.truststore.jks" -e JAVA_OPTS="-Djava.rmi.server.hostname=localhost -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.rmi.port=9000 -Dcom.sun.management.jmxremote.port=9000 -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djavax.net.ssl.trustStore=/etc/kafka/secrets/kafka.client-gateway.truststore.jks -Djavax.net.ssl.trustStorePassword=itsasecret -Djavax.net.ssl.keyStore=/etc/kafka/secrets/kafka.client-gateway.keystore.jks -Djavax.net.ssl.keyStorePassword=itsasecret" zeelos/kafka-streams-leshan:0.2-SNAPSHOT io.zeelos.leshan.kafka.streams.TemperatureStreamsApp kafka-gateway:9082 https://schema-registry-gateway:8071 iot.$GATEWAY_ID.observations analytics.$GATEWAY_ID.observations.maxper30sec /etc/kafka/secrets/client_security_gateway.properties

	> NOTE:
	> We use the GATEWAY_ID env variable defined earlier to specify the gateway we target to.

	> NOTE:		
	> The output of the analytic resides on `analytics.$GATEWAY_ID.observations.maxper30sec` topic at each edge gateway.

	> NOTE:		
	> For `arm32v7` and `arm64v8` edge gateways, we need to use the arm specific images. For that, just postfix the image name with `-arm32v7` or `-arm64v8`. For example, `zeelos/kafka-streams-leshan:0.2-SNAPSHOT-arm32v7` or `zeelos/kafka-streams-leshan:0.2-SNAPSHOT-arm64v8` for `arm32v7` and `arm64v8` respectively. Further, due to low memory of the edge hardware, we suggest to lower the heap requirements of the Java VM. From our tests specifying `-Xmx32M -Xms32M` for `arm32v7` or `-Xmx64M -Xms64M` for `arm64v8` seems to work correctly.

		
20. Subscribe to Kafka topics on the `cloud` node to watch incoming Leshan LWM2M protocol messages (`registrations` / `observations`) coming from `edge` nodes:

		docker exec -it <kafka-command-client-container-id> kafka-avro-console-consumer --topic iot.${GATEWAY_ID}.registrations --bootstrap-server kafka-cloud:9092 --property schema.registry.url=https://schema-registry-cloud:8081 --property print.key=true --consumer.config /etc/kafka/secrets/client_security_cloud.properties

		docker exec -it <kafka-command-client-container-id> kafka-avro-console-consumer --topic iot.${GATEWAY_ID}.observations --bootstrap-server kafka-cloud:9092 --property schema.registry.url=https://schema-registry-cloud:8081 --property print.key=true --consumer.config /etc/kafka/secrets/client_security_cloud.properties

	> NOTE:
	> Use the [kafka-command-client](https://github.com/zeelos/zeelos/blob/master/cloud.dockerapp/docker-compose.yml#L187-L210) container id to execute commands against the cloud kafka cluster.
	
	> NOTE:
	> We use the GATEWAY_ID env variable defined earlier to specify the gateway we target to.


21. Make some requests against an `edge` node Leshan Server. Notice that clients invoke them on the central `cloud` node and the request gets propagated on the edge using [replication](https://docs.confluent.io/current/multi-dc/mirrormaker.html) and back. 

	First subscribe to the reponse topic `iot.${GATEWAY_ID}.management.rep` to view the reply of your request:

		docker exec -it <kafka-command-client-container-id> kafka-avro-console-consumer --topic iot.${GATEWAY_ID}.management.rep --bootstrap-server kafka-cloud:9092 --property schema.registry.url=https://schema-registry-cloud:8081 --property print.key=true --consumer.config /etc/kafka/secrets/client_security_cloud.properties
		
	Now issue commands by producing messages to the request topic `iot.${GATEWAY_ID}.management.req`:
	
		docker exec -it <kafka-command-client-container-id> kafka-avro-console-producer --topic iot.${GATEWAY_ID}.management.req --property value.schema="$(< ./schemas/request-schema.json)" --broker-list kafka-cloud:9092 --property schema.registry.url=https://schema-registry-cloud:8081 --producer.config /etc/kafka/secrets/client_security_cloud.properties

	Format of the requests is as follow (complying to the [Avro request schema](https://github.com/zeelos/zeelos/blob/master/schemas/request-schema.json))
	
	    --"observe" request--
        {"serverId": "rock64", "ep": "<endpoint-id>", "ticket": "ticket#1", "payload": {"kind": "observe", "path": "/3303/0/5700", "contentFormat": "TLV", "body": null}}

    	--"observeCancel" request--
        {"serverId": "rock64", "ep": "<endpoint-id>", "ticket": "ticket#1", "payload": {"kind": "observeCancel", "path": "/3303/0/5700", "contentFormat": "TLV", "body": null}}
            
	    --"read" request--
	    # string type
		{"serverId": "rock64", "ep": "<endpoint-id>", "ticket": "ticket#2", "payload": {"kind": "read", "path": "/3/0/0", "contentFormat": "TLV", "body": null}}

		# boolean type
		{"serverId": "rock64", "ep": "<endpoint-id>", "ticket": "ticket#3", "payload": {"kind": "read", "path": "/1/0/6", "contentFormat": "TLV", "body": null}}
	        
	    --"write" request--
	    {"serverId": "rock64", "ep": "<endpoint-id>", "ticket": "ticket#4", "payload": {"kind": "write", "path": "/1/0/6", "contentFormat": "TLV", "body":{"io.zeelos.leshan.avro.request.AvroWriteRequest":{"mode":"REPLACE", "node":{"io.zeelos.leshan.avro.resource.AvroResource":{"id":6,"path":"/1/0/6","kind":"SINGLE_RESOURCE","type":"BOOLEAN","value":{"boolean":false}}}}}}}
	
	    --"execute" request--
	    {"serverId": "server1", "ep": "<endpoint-id>", "ticket": "ticket#5", "payload": {"kind": "execute", "path": "/3/0/4", "contentFormat": "TLV", "body":{"io.zeelos.leshan.avro.request.AvroExecuteRequest":{"parameters":"param1,param2"}}}}
	    
	>NOTE:
	>Requests can target either an "object" (e.g /3), an "object instance" (e.g 3/0), or a specific "resource" (e.g /3/0/1).
	
	Here is an screenshot of a series of command executions(on top) together with their responses(on bottom):

	![request-response](https://image.ibb.co/nKVihK/leshan_request_response.png)
	
	Command execution is also logged at the Grafana dashboard:

	![request-response](https://image.ibb.co/cxXeNK/leshan_req_rep_grafana.png)


### Monitoring

We have paid special attention on enabling monitoring on all the services running in the cloud and on the edge. [Prometheus](https://prometheus.io/) is used to scrape metrics from services and custom dashboards in [Grafana](https://grafana.com/) are used to display that metrics. Further, as stated earlier, JMX is enabled on all Java services (e.g Kafka, KStreams) and [VisualVM](https://visualvm.github.io/) tool can also be used to directly monitor them.

Mainly monitoring is divided into two sections in Grafana:

* Monitoring Docker nodes and Swarm services (CPU/Mem, Disk, Net etc.)
* Monitoring Apache Kafka since it is the backbone of our architecture. 

For monitoring Docker, you will find two dashboards `Docker Swarm Nodes` and `Docker Swarm Services` whereas for Apache Kafka there are `Kafka Overview` and `Kafka Topics Overview`.

> NOTE:
> The Grafana dashboards for monitoring Docker cluster nodes and Swarm are based on the existing [swarmprom dashboards](https://github.com/stefanprodan/swarmprom) whereas for Kafka are based on the existing one's found in Grafana store mainly [Kafka Overview](https://grafana.com/dashboards/5484) and [Kafka Overview, Burrow consumer lag stats, Kafka disk usage](https://grafana.com/dashboards/5468). We have done some minor modifications to those dashboards to support our requirements, but still would like to say a huge Thank you to all the developers for bootstrapping our work!


![monitoring_docker_nodes](https://image.ibb.co/eVwdZz/monitoring_docker_nodes.png)

![monitoring_docker_swarm_services](https://image.ibb.co/ciy31e/monitoring_docker_swarm_services.png)

![monitoring_docker_swarm_services_2](https://image.ibb.co/eNhkEz/monitoring_docker_swarm_services_2.png)

![monitoring_kafka_overview](https://image.ibb.co/kvLDZz/monitoring_kafka_overview.png)

![monitoring_kafka_overview-2](https://image.ibb.co/gViiZz/monitoring_kafka_overview_2.png)

![monitoring_kmonitoring_kafka_topics_overview](https://image.ibb.co/eh30Ez/monitoring_kafka_topics_overview.png)


## Protocol Adapters

Although [Lightweight M2M](http://openmobilealliance.org/iot/lightweight-m2m-lwm2m) is a feature rich protocol that can serve the needs and requirements for many IoT projects ([the specification](http://www.openmobilealliance.org/release/LightweightM2M/V1_1-20180710-A/OMA-RD-LightweightM2M-V1_1-20180710-A.pdf) is easy to read), understandable there are many legacy protocols already deployed in industrial environments that need to supported. Fortunately enough, the flexible design of LWM2M allows routing of many existing protocols. As a matter of fact, we created a [Modbus](https://en.wikipedia.org/wiki/Modbus) adapter that showcase this functionality (with an [OPC-UA](https://en.wikipedia.org/wiki/OPC_Unified_Architecture) adapter currently in the works). Supporting and routing existing protocols over LWM2M is an important feature and the Open Mobile Alliance has standardize the process in the [latest version (v1.1) of the specification](http://www.openmobilealliance.org/release/LightweightM2M/V1_1-20180710-A/OMA-RD-LightweightM2M-V1_1-20180710-A.pdf) (check the LwM2M Gateway functionality section)


### Modbus to LWM2M

A protocol adapter has been created that translates LWM2M protocol messages to Modbus and back. Please have a look at the [project page](https://github.com/zeelos/leshan-client-modbus) for  more information. 


### OPC-UA to LWM2M
> currently in progress


## Hardware sensors and Operating Systems

Two widely used operating systems for emdedded devices are [Zephyr OS](https://www.zephyrproject.org/) and [Contiki-ng](https://github.com/contiki-ng/contiki-ng) and both come with support for a wide range of hardware devices as well as they provide extensive support for the LWM2M protocol. Check the [zephyr-lwm2m-client](https://github.com/zeelos/zephyr-lwm2m-client) demo and [contiki-ng-lwm2m-client
](https://github.com/zeelos/contiki-ng-lwm2m-client) demo for more information. 

## zeelos-admin-ui

We are currently working to bootstrap an administration interface that will integrate the various functionality that currently is scattered around different tools, to one main user interface. The end goal is to provide an easy to use interface for both users and developers to use the platform . Please visit the [project page](https://github.com/zeelos/zeelos-admin-ui) and contribute with comments and code!

![zeelos-admin-ui](https://image.ibb.co/kbPjFz/zeelos_admin_ui.gif)


## front-ends

> for all services use credentials **username:**`root`, **password**:`secret`
(except for Grafana where username is `admin`)

## Note about Replication

For replication between the cloud and edge Kafka installations, we chose to use the open source [Apache MirrorMaker](https://kafka.apache.org/documentation/#basic_ops_mirror_maker) tool but you are free to use any replication tool such as Confluent's own [Kafka Connect Replicator](https://docs.confluent.io/current/connect/connect-replicator/docs/connect_replicator.html).