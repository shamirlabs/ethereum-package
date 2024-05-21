constants = import_module("../package_io/constants.star")
shared_utils = import_module("../shared_utils/shared_utils.star")
w3s_shared = import_module("./shared.star")


def get_config(
    el_cl_genesis_data,
    keymanager_file,
    image,
    participant_log_level,
    global_log_level,
    cl_context,
    full_name,
    node_keystore_files,
    w3s_min_cpu,
    w3s_max_cpu,
    w3s_min_mem,
    w3s_max_mem,
    extra_params,
    extra_env_vars,
    extra_labels,
    tolerations,
    node_selectors,
    keymanager_enabled,
    plan
):
    validator_keys_dirpath = ""
    validator_secrets_dirpath = ""
    if node_keystore_files != None:
        validator_keys_dirpath = shared_utils.path_join(
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
            node_keystore_files.teku_keys_relative_dirpath,
        )
        validator_secrets_dirpath = shared_utils.path_join(
            constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER,
            node_keystore_files.teku_secrets_relative_dirpath,
        )

    cmd = [
        "--metrics-enabled=true",
        "--metrics-host-allowlist=*",
        "--metrics-host=0.0.0.0",
        "--metrics-port={0}".format(w3s_shared.W3S_METRICS_PORT_NUM),
        "eth2",
        "--network="
        + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
        + "/config.yaml",
        "--keystores-path=" + validator_keys_dirpath,
        "--keystores-passwords-path=" + validator_secrets_dirpath,
        "--slashing-protection-enabled=false",
    ]
    #TODO:SLASHING PROTECTION

    #if len(extra_params) > 0:
        # this is a repeated<proto type>, we convert it into Starlark
    #    cmd.extend([param for param in extra_params])
    w3s_config = plan.upload_files(
        src = "../../static_files/w3s-config/tls/web3signer",
        name = "w3s_config_{}".format(full_name),
    )

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data.files_artifact_uuid,
        constants.VALIDATOR_KEYS_DIRPATH_ON_SERVICE_CONTAINER: node_keystore_files.files_artifact_uuid,
        constants.KEYMANAGER_MOUNT_PATH_ON_CLIENTS: keymanager_file,
        #"/tmp": w3s_config,
    }
    
    ports={}

    ports.update(w3s_shared.W3S_METRICS_USED_PORTS)

    if keymanager_enabled:
        cmd.insert(0,"--http-listen-port={0}".format(w3s_shared.W3S_HTTP_PORT_NUM))
        cmd.insert(0,"--http-host-allowlist=*")

    ports.update(w3s_shared.W3S_HTTP_USED_PORTS)

    return ServiceConfig(
        image=image,
        ports=ports,
        cmd=cmd,
        env_vars=extra_env_vars,
        files=files,
        min_cpu=w3s_min_cpu,
        max_cpu=w3s_max_cpu,
        min_memory=w3s_min_mem,
        max_memory=w3s_max_mem,
        labels=shared_utils.label_maker(
            constants.W3S_TYPE.consensys,
            constants.CLIENT_TYPES.w3s,
            image,
            cl_context.client_name,
            extra_labels,
        ),
        tolerations=tolerations,
        node_selectors=node_selectors,
    )