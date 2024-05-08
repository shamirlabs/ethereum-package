def new_w3s_context(
    client_name,
    service_name,
    metrics_info,
    ports
):
    return struct(
        client_name=client_name,
        service_name=service_name,
        metrics_info=metrics_info,
        ports=ports
    )
