input_parser = import_module("../package_io/input_parser.star")
constants = import_module("../package_io/constants.star")
node_metrics = import_module("../node_metrics_info.star")
w3s_context = import_module("./w3s_context.star")
w3s_shared = import_module("./shared.star")

consensys = import_module("./consensys.star")


# The defaults for min/max CPU/memory that the W3S client can use
MIN_CPU = 50
MAX_CPU = 300
MIN_MEMORY = 128
MAX_MEMORY = 512


def launch(
    plan,
    launcher,
    keymanager_file,
    service_name,
    w3s_type,
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
    prysm_password_relative_filepath,
    prysm_password_artifact_uuid,
    w3s_tolerations,
    participant_tolerations,
    global_tolerations,
    node_selectors,
    keymanager_enabled,
    preset,
    network,  # TODO: remove when deneb rebase is done
    electra_fork_epoch,  # TODO: remove when deneb rebase is done
):
    if node_keystore_files == None:
        return None

    tolerations = input_parser.get_client_tolerations(
        w3s_tolerations, participant_tolerations, global_tolerations
    )

    w3s_min_cpu = int(w3s_min_cpu) if int(w3s_min_cpu) > 0 else MIN_CPU
    w3s_max_cpu = int(w3s_max_cpu) if int(w3s_max_cpu) > 0 else MAX_CPU
    w3s_min_mem = int(w3s_min_mem) if int(w3s_min_mem) > 0 else MIN_MEMORY
    w3s_max_mem = int(w3s_max_mem) if int(w3s_max_mem) > 0 else MAX_MEMORY

    if w3s_type == "consensys":
        config = consensys.get_config(
            el_cl_genesis_data=launcher.el_cl_genesis_data,
            image=image,
            keymanager_file=keymanager_file,
            participant_log_level=participant_log_level,
            global_log_level=global_log_level,
            cl_context=cl_context,
            full_name=full_name,
            node_keystore_files=node_keystore_files,
            w3s_min_cpu=w3s_min_cpu,
            w3s_max_cpu=w3s_max_cpu,
            w3s_min_mem=w3s_min_mem,
            w3s_max_mem=w3s_max_mem,
            extra_params=extra_params,
            extra_env_vars=extra_env_vars,
            extra_labels=extra_labels,
            tolerations=tolerations,
            node_selectors=node_selectors,
            keymanager_enabled=keymanager_enabled,
        )

    else:
        fail("Unsupported w3s_type: {0}".format(w3s_type))

    w3s_service = plan.add_service(service_name, config)

    w3s_metrics_port = w3s_service.ports[w3s_shared.W3S_METRICS_PORT_ID]
    
    w3s_metrics_url = "{0}:{1}".format(
        w3s_service.ip_address, w3s_metrics_port.number
    )
    w3s_node_metrics_info = node_metrics.new_node_metrics_info(
        service_name, w3s_shared.METRICS_PATH, w3s_metrics_url
    )

    w3s_http_ports = w3s_service.ports[w3s_shared.W3S_HTTP_PORT_ID]
    


    return w3s_context.new_w3s_context(
        client_name=w3s_type,
        service_name=service_name,
        metrics_info=w3s_node_metrics_info,
        ports=w3s_http_ports
    )


def new_w3s_launcher(el_cl_genesis_data):
    return struct(el_cl_genesis_data=el_cl_genesis_data)
