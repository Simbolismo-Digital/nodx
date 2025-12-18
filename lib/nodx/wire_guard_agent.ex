defmodule Nodx.WireGuardAgent do
  use Agent
  require Logger

  @wg_subnet "10.200.0.0/24"
  @dets_file to_char_list("/app/data/wg_state.dets")

  # =====================
  # Public API
  # =====================
  def start_link(_opts) do
    Logger.info("[WireGuardAgent] Initializing...")
    Agent.start_link(fn -> init_state() end, name: __MODULE__)
  end

  def get_state, do: Agent.get(__MODULE__, & &1)

  # =====================
  # Initialize state
  # =====================
  defp init_state do
    # Try to open DETS
    case :dets.open_file(:wg_state, file: @dets_file, type: :set) do
      {:ok, dets} ->
        case :dets.lookup(dets, :wireguard) do
          [{:wireguard, state}] ->
            Logger.info("[WireGuardAgent] Loaded state from DETS: #{inspect(state)}")

            Task.async_stream(state.peers, fn {peer_pubkey, %{wg_ip: wg_ip, endpoint: endpoint}} ->
              set_wg_peer(peer_pubkey, wg_ip, endpoint)
            end)
            |> Task.await()

            {dets, state}

          [] ->
            {dets, create_new_state(dets)}
        end

      {:error, error} ->
        throw("[WireGuardAgent] Failed to open DETS file: #{@dets_file} cause #{inspect(error)}")
    end
  end

  # =====================
  # Create new state
  # =====================
  defp create_new_state(dets) do
    private_key = generate_private_key()
    public_key = generate_public_key(private_key)
    wg_ip = generate_wg_ip(public_key)

    # Create wg0 interface
    create_wg_interface(private_key, wg_ip)

    state = %{
      private_key: private_key,
      public_key: public_key,
      wg_ip: wg_ip,
      endpoint: fetch_endpoint(),
      peers: %{}
      # peer_pubkey => %{
      #   wg_ip: "10.200.0.X",
      #   endpoint: "host:51820"
      # }
    }

    # Save to DETS
    :dets.insert(dets, {:wireguard, state})
    Logger.info("[WireGuardAgent] Saved state to DETS: #{inspect(state)}")
    state
  end

  # =====================
  # Fetch public endpoint
  # =====================
  defp fetch_endpoint do
    port = System.get_env("WG_PORT", "51820")

    case Req.get("https://ifconfig.me/ip") do
      {:ok, %Req.Response{body: ip}} ->
        ip = String.trim(ip)
        Logger.info("[WireGuardAgent] Using public IP #{ip} as endpoint")
        "#{ip}:#{port}"

      _ ->
        Logger.warn("[WireGuardAgent] Could not fetch public IP, using localhost")
        "127.0.0.1:#{port}"
    end
  end

  def add_peer(peer_pubkey, wg_ip, endpoint) do
    Agent.update(__MODULE__, fn {dets, state} ->
      new_peers = Map.put(state.peers, peer_pubkey, %{wg_ip: wg_ip, endpoint: endpoint})
      # persist to DETS
      :dets.insert(dets, {:wireguard, %{state | peers: new_peers}})
      %{state | peers: new_peers}
    end)

    set_wg_peer(peer_pubkey, wg_ip, endpoint)
  end

  def set_wg_peer(peer_pubkey, wg_ip, endpoint) do
    System.cmd("wg", [
      "set",
      "wg0",
      "peer",
      peer_pubkey,
      "allowed-ips",
      "#{wg_ip}/32",
      "endpoint",
      endpoint
    ])
  end

  # =====================
  # Internal functions
  # =====================
  defp generate_private_key do
    {key, 0} = System.cmd("wg", ["genkey"])
    String.trim(key)
  end

  defp generate_public_key(private_key) do
    {pubkey, 0} =
      System.cmd("sh", ["-c", "echo '#{private_key}' | wg pubkey"])

    String.trim(pubkey)
  end

  defp generate_wg_ip(pubkey) do
    hash =
      :crypto.hash(:sha256, pubkey)
      |> :binary.decode_unsigned()

    octet = rem(hash, 254) + 1
    "10.200.0.#{octet}"
  end

  defp create_wg_interface(private_key, wg_ip) do
    # Create wg0 interface dynamically
    System.cmd("ip", ["link", "add", "wg0", "type", "wireguard"])
    System.cmd("ip", ["address", "add", "#{wg_ip}/32", "dev", "wg0"])

    System.cmd("sh", [
      "-c",
      "echo '#{private_key}' | wg set wg0 private-key /dev/stdin listen-port 51820"
    ])

    System.cmd("ip", ["link", "set", "wg0", "up"])
    Logger.info("WireGuard interface wg0 created with IP #{wg_ip}")
  end
end
