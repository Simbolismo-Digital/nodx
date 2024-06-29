# nodx
Self contained cluster

## 1. Ascenção:
Subiremos um NOIP local e conectaremos dois nodos locais usando DNS.
https://www.noip.com/pt-BR

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
