import sys
import requests
import json

# Comprobar si se han proporcionado los argumentos necesarios
if len(sys.argv) < 3:
    print("Uso: python script.py 'clave1,clave2,...' 'api_token'")
    sys.exit(1)

# Argumento 1: Array de claves públicas, separadas por comas
public_keys = sys.argv[1].split(',')

# Argumento 2: Token de la API
api_token = sys.argv[2]

# Headers para la petición
headers = {
    "Authorization": f"Bearer {api_token}",
    "Content-Type": "application/json"
}

# URL de la petición
url = "http://localhost:5062/lighthouse/validators/web3signer"

# Bucle para enviar una petición POST por cada clave pública
for voting_public_key in public_keys:
    # Datos que se enviarán en el cuerpo de la petición POST
    data = [{
        "enable": True,
        "description": "validator_one",
        "graffiti": "Mr F was here",
        "suggested_fee_recipient": "0xa2e334e71511686bcfe38bb3ee1ad8f6babcc03d",
        "voting_public_key": voting_public_key,
        "builder_proposals": True,
        "url": "http://path-to-web3signer.com",
        "root_certificate_path": "/path/to/certificate.pem",
        "client_identity_path": "/path/to/identity.p12",
        "client_identity_password": "pass",
        "request_timeout_ms": 12000
    }]

    # Realizar la petición POST
    response = requests.post(url, headers=headers, data=json.dumps(data))

    # Imprimir la respuesta
    print(f"Status Code for {voting_public_key}: {response.status_code}")
    try:
        print(response.json())
    except json.JSONDecodeError:
        print("Response is not in JSON format.")

