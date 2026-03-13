# TODO

## Fix granular `nginx.conf` tree

> [!CAUTION]
> currently loops, reverted

```tree
/etc/nginx/
├── isabelle-evolucao
│   ├── api
│   │   └── test.upload_log.conf
│   └── api-conf
│       └── proxy.conf
├── sites-available
│   └── isabelle-evolucao.conf
└── sites-enabled
    └── isabelle-evolucao.conf -> ../sites-available/isabelle-evolucao.conf
```
