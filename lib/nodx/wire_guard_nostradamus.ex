defmodule Nodx.WireGuardNostradamus do
  use GenServer
  require Logger

  # 10 seconds
  @poll_interval 10_000
  @nostr_relays ["wss://relay.damus.io"]
  # Custom Nostr kind for WireGuard peers
  @event_kind 424_243

  # ----------------------
  # Public API
  # ----------------------
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, Nodx.WireGuardAgent.get_state() |> elem(1), name: __MODULE__)
  end

  # ----------------------
  # GenServer Callbacks
  # ----------------------
  def init(state) do
    Logger.info("[WireGuardNostradamus] Starting Nostr peer sync loop...")
    schedule_sync()
    {:ok, state}
  end

  def handle_info(:sync_peers, wg_state) do
    state = sync_peers(wg_state)
    schedule_sync()
    {:noreply, state}
  end

  # ----------------------
  # Internal Functions
  # ----------------------
  defp schedule_sync do
    Process.send_after(self(), :sync_peers, @poll_interval)
  end

  # ----------------------
  # Core Sync Logic
  # ----------------------
  defp sync_peers(wg_state) do
    Logger.debug("[WireGuardNostradamus] Syncing peers...")

    # 1️⃣ Fetch peers from relays
    peers = fetch_peers()

    Logger.info("[WireGuardNostradamus] Fetched #{length(peers)} peers from relays")

    # 2️⃣ Publish self if missing
    publish_self_if_missing(peers, wg_state)

    # 3️⃣ Add other peers to WireGuard
    peers
    |> Enum.reject(&(&1.pubkey == wg_state.public_key))
    |> Enum.each(fn %{pubkey: pk, wg_ip: ip, endpoint: ep} ->
      Logger.info("[WireGuardNostradamus] Adding/updating peer #{pk} (#{ip} -> #{ep})")
      Nodx.WireGuardAgent.add_peer(pk, ip, ep)
    end)

    wg_state
  end

  # ----------------------
  # Fetch Peers from Nostr
  # ----------------------
  defp fetch_peers do
    # Custom kind for WireGuard peers
    filter = %{kinds: [@event_kind]}

    case Nostr.Client.fetch(@nostr_relays, filter) do
      {:ok, events} ->
        Logger.debug("[WireGuardNostradamus] Received #{length(events)} events from relays")

        events
        |> Enum.map(&parse_peer_event/1)
        |> Enum.filter(& &1)

      {:error, reason} ->
        Logger.error("[WireGuardNostradamus] Failed to fetch peers: #{inspect(reason)}")
        []
    end
  end

  defp parse_peer_event(event) do
    # event["content"] is "10.200.0.X|host:51820"
    case String.split(event["content"], "|") do
      [wg_ip, endpoint] ->
        Logger.debug(
          "[WireGuardNostradamus] Parsing peer event: pubkey=#{event["pubkey"]}, wg_ip=#{wg_ip}, endpoint=#{endpoint}, kind=#{event["kind"]}"
        )

        %{
          pubkey: event["pubkey"],
          wg_ip: wg_ip,
          endpoint: endpoint,
          kind: event["kind"]
        }

      _ ->
        Logger.warn("[WireGuardNostradamus] Malformed peer event: #{inspect(event)}")
        nil
    end
  end

  # ----------------------
  # Publish Self
  # ----------------------
  defp publish_self_if_missing(peers, wg_state) do
    self_pubkey = wg_state.public_key

    unless Enum.any?(peers, &(&1 && &1.pubkey == self_pubkey)) do
      event = build_peer_event(wg_state)
      signed_event = sign_event(event, wg_state.private_key)

      Enum.each(@nostr_relays, fn relay ->
        Logger.info("Would publish")
        #   case Nostr.Client.publish(relay, signed_event) do
      #     {:ok, _} ->
      #       Logger.info(
      #         "[WireGuardNostradamus] Published self to relay #{relay} (pubkey=#{self_pubkey}, wg_ip=#{wg_state.wg_ip}, kind=#{@event_kind})"
      #       )

      #     {:error, reason} ->
      #       Logger.error(
      #         "[WireGuardNostradamus] Failed to publish to relay #{relay}: #{inspect(reason)}"
      #       )
      #   end
      end)
    end
  end

  defp build_peer_event(%{public_key: pk, wg_ip: wg_ip, endpoint: endpoint}) do
    %{
      "pubkey" => pk,
      "created_at" => System.system_time(:second),
      "kind" => @event_kind,
      "tags" => [],
      "content" => "#{wg_ip}|#{endpoint}",
      "id" => Ecto.UUID.generate(),
      "sig" => nil
    }
  end

  # ----------------------
  # Sign Nostr Event
  # ----------------------
  def sign_event(%{
        "pubkey" => pubkey,
        "kind" => kind,
        "content" => content,
        "tags" => tags
      }, privkey) do
    created_at = DateTime.utc_now() |> DateTime.to_unix()

    # 1️⃣ Build raw array
    raw_event = [0, pubkey, created_at, kind, tags, content]

    # 2️⃣ Serialize to JSON
    serialized = Jason.encode!(raw_event)

    # 3️⃣ SHA256 to get id
    id = :crypto.hash(:sha256, serialized) |> Base.encode16(case: :lower)

    # 4️⃣ Sign the id with Ed25519
    # 5️⃣ Return complete event map
    %{
      "id" => id,
      "pubkey" => pubkey,
      "created_at" => created_at,
      "kind" => kind,
      "tags" => tags,
      "content" => content,
      "sig" => parse_privkey(id, privkey)
    }
  end

  def parse_privkey(id, base64_privkey) when is_binary(base64_privkey) do
    :crypto.sign(:eddsa, :none, Base.decode16!(id, case: :lower), [Base.decode64!(base64_privkey), :ed25519])
    |> Base.encode16(case: :lower)
  end
end
