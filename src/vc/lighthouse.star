constants = import_module("../package_io/constants.star")
input_parser = import_module("../package_io/input_parser.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
vc_shared = import_module("./shared.star")

RUST_BACKTRACE_ENVVAR_NAME = "RUST_BACKTRACE"
RUST_FULL_BACKTRACE_KEYWORD = "full"

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "error",
    constants.GLOBAL_LOG_LEVEL.warn: "warn",
    constants.GLOBAL_LOG_LEVEL.info: "info",
    constants.GLOBAL_LOG_LEVEL.debug: "debug",
    constants.GLOBAL_LOG_LEVEL.trace: "trace",
}


def get_config(
    el_cl_genesis_data,
    image,
    participant_log_level,
    global_log_level,
    beacon_http_url,
    cl_context,
    el_context,
    full_name,
    node_keystore_files,
    vc_min_cpu,
    vc_max_cpu,
    vc_min_mem,
    vc_max_mem,
    extra_params,
    extra_env_vars,
    extra_labels,
    tolerations,
    node_selectors,
    keymanager_enabled,
    network,
    electra_fork_epoch,
    w3s_context,
    plan,
    keymanager_file,
):

    
    log_level = input_parser.get_client_log_level_or_default(
        participant_log_level, global_log_level, VERBOSITY_LEVELS
    )


    cmd = [
        "lighthouse",
        "vc",
        "--debug-level=trace" ,
        #"--debug-level=" + log_level,
        "--testnet-dir=" + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER,
        # The node won't have a slashing protection database and will fail to start otherwise
        "--init-slashing-protection",
        "--beacon-nodes=" + beacon_http_url,
        # "--enable-doppelganger-protection", // Disabled to not have to wait 2 epochs before validator can start
        # burn address - If unset, the validator will scream in its logs
        "--suggested-fee-recipient=" + constants.VALIDATING_REWARDS_ACCOUNT,
        # vvvvvvvvvvvvvvvvvvv PROMETHEUS CONFIG vvvvvvvvvvvvvvvvvvvvv
        "--metrics",
        "--metrics-address=0.0.0.0",
        "--metrics-allow-origin=*",
        "--metrics-port={0}".format(vc_shared.VALIDATOR_CLIENT_METRICS_PORT_NUM),
        # ^^^^^^^^^^^^^^^^^^^ PROMETHEUS CONFIG ^^^^^^^^^^^^^^^^^^^^^
        "--graffiti=" + full_name,
         # TODO       --disable-slashing-protection-web3signer
        "--disable-slashing-protection-web3signer" 

    ]

    keymanager_api_cmd = [
        "--http",
        "--http-port={0}".format(vc_shared.VALIDATOR_HTTP_PORT_NUM),
        "--http-address=0.0.0.0",
        "--http-allow-origin=*",
        "--unencrypted-http-transport",
    ]

    if w3s_context == None: 
        validator_keys_dirpath = shared_utils.path_join(
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
            node_keystore_files.raw_keys_relative_dirpath,
        )

        validator_secrets_dirpath = shared_utils.path_join(
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
            node_keystore_files.raw_secrets_relative_dirpath,
        )

        files = {
            constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
            
        }
        cmd.extend(
            [
                "--keystoresDir=" + validator_keys_dirpath,
                "--secretsDir=" + validator_secrets_dirpath,
            ]
        )
    else: 
        w3s_config = plan.upload_files(
            src = "../../static_files/w3s-config/tls/lighthouse",
            name = "w3s_config_{}".format(full_name),
        )
      
        files = {
            constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER: w3s_context.node_keystore_files,
            "/tmp": w3s_config,
        }
        
        cmd.extend(
            [
                #"--externalSigner.url={0}".format(w3s_context.ports.url),
                #"--externalSigner.fetch",
                "--disable-auto-discover",
                "--datadir=/root/.lighthouse/custom",
            ]
        )

    if len(extra_params):
        cmd.extend([param for param in extra_params])


    env = {RUST_BACKTRACE_ENVVAR_NAME: RUST_FULL_BACKTRACE_KEYWORD}
    env.update(extra_env_vars)

    ports = {}
    ports.update(vc_shared.VALIDATOR_CLIENT_USED_PORTS)

    if keymanager_enabled:
        cmd.extend(keymanager_api_cmd)
        ports.update(vc_shared.VALIDATOR_KEYMANAGER_USED_PORTS)

    service= ServiceConfig(
        image=image,
        ports=ports,
        cmd=cmd,
        env_vars=env,
        files=files,
        min_cpu=vc_min_cpu,
        max_cpu=vc_max_cpu,
        min_memory=vc_min_mem,
        max_memory=vc_max_mem,
        labels=shared_utils.label_maker(
            constants.VC_TYPE.lighthouse,
            constants.CLIENT_TYPES.validator,
            image,
            cl_context.client_name,
            extra_labels,
        ),
        tolerations=tolerations,
        node_selectors=node_selectors,
    )

    #charge keys

    return service

def import_w3s_keys(plan, w3s_context, validator_service, token ):
   

    request_recipe = GetHttpRequestRecipe(
            port_id = "w3s-http",
            endpoint = "/api/v1/eth2/publicKeys",
            extract = {
                "body2": '',
            },
    )


    http_response = plan.request(
            service_name = w3s_context.service_name,
            recipe = request_recipe,
            acceptable_codes = [200],
            description = "Retrieving validator pubkeys from W3S",
    )
    aux= http_response["body"]
    w3s_url="http://{}:{}".format(w3s_context.service_name,w3s_context.service_ports["w3s-http"].number)
    validator_url="http://{}:{}".format(validator_service.name,validator_service.ports["vc-http"].number)
    plan.print(w3s_url)
    plan.print(validator_url)

    result = plan.run_python(
        run = """
import sys
import requests
import json

public_keys = sys.argv[1][1:-1].split(',')
api_token = sys.argv[2]
w3s_url= sys.argv[3]
validator_url= sys.argv[4]
headers = {
    "Authorization": f"Bearer {api_token}",
    "Content-Type": "application/json"
}

url = f"{validator_url}/lighthouse/validators/web3signer"
for voting_public_key in public_keys:
    data = [{
        "enable": True,
        "description": "validator_one",
        "graffiti": "Mr F was here",
        "suggested_fee_recipient": "0xa2e334e71511686bcfe38bb3ee1ad8f6babcc03d",
        "voting_public_key": voting_public_key,
        "builder_proposals": True,
        "url": f"{w3s_url}",
        "request_timeout_ms": 12000
    }]
    response = requests.post(url, headers=headers, data=json.dumps(data))
""",
        args = [
                aux,
                token,
                w3s_url,
                validator_url
            ],
            packages = [
                "requests",
            ],
        )

