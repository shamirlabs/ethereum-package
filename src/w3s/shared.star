shared_utils = import_module("../shared_utils/shared_utils.star")

W3S_HTTP_PORT_ID = "w3s-http"
W3S_HTTP_PORT_NUM = 9000
W3S_METRICS_PORT_NUM = 8080
W3S_METRICS_PORT_ID = "metrics"
METRICS_PATH = "/metrics"

W3S_METRICS_USED_PORTS = {
    W3S_METRICS_PORT_ID: shared_utils.new_port_spec(
        W3S_METRICS_PORT_NUM,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
}

W3S_HTTP_USED_PORTS = {
    W3S_HTTP_PORT_ID: shared_utils.new_port_spec(
        W3S_HTTP_PORT_NUM,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}

