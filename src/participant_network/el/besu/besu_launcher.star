shared_utils = import_module("github.com/kurtosis-tech/eth2-module/src/shared_utils/shared_utils.star")
parse_input = import_module("github.com/kurtosis-tech/eth2-module/src/module_io/parse_input.star")
el_client_context = import_module("github.com/kurtosis-tech/eth2-module/src/participant_network/el/el_client_context.star")

module_io = import_types("github.com/kurtosis-tech/eth2-module/types.proto")

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/opt/besu/execution-data"

GENESIS_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/opt/besu/genesis"

RPC_PORT_NUM = 8545
WS_PORT_NUM = 8546
DISCOVERY_PORT_NUM = 30303
ENGINE_HTTP_RPC_PORT_NUM = 8550
ENGINE_WS_RPC_PORT_NUM = 8551

# Port IDs
RPC_PORT_ID = "rpc"
WS_PORT_ID = "ws"
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
ENGINE_HTTP_RPC_PORT_ID = "engineHttpRpc"
ENGINE_WS_RPC_PORT_ID = "engineWsRpc"

PRIVATE_IP_ADDRESS_PLACEHOLDER = "KURTOSIS_IP_ADDR_PLACEHOLDER"

USED_PORTS = {
	RPC_PORT_ID: shared_utils.new_port_spec(RPC_PORT_NUM, shared_utils.TCP_PROTOCOL),
	WS_PORT_ID: shared_utils.new_port_spec(WS_PORT_NUM, shared_utils.TCP_PROTOCOL),
	TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(DISCOVERY_PORT_NUM, shared_utils.TCP_PROTOCOL),
	UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(DISCOVERY_PORT_NUM, shared_utils.UDP_PROTOCOL),
	ENGINE_HTTP_RPC_PORT_ID: shared_utils.new_port_spec(ENGINE_HTTP_RPC_PORT_NUM, shared_utils.TCP_PROTOCOL),
	ENGINE_WS_RPC_PORT_ID: shared_utils.new_port_spec(ENGINE_WS_RPC_PORT_NUM, shared_utils.TCP_PROTOCOL)
}

ENTRYPOINT_ARGS = ["sh", "-c"]

BESU_LOG_LEVELS = {
	module_io.GlobalClientLogLevel.error: "ERROR",
	module_io.GlobalClientLogLevel.warn:  "WARN",
	module_io.GlobalClientLogLevel.info:  "INFO",
	module_io.GlobalClientLogLevel.debug: "DEBUG",
	module_io.GlobalClientLogLevel.trace: "TRACE",
}

ENODE_FACT_NAME = "enode-fact"

def launch(
	launcher,
	service_id,
	image,
	participant_log_level,
	global_log_level,
	existing_el_clients,
	extra_params):

	log_level = parse_input.get_client_log_level_or_default(participant_log_level, global_log_level, BESU_LOG_LEVELS)

	config = get_config(launcher.network_id, launcher.el_genesis_data,
                                    image, existing_el_clients, log_level, extra_params)

	service = add_service(service_id, config)

	define_fact(service_id = service_id, fact_name = ENODE_FACT_NAME, fact_recipe = struct(method= "POST", endpoint = "", field_extractor = ".result.enode", body = '{"method":"admin_nodeInfo","params":[],"id":1,"jsonrpc":"2.0"}', content_type = "application/json", port_id = RPC_PORT_ID))
	enode = wait(service_id = service_id, fact_name = ENODE_FACT_NAME)

	return el_client_context.new_el_client_context(
		"besu",
		"", # besu has no ENR
		enode,
		service.ip_address,
		RPC_PORT_NUM,
		WS_PORT_NUM,
		ENGINE_HTTP_RPC_PORT_NUM
	)


def get_config(network_id, genesis_data, image, existing_el_clients, log_level, extra_params):
	if len(existing_el_clients) < 2:
		fail("Besu node cannot be boot nodes, and due to a bug it requires two nodes to exist beforehand")

	boot_node_1 = existing_el_clients[0]
	boot_node_2 = existing_el_clients[1]

	genesis_json_filepath_on_client = shared_utils.path_join(GENESIS_DATA_DIRPATH_ON_CLIENT_CONTAINER, genesis_data.besu_genesis_json_relative_filepath)
	jwt_secret_json_filepath_on_client = shared_utils.path_join(GENESIS_DATA_DIRPATH_ON_CLIENT_CONTAINER, genesis_data.jwt_secret_relative_filepath)

	launch_node_command = [
		"besu",
		"--logging=" + log_level,
		"--data-path=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
		"--genesis-file=" + genesis_json_filepath_on_client,
		"--network-id=" + network_id,
		"--host-allowlist=*",
		"--rpc-http-enabled=true",
		"--rpc-http-host=0.0.0.0",
		"--rpc-http-port={0}".format(RPC_PORT_NUM),
		"--rpc-http-api=ADMIN,CLIQUE,ETH,NET,DEBUG,TXPOOL,ENGINE",
		"--rpc-http-cors-origins=*",
		"--rpc-ws-enabled=true",
		"--rpc-ws-host=0.0.0.0",
		"--rpc-ws-port={0}".format(WS_PORT_NUM),
		"--rpc-ws-api=ADMIN,CLIQUE,ETH,NET,DEBUG,TXPOOL,ENGINE",
		"--p2p-enabled=true",
		"--p2p-host=" + PRIVATE_IP_ADDRESS_PLACEHOLDER,
		"--p2p-port={0}".format(DISCOVERY_PORT_NUM),
		"--engine-rpc-enabled=true",
		"--engine-jwt-secret={0}".format(jwt_secret_json_filepath_on_client),
		"--engine-host-allowlist=*",
		"--engine-rpc-port={0}".format(ENGINE_HTTP_RPC_PORT_NUM),
	]

	if len(existing_el_clients) > 0:
		launch_node_command.append("--bootnodes={0},{1}".format(boot_node_1.enode, boot_node_2.enode))

	if len(extra_params) > 0:
		# we do this as extra_params isn't a normal [] but a proto repeated array
		launch_node_command.extend([param for param in extra_params])

	launch_node_command_str = " ".join(launch_node_command)

	return struct(
		image = image,
		ports = USED_PORTS,
		cmd = [launch_node_command_str],
		files = {
			genesis_data.files_artifact_uuid: GENESIS_DATA_DIRPATH_ON_CLIENT_CONTAINER
		},
		entrypoint = ENTRYPOINT_ARGS,
		private_ip_address_placeholder = PRIVATE_IP_ADDRESS_PLACEHOLDER
	)


def new_besu_launcher(network_id, el_genesis_data):
	return struct(
		network_id = network_id,
		el_genesis_data = el_genesis_data
	)