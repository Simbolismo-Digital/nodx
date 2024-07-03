# nodx
Self contained cluster

## 1. Ascenção:
Subiremos um NOIP local e conectaremos dois nodos locais usando DNS.
https://www.noip.com/pt-BR

* installing
```sh
  wget --content-disposition https://www.noip.com/download/linux/latest
  tar xf noip-duc_3.1.1.tar.gz
  cd noip-duc_3.1.1/binaries && sudo apt install ./noip-duc_3.1.1_amd64.deb
```

* running
```sh
  noip-duc --hostnames bancodetempo.ddns.net --username davi.abreu.w@gmail.com --password *****
  [2024-06-30T15:36:33Z ERROR noip_duc] update failed; No host or group was specified. Please create a group with a password to update at https://my.noip.com/dynamic-dns/groups
  
  # I created the group, after a while it solved
```

* get my external ip
```sh
EXTERNAL_IP=$(curl --silent -4 ifconfig.me)
```

* não foi suficiente

* tunneling com ngrok
```sh
  # I started some application: e.g. xlog application on localhost:4000
  sudo ngrok http 4000 # it runs ok in new url

  #!/bin/bash

  # No-IP credentials
  NOIP_USERNAME="davi.abreu.w@gmail.com"
  NOIP_PASSWORD="******"
  NOIP_HOSTNAME="bancodetempo.ddns.net"

  # Get the public URL from Ngrok
  NGROK_URL=$(curl --silent http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[0].public_url')

  # Extract the IP and port from the Ngrok URL
  NGROK_IP=$(echo $NGROK_URL | awk -F[/:] '{print $4}')
  NGROK_PORT=$(echo $NGROK_URL | awk -F[/:] '{print $5}')

  # Update No-IP with the new IP and port
  curl -u "$NOIP_USERNAME:$NOIP_PASSWORD" "https://dynupdate.no-ip.com/nic/update?hostname=$NOIP_HOSTNAME&myip=$NGROK_IP"

  echo "Updated No-IP with Ngrok URL: $NGROK_URL"
```

* ip tables routing
```sh
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 4000
```


## 2. A asa: 
Criaremos um docker com NOIP e validaremos que os nodos locais ainda rodam.
https://hub.docker.com/r/coppit/no-ip
Se o DNS estiver fora, a aplicação terá um processo (GenServer) monitor para executar o docker com o NOIP sempre que preciso.
A libcluster aparenta ter a estratégia pronta pra clusterizar: https://github.com/bitwalker/libcluster/blob/main/lib/strategy/kubernetes_dns.ex

```
# mix.exs
defp deps do
  [
    {:porcelain, "~> 2.0"},
    # libcluster needs further setup
    {:libcluster, "~> 3.3"}
  ]
end
```

```
case :inet_res.getbyname('example.net', :a) do
  {:error, :nxdomain} -> 
    defp run_docker_image(image_name) do
  case Porcelain.exec("docker", ["run", "noip"]) do
    %Porcelain.Result{out: output, status: 0} ->
      IO.puts("Docker image ran successfully: #{output}")

    %Porcelain.Result{out: output, status: status} ->
      IO.puts("Failed to run Docker image. Status: #{status}, Output: #{output}")
  end
end
  _ -> nil
```


## 3. O ovo:
Colocaremos a aplicação Elixir num Docker que poderá fechar o ciclo sempre que necessário.

## 4. A lenda:
https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html

## 5. O resultado:
Um cluster imortal que se regenera e interconecta a partir de uma única simples instância.
