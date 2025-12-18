# nodx
Self contained cluster

```
docker compose build
```

Up the systems locally
```
docker compose -f docker-compose.local.yml up -d
```

Logs
```
docker logs nodx1
docker logs nodx2
docker logs nodx-postgresql-1
```

Shells
```
# 1
docker exec -it nodx1 /bin/bash
# 2
docker exec -it nodx2 /bin/bash
```

```
./bin/nodx remote
Node.connect(:"nodx1@nodx1")
Node.connect(:"nodx2@nodx2")
```

Helpers
```
epmd -names
```