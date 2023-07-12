#!/bin/sh
# Create self signed certificates.

openssl req -out ca.csr -newkey rsa:2048 -nodes -keyout ca.key -config ca.cnf
openssl x509 -req -days 3650 -in ca.csr -signkey ca.key -out ca.crt
openssl req -out server.csr -newkey rsa:2048 -nodes -keyout server.key -config server.cnf
openssl x509 -req -days 3650 -CA ca.crt -CAkey ca.key -CAcreateserial -in server.csr -out server.crt -sha256 -extfile san.ext

rm ca.csr car.key server.csr -fr
