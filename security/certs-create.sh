#!/bin/bash

set -o nounset \
    -o errexit \
    -o verbose
#    -o xtrace

# Cleanup files
rm -f *.crt *.csr *_creds *.jks *.srl *.key *.pem *.der *.p12

# Generate CA key
openssl req -new -x509 -keyout zeelos.io-ca.key -out zeelos.io-ca.crt -days 9999 -subj '/CN=zeelos.io/OU=dev/O=zeelos.io/L=Athens/C=GR' -passin pass:itsasecret -passout pass:itsasecret

for i in kafka-cloud connect-cloud schema-registry-cloud rest-cloud client-cloud kafka-gateway schema-registry-gateway rest-gateway client-gateway
do
	echo "------------------------------- $i -------------------------------"

	# Create host keystore
	keytool -genkey -noprompt \
				 -alias $i \
				 -dname "CN=$i,OU=dev,O=zeelos.io,L=Athens,C=GR" \
                                 -ext san=dns:$i \
				 -keystore kafka.$i.keystore.jks \
				 -keyalg RSA \
				 -validity 9999 \
				 -storetype pkcs12 \
				 -storepass itsasecret \
				 -keypass itsasecret

	# Create the certificate signing request (CSR)
	keytool -keystore kafka.$i.keystore.jks -alias $i -certreq -file $i.csr -storepass itsasecret -keypass itsasecret

    # Sign the host certificate with the certificate authority (CA)
	openssl x509 -req -CA zeelos.io-ca.crt -CAkey zeelos.io-ca.key -in $i.csr -out $i-signed.crt -days 9999 -CAcreateserial -passin pass:itsasecret

    # Import the CA cert into the keystore
	keytool -noprompt -keystore kafka.$i.keystore.jks -alias CARoot -import -file zeelos.io-ca.crt -storepass itsasecret -keypass itsasecret

    # Import the signed host certificate into the keystore
	keytool -noprompt -keystore kafka.$i.keystore.jks -alias $i -import -file $i-signed.crt -storepass itsasecret -keypass itsasecret

	# Create truststore and import the CA cert
	keytool -noprompt -keystore kafka.$i.truststore.jks -alias CARoot -import -file zeelos.io-ca.crt -storepass itsasecret -keypass itsasecret

	# Save creds
  	echo "itsasecret" > ${i}_sslkey_creds
  	echo "itsasecret" > ${i}_keystore_creds
  	echo "itsasecret" > ${i}_truststore_creds

	# Create pem files and keys used for Schema Registry HTTPS testing
	#   openssl x509 -noout -modulus -in client.certificate.pem | openssl md5
	#   openssl rsa -noout -modulus -in client.key | openssl md5
    #   echo "GET /" | openssl s_client -connect localhost:8082/subjects -cert client.certificate.pem -key client.key -tls1
	keytool -export -alias $i -file $i.der -keystore kafka.$i.keystore.jks -storepass itsasecret
	openssl x509 -inform der -in $i.der -out $i.certificate.pem
	keytool -importkeystore -srckeystore kafka.$i.keystore.jks -destkeystore $i.keystore.p12 -deststoretype PKCS12 -deststorepass itsasecret -srcstorepass itsasecret -noprompt
	openssl pkcs12 -in $i.keystore.p12 -nodes -nocerts -out $i.key -passin pass:itsasecret

done
