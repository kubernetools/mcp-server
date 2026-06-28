FROM registry.access.redhat.com/hi/core-runtime:2.42-openssl

COPY mcp /usr/local/bin/mcp

EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/mcp"]
