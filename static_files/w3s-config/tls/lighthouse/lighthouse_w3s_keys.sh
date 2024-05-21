#!/bin/bash

json_directory="/validator-keys/teku-keys"
definitions_file="/root/.lighthouse/custom/validators/validator_definitions.yml"

url_w3s="$1"

if [ ! -f "$definitions_file" ]; then
    touch "$definitions_file"
fi
> $definitions_file
#bash /tmp/keymanager/generate_certs.sh
#openssl pkcs12 -in /tmp/validator_keystore.p12 -clcerts -nokeys -out /tmp/certificate.pem -passin file:/tmp/keymanager.txt

echo "---" >> "$definitions_file"
for json_file in "$json_directory"/*.json; do
    filename=$(basename -- "$json_file")
    validator_name="${filename%.json}"

    echo "- enabled: true" >> "$definitions_file"
    echo "  voting_public_key: \"$validator_name\"" >> "$definitions_file"
    echo "  type: web3signer" >> "$definitions_file"
    echo "  url: \"$url_w3s\"" >> "$definitions_file"
    #echo "  root_certificate_path: /tmp/tls/lighthouse/web3signer.pem" >> "$definitions_file"
    #echo "  client_identity_path: /tmp/tls/lighthouse/key.p12"  >> "$definitions_file"
    #echo "  client_identity_password: /tmp/tls/lighthouse/password.txt" >> "$definitions_file"

done