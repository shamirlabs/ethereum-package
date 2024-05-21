def new_w3s_context(
    client_name,
    service_name,
    service_ports,
    node_keystore_files,
):
    return struct(
        client_name=client_name,
        service_name=service_name,
        service_ports=service_ports,
        node_keystore_files=node_keystore_files
    )
